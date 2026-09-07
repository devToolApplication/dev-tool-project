# Test Matrix: Flowable KOC Candidate Discovery Loop v2

- Feature: KOC-DISCOVERY-V2
- Quy trinh: `kocCandidateDiscoveryProcess` (BPMN 2.0)
- Tai lieu thiet ke goc: `docs/designs/koc-candidate-discovery-bpmn-workflow.md` (Muc 14 & 15)
- Ngay lap: 2026-09-07
- Vai tro: Senior QA / Test Engineer

---

## 1. Tong quan va Chien luoc kiem thu (Test Strategy)

### 1.1. Muc tieu kiem thu
Kiem chung toan dien quy trinh Flowable BPMN `kocCandidateDiscoveryProcess` phien ban v2, bao gom:
- Co che vong lap co trang thai (stateful bounded loop) dua tren `searchRound` va `roundLimit`.
- Co che phan luong Gateway dua hoan toan tren process variables (`loginRequired`, `hasNewCandidates`, `enoughCandidates`, `roundsRemaining`, `discoveryDecision`, `approved`), loai bo triet de `execution.getVariable(...)`.
- Xu ly loi AI tieu chuan (bo batch, khong ket thuc FAILED, khong lam mat candidate da tich luy) va loi xac thuc `MCP_FACEBOOK_LOGIN_REQUIRED` (chuyen huong sang subprocess `hitlFacebookLoginProcess`).
- Quan ly chu ky tim kiem qua User Task quyet dinh (`userTaskDiscoveryDecision`: `FIND_MORE` vs `STOP`) va User Task phe duyet (`userTaskApproveCandidates`: `approved` true/false).
- Dam bao tinh toan ven du lieu (idempotency cua keyword/cursor, unique profile ID/URL trong workflow va database).

### 1.2. Pham vi kiem thu
- **Kiem thu tich hop Flowable Engine:** 12 scenarios Flowable Integration Tests dac ta tai Section 14.2.
- **Kiem thu Unit Test Delegate:** 9 units kiem thu delegates theo Section 14.1.
- **Kiem thu cau truc BPMN XML:** Static parsing, linting schema, kiem tra loai bo cac anti-patterns cu.

### 1.3. Nguyen tac kiem thu (QA Rules)
1. Moi scenario kiem thu phai xac minh ca 3 goc do:
   - Flowable Execution Path: Cac service task, subprocess call activity, gateway, user task duoc thuc thi theo dung trinh tu.
   - Process Variables State: Gia tri cac bien qua tung buoc (input, intermediate, output).
   - Campaign Lifecycle State: Trang thai campaign trong MongoDB storage (`RUNNING`, `USER_TASK`, `COMPLETED`, `TERMINATED`).
2. Khong gia lap trang thai sai lech so voi contract thuc te cua AI SDK Service.
3. Moi loi he thong / ha tang bat buoc phai ban ra Flowable Incident, khong duoc swallowed.

---

## 2. Test Data Management & Fixtures

### 2.1. Du lieu khoi tao Campaign mac dinh
```json
{
  "campaignId": "camp-discovery-test-001",
  "niche": "Beauty",
  "accountType": "FACEBOOK",
  "tag": "DISCOVERY",
  "targetCount": 3,
  "minScore": 75.0,
  "searchBatchSize": 10,
  "maxSearchRounds": 3
}
```

### 2.2. Tai khoan Facebook Test
```json
{
  "id": "acc-fb-test-01",
  "type": "FACEBOOK",
  "username": "qa.koc.automation@example.com",
  "password": "MockSecurePassword123!",
  "tags": ["DISCOVERY", "LOGIN"]
}
```

### 2.3. AI Search Fixtures
- **Search Success (Batch 2 candidates):**
  - Candidate 1: `externalProfileId: "fb-cand-101"`, `fullName: "Nguyen Van A"`, `profileUrl: "https://facebook.com/nva.koc"`
  - Candidate 2: `externalProfileId: "fb-cand-102"`, `fullName: "Tran Thi B"`, `profileUrl: "https://facebook.com/ttb.koc"`
  - Searches metadata: `[{ "keyword": "koc beauty review", "cursorUsed": null, "nextCursor": "cur-01" }]`
- **Search Empty:**
  - `candidates: []`
  - Searches metadata: `[{ "keyword": "koc ultra rare niche", "cursorUsed": null, "nextCursor": null }]`
