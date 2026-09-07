# Design: Quy trình BPMN Tìm kiếm & Đánh giá Ứng viên KOC (KOC Candidate Discovery & Evaluation)

- **Date:** 2026-09-06
- **Branch:** main
- **Repo:** devToolApplication/dev-tool-project
- **Status:** APPROVED
- **Mode:** Startup / Enterprise Architecture
- **Architecture Approach:** Phương án B (Có vòng lặp AI Re-search tự động khi chưa đủ số lượng đạt chuẩn)

---

## 1. Problem Statement & Mục tiêu

Hệ thống cần tự động hoá quy trình tuyển chọn ứng viên KOC (Key Opinion Consumer) cho các chiến dịch Marketing:
1. Tìm kiếm danh sách KOC tiềm năng trên mạng xã hội (Facebook/Instagram/TikTok) dựa trên tiêu chí chiến dịch (ngành hàng, độ tương tác, số follower).
2. Dùng AI Agent độc lập thẩm định, đánh giá chất lượng profile, lọc tương tác ảo và chấm điểm độ phù hợp (score 1-100).
3. Đảm bảo số lượng ứng viên đạt chuẩn tối thiểu trước khi chuyển cho quản trị viên/trưởng chiến dịch duyệt.
4. Cung cấp User Task (Human-in-the-Loop) để chuyên viên xét duyệt, tinh chỉnh danh sách cuối cùng.
5. Lưu kết quả đã phê duyệt vào MongoDB collection `koc_candidates` để phục vụ các khâu liên hệ, gửi hợp đồng và theo dõi chiến dịch sau này.

---

## 2. Tiền đề & Ràng buộc Thiết kế (Premises & Invariants)

1. **Sub-process Quy chuẩn:** Mọi tác vụ gọi AI Agent bắt buộc sử dụng **BPMN Call Activity** gọi sub-process `AI_WORKFLOW_PROCESS` (không dùng direct service task) theo quy chuẩn kiến trúc của dự án.
2. **Quản lý dữ liệu qua Process Variables:** Dữ liệu ứng viên truyền giữa các node dưới dạng mảng JSON có cấu trúc rõ ràng (`outputSchema` chặt chẽ):
   - `rawCandidates`: Danh sách KOC thô tìm được từ AI Search.
   - `reviewedCandidates`: Danh sách đã qua AI Review và chấm điểm.
   - `approvedCandidates`: Danh sách được chuyên viên đánh dấu chấp thuận trong User Task.
3. **Tuân thủ Backend Architecture (`docs/note/be-note.md`):**
   - Không inject trực tiếp `Repository` vào `Delegate` hoặc `Service`.
   - Tất cả tương tác database phải qua tầng trung gian `Storage` (`infrastructure/storage`).
   - Mọi Service kế thừa `BaseService`, sử dụng `mapperUtil`.
   - Viết Unit Tests đầy đủ cho Delegate và Service (`*ServiceTest.java`).

---

## 3. Kiến trúc Luồng BPMN 2.0 (Flowable Process)

### 3.1. Sơ đồ các bước thực thi

```
[Start Event]
      │
      ▼
[Call Activity: AI Search KOC (callAiSearchKoc)]
      │ (agentCode: 'facebook-agent', skill: facebook-collect, provider: codex/claude)
      ▼
[Service Task: Filter Duplicate Candidates (taskDeduplicateCandidates)]
      │ (Delegate: filterDuplicateCandidatesDelegate - Kiểm tra DB & deduplicate theo externalProfileId/profileUrl)
      ▼
[Call Activity: AI Review & Score (callAiReviewKoc)]
      │ (agentCode: 'facebook-agent', skill: facebook-evaluate, provider: codex/claude)
      ▼
[Exclusive Gateway: Check Qualified Threshold (gwCheckThreshold)]
      ├── [Chưa đủ KOC & retryCount < maxRetries] ──► [Service Task: Expand Keyword & Inc Retry] ──┐
      │                                                                                             │
      │◄────────────────────────────────────────────────────────────────────────────────────────────┘
      │
      └── [Đủ KOC hoặc retryCount >= maxRetries]
            │
            ▼
      [User Task: Human Review & Approval (userTaskApproveCandidates)]
            │ (Assignee: campaign-manager / admin)
            ▼
      [Exclusive Gateway: Is Approved? (gwCheckUserApproval)]
            ├── [approved == true] ──► [Service Task: Save Candidates (saveKocCandidatesDelegate)] ──► [End Success]
            │
            └── [approved == false] ──────────────────────────────────────────────────────────────► [End Cancelled/Rejected]
```