- **Search Error RATE_LIMIT_EXCEEDED:**
  - `status: "FAILED"`, `errorCode: "RATE_LIMIT_EXCEEDED"`, `errorMessage: "Facebook Graph API rate limit exceeded"`
- **Search Error MCP_FACEBOOK_LOGIN_REQUIRED:**
  - `status: "FAILED"`, `errorCode: "MCP_FACEBOOK_LOGIN_REQUIRED"`, `errorMessage: "Session expired, login required"`
  - `threadId: "tid-fb-session-login-01"`

### 2.4. AI Review Fixtures
- **Review Qualified:**
  - Candidate 1: `score: 85.0`, `isQualified: true`
  - Candidate 2: `score: 60.0`, `isQualified: false`
- **Review Error MCP_FACEBOOK_LOGIN_REQUIRED:**
  - `status: "FAILED"`, `errorCode: "MCP_FACEBOOK_LOGIN_REQUIRED"`, `errorMessage: "Cookie expired during profile inspection"`

---

## 3. Ma tran kiem thu tong the (Master Test Matrix)

| ID | Ten Scenario | Dieu kien kich hoat / Input | Luong thuc thi (Path / Nodes) | Bien trang thai chinh | Campaign Status | Do uu tien |
|---|---|---|---|---|---|---|
| **S1** | Search loi thuong | AI Search tra ve `RATE_LIMIT_EXCEEDED` hoac `SEARCH_FAILED` | `taskInitializeDiscoveryState` -> `taskLoadAccount` -> `taskPrepareSearchContext` -> `callAiSearchKoc` -> `taskRecordSearchOutput` -> `gwCheckSearchStatus` -> `taskFilterDuplicateCandidates` (`hasNewCandidates=false`) -> `taskAdvanceSearchRound` -> `gwCheckRoundsRemaining` | `searchRound: 1`, `loginRequired: false`, `lastErrorStage: SEARCH`, `lastErrorCode: RATE_LIMIT_EXCEEDED` | `RUNNING` | P0 (Blocker) |
| **S2** | Search loi login required | AI Search tra ve `MCP_FACEBOOK_LOGIN_REQUIRED` | `callAiSearchKoc` -> `taskRecordSearchOutput` -> `gwCheckSearchStatus` (`loginRequired=true`) -> `callRecoverFbLoginSearch` -> `taskAdvanceSearchRound` -> Loop ve `taskPrepareSearchContext` | `searchRound: 1`, `loginRequired: true`, `threadId` duoc bao luu nguyen ven | `RUNNING` | P0 (Blocker) |
| **S3** | Review loi login required | AI Review tra ve `MCP_FACEBOOK_LOGIN_REQUIRED` | `taskPrepareReviewContext` -> `callAiReviewKoc` -> `taskProcessReviewResults` -> `gwCheckReviewStatus` (`loginRequired=true`) -> `callRecoverFbLoginReview` -> `taskAdvanceSearchRound` -> Loop ve `taskPrepareSearchContext` | `searchRound: 1`, `loginRequired: true`, review batch bi huy, giu nguyen candidate cu | `RUNNING` | P0 (Blocker) |
| **S4** | Search rong hoac trung toan bo | Search tra ve 0 candidate hoac toan bo profile da co trong DB/workflow | `callAiSearchKoc` -> `taskRecordSearchOutput` -> `taskFilterDuplicateCandidates` (`uniqueCandidates=[]`, `hasNewCandidates=false`) -> `gwCheckNewCandidates` -> `taskAdvanceSearchRound` | `hasNewCandidates: false`, `uniqueCandidates: []`, bo qua hoan toan buoc Review | `RUNNING` | P1 (High) |
| **S5** | Tich luy du targetCount | So luong `qualifiedCandidates` dat >= `targetCount` | `callAiReviewKoc` -> `taskProcessReviewResults` (`enoughCandidates=true`) -> `gwCheckCandidatesThreshold` -> `taskUpdateStatusUserTask` -> `userTaskApproveCandidates` | `enoughCandidates: true`, `qualifiedCount >= targetCount` | `USER_TASK` | P0 (Blocker) |
| **S6** | Het maxSearchRounds chua du target | `searchRound == roundLimit` va `qualifiedCount < targetCount` | `taskAdvanceSearchRound` -> `gwCheckRoundsRemaining` (`roundsRemaining=false`) -> `taskUpdateStatusUserDecision` -> `userTaskDiscoveryDecision` | `roundsRemaining: false`, dung tai `userTaskDiscoveryDecision` | `USER_TASK` | P0 (Blocker) |
| **S7** | Checkpoint chon FIND_MORE | Nguoi dung submit `userTaskDiscoveryDecision` voi `discoveryDecision='FIND_MORE'` | `userTaskDiscoveryDecision` -> `gwCheckDiscoveryDecision` -> `taskUpdateStatusRunning` -> `taskExtendSearchCycle` -> `taskPrepareSearchContext` | `roundLimit += maxSearchRounds`, `roundsRemaining: true`, giu nguyen `searchHistory`, `qualifiedCandidates` | `RUNNING` | P0 (Blocker) |
| **S8** | Checkpoint chon STOP | Nguoi dung submit `userTaskDiscoveryDecision` voi `discoveryDecision='STOP'` | `userTaskDiscoveryDecision` -> `gwCheckDiscoveryDecision` -> `taskUpdateStatusUserTask` -> `userTaskApproveCandidates` | Chuyen thang den man phe duyet ung vien hien co | `USER_TASK` | P0 (Blocker) |
| **S9** | Phe duyet thanh cong | Nguoi dung submit `userTaskApproveCandidates` voi `approved=true` | `userTaskApproveCandidates` -> `gwCheckApproval` -> `taskSaveKocCandidates` -> `taskUpdateStatusCompleted` -> `endSuccess` | Luu MongoDB, `approved: true` | `COMPLETED` | P0 (Blocker) |
| **S10** | Tu choi phe duyet | Nguoi dung submit `userTaskApproveCandidates` voi `approved=false` | `userTaskApproveCandidates` -> `gwCheckApproval` -> `taskUpdateStatusRejected` -> `endRejected` | Khong luu MongoDB, `approved: false` | `TERMINATED` | P1 (High) |
| **S11** | Kiem tra cau truc BPMN XML | Doc file BPMN XML tren disk/resources | Unit parsing & regex scan | Khong con `execution.getVariable`, khong con `endFailed`, khong con `retryCount/maxRetries` | N/A | P0 (Blocker) |
| **S12** | Engine parse & deploy thuc te | Deploy vao Flowable Spring Process Engine | Flowable RepositoryService deploy thanh cong khong throw exception | BpmnModel hop le, Deployment Entity duoc tao co ID hop le | N/A | P0 (Blocker) |

---

## 4. Chi tiet 12 Kich ban kiem thu (Detailed Test Specifications)

### 4.1. TC-FLOW-01 (Scenario S1): Search loi thuong (RATE_LIMIT / TIMEOUT / SEARCH_FAILED)
- **Tieu de:** Xu ly loi AI Search thong thuong, bo batch, tang round va tiep tuc chu ky
- **Tien dieu kien:**
  - Campaign tao moi voi `searchBatchSize = 10`, `maxSearchRounds = 3`, `targetCount = 5`.
  - Account Facebook hop le o tag `DISCOVERY`.
- **Cac buoc thuc hien:**
  1. Khoi dong workflow bang `startWorkflow(...)`.
  2. Mock AI SDK nhan Search request lan 1: Tra ve `status="FAILED"`, `errorCode="RATE_LIMIT_EXCEEDED"`, `errorMessage="Facebook API rate limit exceeded"`.
  3. Quan sat thuc thi cua Flowable engine qua cac node.
- **Ket qua mong doi:**
  - Node `taskRecordSearchOutput` ghi nhan `lastErrorStage = "SEARCH"`, `lastErrorCode = "RATE_LIMIT_EXCEEDED"`, `lastErrorMessage = "Facebook API rate limit exceeded"`, `lastErrorAtRound = 1`.
  - Bien `loginRequired` bang `false`.
  - Node `taskFilterDuplicateCandidates` ghi nhan `rawCandidatesOutput` rong -> dat `hasNewCandidates = false`.
  - Gateway `gwCheckNewCandidates` re nhanh sang `taskAdvanceSearchRound` (bo qua hoan toan `taskPrepareReviewContext` va `callAiReviewKoc`).
  - `taskAdvanceSearchRound` tang `searchRound` tu 0 len 1.
  - Vi `searchRound (1) < roundLimit (3)` -> `roundsRemaining = true`.
  - Gateway `gwCheckRoundsRemaining` re ve `taskPrepareSearchContext` de chay luot search round 2.
  - Campaign status giu nguyen `RUNNING`, KHONG bi chuyen thanh `FAILED`.