### 3.2. Chi tiết cấu hình từng Node trong BPMN

| Node ID | Node Type | Tên / Vai trò | Cấu hình & Biến Input/Output |
| :--- | :--- | :--- | :--- |
| `startEvent` | StartEvent | Khởi động quy trình | Nhận: `campaignId`, `niche`, `targetCount`, `minFollowers`, `minScore`, `maxRetries` (default: 3). Khởi tạo `retryCount = 0`, `collectedProfileIds = []`. |
| `callAiSearchKoc` | CallActivity | Tìm kiếm ứng viên KOC | `calledElement="AI_WORKFLOW_PROCESS"`. In: `agentCode='facebook-agent'`, `prompt` (thu thập danh sách KOC theo kỹ năng `facebook-collect`), `outputSchema` (Schema danh sách KOC thô). Out: `rawCandidates`. |
| `taskDeduplicateCandidates` | ServiceTask | Khử trùng lặp ứng viên | `flowable:delegateExpression="${filterDuplicateCandidatesDelegate}"`. In: `campaignId`, `rawCandidates`, `collectedProfileIds`. Đối soát với DB (`koc_candidates`) và tập đã thu thập. Out: `uniqueCandidates`, cập nhật `collectedProfileIds`. |
| `callAiReviewKoc` | CallActivity | Đánh giá & chấm điểm KOC | `calledElement="AI_WORKFLOW_PROCESS"`. In: `agentCode='facebook-agent'`, `prompt` (thẩm định profile, đối soát tiêu chí và chấm điểm theo kỹ năng `facebook-evaluate`), `uniqueCandidates`. Out: `reviewedCandidates`, `qualifiedCount`. |
| `gwCheckThreshold` | ExclusiveGateway | Kiểm tra số lượng đạt chuẩn | Điều kiện 1 (Lặp lại): `${qualifiedCount < targetCount && retryCount < maxRetries}`. Điều kiện 2 (Đi tiếp): `${qualifiedCount >= targetCount \|\| retryCount >= maxRetries}`. |
| `taskExpandSearchCriteria` | ServiceTask / ScriptTask | Mở rộng tiêu chí & tăng lượt thử | Tăng `retryCount = retryCount + 1`, mở rộng từ khóa/hashtag. Quay lại `callAiSearchKoc`. |
| `userTaskApproveCandidates` | UserTask | Chuyên viên duyệt danh sách | Form hiển thị danh sách `reviewedCandidates` kèm điểm số, nhận xét AI. Output: `approved = true/false`, `selectedCandidateIds`. |
| `gwCheckUserApproval` | ExclusiveGateway | Rẽ nhánh theo quyết định duyệt | `${approved == true}` sang task lưu; `${approved == false}` kết thúc luồng. |
| `taskSaveKocCandidates` | ServiceTask | Lưu ứng viên vào MongoDB | `flowable:delegateExpression="${saveKocCandidatesDelegate}"`. Nhận `campaignId`, `selectedCandidates`, lưu vào MongoDB collection `koc_candidates`. |
| `endSuccess` / `endRejected` | EndEvent | Kết thúc quy trình | Trả về trạng thái thực thi hoàn tất / từ chối. |

---

## 4. Đặc tả Cấu trúc Dữ liệu & Output Schema

### 4.1. Schema AI Search (`rawCandidates` kèm Error Handling):
```json
{
  "type": "object",
  "properties": {
    "status": { "type": "string", "enum": ["SUCCESS", "FAILED"] },
    "errorCode": {
      "type": "string",
      "enum": ["NONE", "MCP_FACEBOOK_LOGIN_REQUIRED", "RATE_LIMIT_EXCEEDED", "ACCOUNT_CHECKPOINT", "SEARCH_FAILED"]
    },
    "errorMessage": { "type": "string" },
    "candidates": {
      "type": "array",
      "items": {
        "type": "object",
        "properties": {
          "externalProfileId": { "type": "string" },
          "fullName": { "type": "string" },
          "profileUrl": { "type": "string" },
          "platform": { "type": "string" },
          "followerCount": { "type": "number" },
          "engagementRate": { "type": "number" },
          "niche": { "type": "string" }
        },
        "required": ["externalProfileId", "fullName", "profileUrl"]
      }
    }
  },
  "required": ["status"]
}
```