---

### 4.2. TC-FLOW-02 (Scenario S2): Search gap loi MCP_FACEBOOK_LOGIN_REQUIRED
- **Tieu de:** Search gap loi het phien Facebook, goi subprocess HITL Facebook Login va lap lai voi cung threadId
- **Tien dieu kien:**
  - Campaign khoi tao voi `targetCount = 2`, `maxSearchRounds = 3`.
- **Cac buoc thuc hien:**
  1. Khoi dong workflow.
  2. Mock AI SDK Search lan 1: Tra ve `status="FAILED"`, `errorCode="MCP_FACEBOOK_LOGIN_REQUIRED"`, `threadId="tid-session-fb-01"`.
  3. Mock subprocess `hitlFacebookLoginProcess`: Tra ve `aiStatus="COMPLETED"`, login thanh cong.
  4. Quan sat ket qua tai Gateway `gwCheckSearchStatus` va luot search tiep theo.
- **Ket qua mong doi:**
  - Node `taskRecordSearchOutput` xac dinh dung `errorCode == 'MCP_FACEBOOK_LOGIN_REQUIRED'` -> set `loginRequired = true`.
  - Gateway `gwCheckSearchStatus` re nhanh vao `callRecoverFbLoginSearch` (Subprocess `hitlFacebookLoginProcess`).
  - Sau khi subprocess login hoan tat, sequence flow `f_login_search_to_advance_round` dua den `taskAdvanceSearchRound`.
  - `searchRound` tang len 1, `roundsRemaining = true`.
  - Vong search tiep theo (round 2) bat buoc truyen chinh xac `threadId = "tid-session-fb-01"` vao `callAiSearchKoc`.

---

### 4.3. TC-FLOW-03 (Scenario S3): Review gap loi MCP_FACEBOOK_LOGIN_REQUIRED
- **Tieu de:** Review gap loi het phien Facebook, goi subprocess login, huy batch review va chuyen sang luot search moi
- **Tien dieu kien:**
  - AI Search round 1 thanh cong, tra ve 2 candidates hop le (`fb-001`, `fb-002`).
  - `hasNewCandidates = true`.
- **Cac buoc thuc hien:**
  1. AI Search hoan tat thanh cong, du lieu chuyen qua Review.
  2. Mock AI SDK Review: Tra ve `status="FAILED"`, `errorCode="MCP_FACEBOOK_LOGIN_REQUIRED"`.
  3. Mock subprocess `hitlFacebookLoginProcess`: Login thanh cong.
  4. Theo doi duong di qua Gateway `gwCheckReviewStatus`.
- **Ket qua mong doi:**
  - Node `taskProcessReviewResults` phat hien `reviewErrorCode == 'MCP_FACEBOOK_LOGIN_REQUIRED'` -> set `loginRequired = true`.
  - Gateway `gwCheckReviewStatus` re nhanh vao `callRecoverFbLoginReview` (Subprocess `hitlFacebookLoginProcess`).
  - Batch review bi huy: `qualifiedCandidates` khong duoc tich luy candidate cua batch nay (`qualifiedCount` van la 0).
  - Sau khi subprocess login xong, tiep tuc den `taskAdvanceSearchRound` -> tang round len 1.
  - Gateway `gwCheckRoundsRemaining` re ve `taskPrepareSearchContext` bat dau luot Search moi.

---

### 4.4. TC-FLOW-04 (Scenario S4): Search rong hoac toan candidate trung lap
- **Tieu de:** Search khong co ung vien moi hoac toan bo candidate bi trung database/seen profiles
- **Tien dieu kien:**
  - Database da ton tai candidate voi externalProfileId `fb-dup-001` va `fb-dup-002`.
- **Cac buoc thuc hien:**
  1. Workflow bat dau.
  2. Mock AI SDK Search tra ve 2 candidates trung (`fb-dup-001`, `fb-dup-002`).
  3. Service `FilterDuplicateCandidatesDelegate` kiem tra trung qua `KocCandidateService`.
- **Ket qua mong doi:**
  - `FilterDuplicateCandidatesDelegate` loc bo toan bo candidate trung.
  - Bien `uniqueCandidates` co kich thuoc 0.
  - Bien `hasNewCandidates = false`.
  - Gateway `gwCheckNewCandidates` re theo nhanh `f_no_new_candidates` truc tiep sang `taskAdvanceSearchRound`.
  - Khong kich hoat `taskPrepareReviewContext` va `callAiReviewKoc`.
  - `searchRound` tang len 1, workflow tiep tuc vong search tiep theo.

---

### 4.5. TC-FLOW-05 (Scenario S5): Tich luy du targetCount qua nhieu luot
- **Tieu de:** Workflow tich luy du so luong candidate yeu cau va chuyen sang phe duyet
- **Tien dieu kien:**
  - `targetCount = 3`, `searchBatchSize = 2`, `maxSearchRounds = 5`.
- **Cac buoc thuc hien:**
  1. Round 1: Search tra 2 candidates (`fb-01`, `fb-02`), Review dat ca 2 (`fb-01`, `fb-02` qualified) -> `qualifiedCount = 2 < targetCount (3)` -> `enoughCandidates = false` -> Round tang len 1 -> Loop tiep round 2.
  2. Round 2: Search tra 2 candidates moi (`fb-03`, `fb-04`), Review dat 1 candidate (`fb-03` qualified) -> `qualifiedCount = 3 == targetCount (3)`.
- **Ket qua mong doi:**
  - Node `taskProcessReviewResults` tinh `qualifiedCount = 3 >= targetCount (3)` -> set `enoughCandidates = true`.
  - Gateway `gwCheckCandidatesThreshold` re sang nhanh `f_enough_candidates`.
  - Chuyen den `taskUpdateStatusUserTask` -> Cap nhat campaign status thanh `USER_TASK`.
  - Dung tai `userTaskApproveCandidates`.
  - Bien `qualifiedCandidates` chua day du 3 ung vien (`fb-01`, `fb-02`, `fb-03`).

---

### 4.6. TC-FLOW-06 (Scenario S6): Chay het maxSearchRounds ma chua du targetCount
- **Tieu de:** Canh bao het chu ky tim kiem, dung tai User Task quyet dinh
- **Tien dieu kien:**
  - `targetCount = 5`, `maxSearchRounds = 2`.
- **Cac buoc thuc hien:**
  1. Round 1: Tim duoc 1 qualified candidate -> `qualifiedCount = 1`. Advance round len 1. `searchRound (1) < roundLimit (2)` -> Tiep tuc round 2.
  2. Round 2: Tim duoc 1 qualified candidate -> `qualifiedCount = 2`. Advance round len 2.
  3. Kiem tra tai Gateway `gwCheckRoundsRemaining`.
- **Ket qua mong doi:**
  - Tai `taskAdvanceSearchRound`: `searchRound` dat gia tri 2, `roundLimit` la 2.
  - Bien `roundsRemaining = false`.
  - Gateway `gwCheckRoundsRemaining` re theo nhanh `f_no_rounds_remaining`.
  - Node `taskUpdateStatusUserDecision` cap nhat campaign status thanh `USER_TASK`.
  - Workflow dung tai User Task `userTaskDiscoveryDecision` ("Decision: Find More or Stop").
  - Nhiem vu hien thi day du bien: `qualifiedCandidates` (2 items), `qualifiedCount` (2), `targetCount` (5), `searchRound` (2).

---

### 4.7. TC-FLOW-07 (Scenario S7): Nguoi dung chon FIND_MORE tai Checkpoint
- **Tieu de:** Nguoi dung quyet dinh cap them mot chu ky tim kiem moi
- **Tien dieu kien:**
  - Workflow dang dung tai `userTaskDiscoveryDecision` sau khi het 3 rounds cu (`roundLimit = 3`, `searchRound = 3`, `qualifiedCount = 2`).
- **Cac buoc thuc hien:**
  1. Complete User Task `userTaskDiscoveryDecision` voi payload: `{"discoveryDecision": "FIND_MORE"}`.
  2. Theo doi Gateway `gwCheckDiscoveryDecision`.