### 4.2. Schema AI Review & Score (`reviewedCandidates` kèm Error Handling):
```json
{
  "type": "object",
  "properties": {
    "status": { "type": "string", "enum": ["SUCCESS", "FAILED"] },
    "errorCode": {
      "type": "string",
      "enum": ["NONE", "MCP_FACEBOOK_LOGIN_REQUIRED", "RATE_LIMIT_EXCEEDED", "ACCOUNT_CHECKPOINT", "REVIEW_FAILED"]
    },
    "errorMessage": { "type": "string" },
    "qualifiedCount": { "type": "number" },
    "candidates": {
      "type": "array",
      "items": {
        "type": "object",
        "properties": {
          "externalProfileId": { "type": "string" },
          "fullName": { "type": "string" },
          "profileUrl": { "type": "string" },
          "platform": { "type": "string" },
          "score": { "type": "number" },
          "isQualified": { "type": "boolean" },
          "strengths": { "type": "array", "items": { "type": "string" } },
          "risks": { "type": "array", "items": { "type": "string" } },
          "reviewNote": { "type": "string" }
        },
        "required": ["externalProfileId", "score", "isQualified"]
      }
    }
  },
  "required": ["status"]
}
```

### 4.3. Cơ chế Xử lý Lỗi Tự phục hồi (HITL Facebook Login & Thread Retry):
- **Phát hiện lỗi:** Khi `searchErrorCode` hoặc `reviewErrorCode` trả về `MCP_FACEBOOK_LOGIN_REQUIRED`.
- **Rẽ nhánh tự động:** ExclusiveGateway (`gwCheckSearchStatus`, `gwCheckReviewStatus`) chuyển hướng sang CallActivity (`callRecoverFbLoginSearch`, `callRecoverFbLoginReview`) gọi sub-flow `hitlFacebookLoginProcess`.
- **Thực hiện đăng nhập:** Sub-flow xử lý login Facebook với tài khoản `tag = 'LOGIN'`, tự động lấy OTP Gmail qua MCP nếu cần.
- **Tiếp tục luồng (Retry):** Sau khi sub-flow đăng nhập hoàn tất, quy trình quay trở lại gọi AI Task tương ứng, truyền lại nguyên vẹn `threadId` đang dừng để AI tiếp tục thực thi trên session trình duyệt đã được xác thực.

---

## 5. Kế hoạch Triển khai Code (Implementation Scope)

1. **BPMN Definition:**
   - Tạo file BPMN 2.0 XML: `services/ai-agent-mcrs/src/main/resources/processes/koc_candidate_discovery_process.bpmn20.xml`.
2. **Domain & Data Access Layer:**
   - Entity: `com.lamld.aiAgent.modules.koccandidate.domain.entity.KocCandidateEntity` (Mapping MongoDB collection `koc_candidates`).
   - DTOs: Request/Response cho KOC Candidate.
   - Storage Interface & Impl: `KocCandidateStorage` & `KocCandidateStorageImpl` (kế thừa chuẩn của dự án, trung gian giữa Repository và Service).
   - Repository: `KocCandidateRepository` (Spring Data MongoDB).
3. **Application & Delegate Layer:**
   - Service: `KocCandidateService` (extends `BaseService`, quản lý lưu trữ, tra cứu ứng viên theo chiến dịch).
   - Delegate Khử trùng: `FilterDuplicateCandidatesDelegate` (implements `JavaDelegate`, đối soát `externalProfileId` và `profileUrl` với MongoDB `koc_candidates` và tập `collectedProfileIds` trong execution context để loại bỏ ứng viên trùng lặp trước khi gọi AI review).
   - Delegate Lưu: `SaveKocCandidatesDelegate` (implements `JavaDelegate`, trích xuất `selectedCandidates` từ Process Variables và gọi `KocCandidateService.saveBatch(...)`).
4. **Test Suite:**
   - Unit test cho `KocCandidateServiceTest.java`.
   - Unit test cho `FilterDuplicateCandidatesDelegateTest.java`.
   - Unit test cho `SaveKocCandidatesDelegateTest.java`.
   - Flowable integration test mô phỏng toàn bộ quy trình: `KocCandidateDiscoveryWorkflowTest.java` (mocking AI Subprocess và UserTask claim/complete).