- **Ket qua mong doi:**
  - Gateway `gwCheckDiscoveryDecision` re sang nhanh `f_decision_find_more`.
  - Node `taskUpdateStatusRunning` cap nhat campaign status ve lai `RUNNING`.
  - Node `taskExtendSearchCycle` thuc hien: `roundLimit = roundLimit (3) + maxSearchRounds (3) = 6`.
  - Bien `searchHistory`, `seenProfileIds`, `seenProfileUrls`, `qualifiedCandidates` giu nguyen 100%, khong bi reset.
  - Sequence flow `f_cycle_to_prepare_search` dua workflow quay tro lai `taskPrepareSearchContext` de thuc hien Round 4.

---

### 4.8. TC-FLOW-08 (Scenario S8): Nguoi dung chon STOP tai Checkpoint
- **Tieu de:** Nguoi dung chap nhan so luong hien co va dung tim kiem de phe duyet
- **Tien dieu kien:**
  - Workflow dang dung tai `userTaskDiscoveryDecision` voi 2 candidates da tich luy.
- **Cac buoc thuc hien:**
  1. Complete User Task `userTaskDiscoveryDecision` voi payload: `{"discoveryDecision": "STOP"}`.
  2. Theo doi Gateway `gwCheckDiscoveryDecision`.
- **Ket qua mong doi:**
  - Gateway `gwCheckDiscoveryDecision` re sang nhanh `f_decision_stop` (default sequence flow).
  - Node `taskUpdateStatusUserTask` giu campaign status la `USER_TASK`.
  - Workflow chuyen thang den `userTaskApproveCandidates` voi danh sach 2 ung vien hien co.
  - KHONG tu dong luu ung vien vao MongoDB khi chua qua buoc phe duyet cua nguoi dung.

---

### 4.9. TC-FLOW-09 (Scenario S9): Phe duyet danh sach ung vien thanh cong
- **Tieu de:** Nguoi dung phe duyet danh sach KOC, luu database va hoan tat campaign
- **Tien dieu kien:**
  - Workflow dang dung tai `userTaskApproveCandidates` voi 3 qualified candidates.
- **Cac buoc thuc hien:**
  1. Complete User Task `userTaskApproveCandidates` voi payload: `{"approved": true}`.
  2. Theo doi Gateway `gwCheckApproval`.
- **Ket qua mong doi:**
  - Gateway `gwCheckApproval` re sang nhanh `f_approved`.
  - Node `taskSaveKocCandidates` duoc goi: thuc hien luu danh sach ung vien vao collection `koc_candidates` trong MongoDB thong qua `KocCandidateService.saveBatch(...)`.
  - Node `taskUpdateStatusCompleted` cap nhat campaign status thanh `COMPLETED`.
  - Workflow ket thuc thanh cong tai `endSuccess`.
  - Trinh tu chuyen trang thai campaign: `RUNNING` -> `USER_TASK` -> `COMPLETED`.

---

### 4.10. TC-FLOW-10 (Scenario S10): Tu choi / Huy danh sach ung vien
- **Tieu de:** Nguoi dung tu choi ket qua tim kiem, cham dut quy trinh
- **Tien dieu kien:**
  - Workflow dang dung tai `userTaskApproveCandidates`.
- **Cac buoc thuc hien:**
  1. Complete User Task `userTaskApproveCandidates` voi payload: `{"approved": false}`.
  2. Theo doi Gateway `gwCheckApproval`.
- **Ket qua mong doi:**
  - Gateway `gwCheckApproval` re sang nhanh `f_rejected` (default sequence flow).
  - Khong goi `taskSaveKocCandidates` (khong co candidate nao duoc ghi vao database).
  - Node `taskUpdateStatusRejected` cap nhat campaign status thanh `TERMINATED`.
  - Workflow ket thuc tai `endRejected`.
  - Trinh tu chuyen trang thai campaign: `RUNNING` -> `USER_TASK` -> `TERMINATED`.

---

### 4.11. TC-FLOW-11 (Scenario S11): Kiem tra tinh toan ven cau truc BPMN XML (Static Audit)
- **Tieu de:** Kiem tra tap tin BPMN XML khong con bieu thuc execution cu, khong con endFailed hay retryCount
- **Tien dieu kien:**
  - File `koc_candidate_discovery_process.bpmn20.xml` co san tren classpath resources.
- **Cac buoc thuc hien:**
  1. Doc noi dung XML duoi dang chuoi UTF-8.
  2. Kiem tra su vang mat (must NOT contain) cua cac tu khoa loi thoi:
     - `execution.getVariable`
     - `endFailed`
     - `taskUpdateStatusFailed`
     - `retryCount`
     - `maxRetries`
     - `ExpandSearchCriteriaDelegate`
  3. Kiem tra su hien dien (must contain) cua cac component v2:
     - `InitializeDiscoveryStateDelegate`
     - `PrepareSearchContextDelegate`
     - `RecordSearchOutputDelegate`
     - `PrepareReviewContextDelegate`
     - `AdvanceSearchRoundDelegate`
     - `ExtendSearchCycleDelegate`
     - `userTaskDiscoveryDecision`
     - `userTaskApproveCandidates`
     - Bien dieu kien gateway: `${loginRequired}`, `${hasNewCandidates}`, `${enoughCandidates}`, `${roundsRemaining}`, `${discoveryDecision == 'FIND_MORE'}`, `${approved}`.
- **Ket qua mong doi:**
  - Tat ca assertions deu PASS, XML sach 100% anti-patterns cu.

---

### 4.12. TC-FLOW-12 (Scenario S12): Engine Parse va Deploy Process Definition thanh cong
- **Tieu de:** Flowable Engine thuc te phan tich cu phap va deploy process thanh cong
- **Tien dieu kien:**
  - Flowable Spring Process Engine duoc khoi tao hop le.
- **Cac buoc thuc hien:**
  1. Su dung `BpmnXMLConverter.convertToBpmnModel(...)` de parse XML.
  2. Thuc hien deploy quy trinh thong qua `engine.getRepositoryService().createDeployment().addString(...).deploy()`.
  3. Query `ProcessDefinition` tu RepositoryService bang process key `kocCandidateDiscoveryProcess`.
- **Ket qua mong doi:**
  - Khong co exception cu phap BPMN.
  - Deployment ID khong null.
  - ProcessDefinition lay ra co key `kocCandidateDiscoveryProcess`, name "KOC Candidate Discovery & Evaluation Workflow", version >= 1.

---

## 5. Kiem thu Kich ban bien & Ngoai le (Boundary & Edge Cases)

| Ma Case | Mo ta | Input bien | Hanh vi mong doi |
|---|---|---|---|
| **EDGE-01** | `searchBatchSize = 1` | `searchBatchSize = 1` | Output schema chi yeu cau `maxItems: 1`. Workflow chay binh thuong tung ung vien. |
| **EDGE-02** | `targetCount = 1` | `targetCount = 1` | Ngay khi luot 1 tim duoc 1 qualified candidate -> `enoughCandidates = true`, chuyen thang sang phe duyet. |
| **EDGE-03** | Khong tim thay tai khoan Facebook | Account search tra ve rong | `LoadAccountContextDelegate` throw exception ro rang -> Flowable tao incident, khong chay AI voi account rong. |
| **EDGE-04** | AI tra ve candidate thieu field bat buoc | `fullName` null hoac thieu `profileUrl` | `RecordSearchOutputDelegate` bo qua item khong hop le, khong gay NPE. |
| **EDGE-05** | Keyword da dung nhung cursor moi | `cursorUsed = "cur-02"` | Chap nhan hop le va ghi nhan vao `searchHistory`. |
| **EDGE-06** | Lap lai chinh xac `(keyword, cursorUsed)` | Trung cap `(keyword, cursorUsed)` da co trong `searchHistory` | `RecordSearchOutputDelegate` bo qua duplicate attempt de tranh loop vo han. |

---

## 6. Pre-CD Gate Checklist (Tieu chi nghiem thu Local Gate)

- [ ] Toan bo 12 scenarios Flowable Integration Tests duoc dinh nghia va thuc thi tren engine Flowable.
- [ ] Subprocess `AI_WORKFLOW_PROCESS` va `hitlFacebookLoginProcess` duoc mock dung contract va xu ly ca truong hop pass/fail/login required.
- [ ] Log backend sach loi (khong co unexpected NullPointerException, ClassCastException, BPMN parse error).
- [ ] Trang thai campaign database chuyen doi dung: `RUNNING` -> `USER_TASK` -> `COMPLETED`/`TERMINATED`.
- [ ] Khong co truong hop nao campaign bi set trang thai `FAILED` do ket qua AI task.
