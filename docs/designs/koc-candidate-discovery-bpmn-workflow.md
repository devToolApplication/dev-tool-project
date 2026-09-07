# Thiết kế: KOC Candidate Discovery Loop v2

- **Ngày:** 2026-09-07
- **Trạng thái:** APPROVED
- **Phạm vi:** BPMN `kocCandidateDiscoveryProcess`, campaign configuration, AI Search/Review contract và Flowable delegates
- **Thay thế:** Thiết kế vòng lặp `retryCount/maxRetries` trước đây

## 1. Mục tiêu

Thiết kế lại quy trình tìm KOC thành vòng lặp có giới hạn và có trạng thái rõ ràng:

1. Mỗi lượt AI Search trả tối đa `searchBatchSize` ứng viên.
2. AI Review giữ tất cả ứng viên đạt tiêu chí, từ 0 đến N người mỗi batch.
3. Ứng viên đạt chuẩn được tích lũy qua nhiều lượt cho đến khi đủ `targetCount`.
4. Nếu hết một chu kỳ mà chưa đủ, người dùng chọn `FIND_MORE` hoặc `STOP`.
5. Mỗi lượt Search nhận lịch sử keyword, cursor và profile đã thấy của chính workflow để hạn chế tìm trùng.
6. Không có nhánh BPMN `FAILED` cho kết quả AI task. Lỗi đăng nhập đi qua Facebook Login; lỗi AI khác bỏ batch và chuyển sang lượt kế tiếp.
7. BPMN không dùng `execution.getVariable(...)`. Gateway chỉ đọc biến process ngắn, có ý nghĩa nghiệp vụ.

## 2. Quyết định đã chốt

| Chủ đề | Quyết định |
|---|---|
| Hết chu kỳ nhưng chưa đủ | Dừng tại User Task để chọn `FIND_MORE` hoặc `STOP` |
| `FIND_MORE` | Cấp thêm một chu kỳ gồm `maxSearchRounds` lượt |
| State khi tìm tiếp | Giữ nguyên ứng viên đạt, lịch sử search, cursor và profile đã thấy |
| `STOP` | Chuyển sang User Task phê duyệt danh sách hiện có |
| Lỗi AI thông thường | Ghi lỗi, bỏ batch hiện tại, tăng lượt và tiếp tục |
| `MCP_FACEBOOK_LOGIN_REQUIRED` | Gọi subprocess Facebook Login; sau đó bỏ batch hiện tại và sang lượt Search mới |
| Login vẫn chưa thành công | Bỏ batch và sang lượt Search mới; không retry Login vô hạn |
| Search không có ứng viên mới | Bỏ qua Review và sang lượt Search kế tiếp |
| Review batch | Giữ mọi ứng viên đạt tiêu chí; không bắt buộc đúng X người |
| Cấu hình giới hạn | Thuộc campaign; mặc định `searchBatchSize=10`, `maxSearchRounds=3` |
| Context chống trùng | Chỉ gửi lịch sử của workflow hiện tại; backend vẫn lọc unique toàn bảng |
| Cursor | Lưu theo từng keyword/truy vấn, không dùng một cursor chung cho cả batch |

## 3. Kiến trúc BPMN

```text
Start
  |
  v
Initialize Discovery State
  |
  v
Load Facebook Account
  |
  v
Prepare Search Context
  |
  v
Call AI Search (max N)
  |
  v
Record Search Output
  |
  v
loginRequired? -- true --> Facebook Login Subprocess --+
  |                                                       |
 false                                                    |
  v                                                       |
Filter Duplicate Candidates                              |
  |                                                       |
  v                                                       |
hasNewCandidates? -- false -------------------------------+
  |
 true
  v
Prepare Review Context
  |
  v
Call AI Review
  |
  v
Process Review Output
  |
  v
loginRequired? -- true --> Facebook Login Subprocess -----+
  |                                                       |
 false                                                    |
  v                                                       |
enoughCandidates? -- false -------------------------------+
  |                                                       |
 true                                                     |
  v                                                       |
Set Campaign USER_TASK                                    |
  |                                                       |
  v                                                       |
Approve Candidate List                                    |
  |                                                       |
  +-- approved --> Save --> Set COMPLETED --> End          |
  |                                                       |
  +-- rejected --> Set TERMINATED --> End                  |
                                                          |
                    +-------------------------------------+
                    v
              Advance Search Round
                    |
                    v
              roundsRemaining?
                | true
                +------> Prepare Search Context
                |
                | false
                v
          Set Campaign USER_TASK
                |
                v
       User: FIND_MORE or STOP
          |                 |
      FIND_MORE            STOP
          |                 |
          v                 +------> Approve Candidate List
 Set Campaign RUNNING
          |
          v
 Grant One More Cycle
          |
          +------> Prepare Search Context
```

### 3.1. Quy tắc vòng lặp

- `searchRound` là số lượt Search đã hoàn tất xử lý.
- `roundLimit` khởi tạo bằng `maxSearchRounds`.
- Mọi đường của một lượt, gồm Search lỗi, Login, Search rỗng, Review lỗi và Review thành công nhưng chưa đủ, đều đi qua đúng một `AdvanceSearchRoundDelegate`.
- `roundsRemaining = searchRound < roundLimit` sau khi tăng lượt.
- `FIND_MORE` thực hiện `roundLimit = roundLimit + maxSearchRounds`.
- Vòng lặp tự động luôn hữu hạn. Chỉ người dùng mới có thể cấp thêm chu kỳ.

## 4. Gateway và expression

Gateway chỉ dùng các biến boolean hoặc enum đã được Delegate tính trước:

```text
${loginRequired}
${hasNewCandidates}
${enoughCandidates}
${roundsRemaining}
${discoveryDecision == 'FIND_MORE'}
${approved}
```

Các field/input đơn giản dùng process variable trực tiếp:

```text
${campaignId}
${searchPrompt}
${reviewPrompt}
${approverAssignee}
```

Không dùng `execution.getVariable(...)`, không đọc nested map trong gateway và không đặt phép tính count/retry trong XML.

## 5. Process variables

| Biến | Kiểu | Nguồn / ý nghĩa |
|---|---|---|
| `campaignId` | String | Input bắt buộc |
| `targetCount` | Integer > 0 | Campaign |
| `minScore` | Number | Campaign |
| `searchBatchSize` | Integer > 0 | Campaign; mặc định lưu là 10 |
| `maxSearchRounds` | Integer > 0 | Campaign; mặc định lưu là 3 |
| `searchRound` | Integer | Số lượt đã dùng, khởi tạo 0 |
| `roundLimit` | Integer | Giới hạn hiện tại, khởi tạo bằng `maxSearchRounds` |
| `searchHistory` | Array<SearchAttempt> | Keyword/cursor đã dùng trong workflow |
| `seenProfileIds` | Set<String> | ID profile AI đã trả trong workflow |
| `seenProfileUrls` | Set<String> | URL profile AI đã trả trong workflow |
| `uniqueCandidates` | Array<Candidate> | Batch mới sau khi lọc trùng |
| `qualifiedCandidates` | Array<ReviewedCandidate> | Ứng viên đạt chuẩn tích lũy |
| `qualifiedCount` | Integer | Kích thước `qualifiedCandidates` |
| `loginRequired` | Boolean | Kết quả phân loại output của AI task hiện tại |
| `hasNewCandidates` | Boolean | Batch Search còn ứng viên sau lọc trùng |
| `enoughCandidates` | Boolean | `qualifiedCount >= targetCount` |
| `roundsRemaining` | Boolean | `searchRound < roundLimit` |
| `discoveryDecision` | `FIND_MORE` hoặc `STOP` | Output của User Task quyết định |
| `lastErrorStage` | `SEARCH`, `REVIEW` hoặc `LOGIN` | Stage lỗi gần nhất |
| `lastErrorCode` | String | Mã lỗi gần nhất |
| `lastErrorMessage` | String | Thông báo lỗi gần nhất |
| `lastErrorAtRound` | Integer | Lượt xảy ra lỗi gần nhất |
| `threadId` | String | Thread AI được giữ xuyên suốt workflow |

## 6. AI Search contract

### 6.1. Output schema

`PrepareSearchContextDelegate` tạo schema dạng `Map<String,Object>` và gán `maxItems` của `candidates` bằng `searchBatchSize`. Call Activity truyền biến này qua `outputSchema`, không đặt JSON escaped dài trong BPMN.

```json
{
  "type": "object",
  "properties": {
    "status": {
      "type": "string",
      "enum": ["SUCCESS", "FAILED"]
    },
    "errorCode": {
      "type": "string",
      "enum": [
        "NONE",
        "MCP_FACEBOOK_LOGIN_REQUIRED",
        "RATE_LIMIT_EXCEEDED",
        "ACCOUNT_CHECKPOINT",
        "SEARCH_FAILED"
      ]
    },
    "errorMessage": { "type": "string" },
    "searches": {
      "type": "array",
      "items": {
        "type": "object",
        "properties": {
          "keyword": { "type": "string", "minLength": 1 },
          "cursorUsed": { "type": ["string", "null"] },
          "nextCursor": { "type": ["string", "null"] }
        },
        "required": ["keyword", "cursorUsed", "nextCursor"],
        "additionalProperties": false
      }
    },
    "candidates": {
      "type": "array",
      "maxItems": 10,
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
        "required": ["externalProfileId", "fullName", "profileUrl"],
        "additionalProperties": false
      }
    }
  },
  "required": ["status", "errorCode", "errorMessage", "searches", "candidates"],
  "additionalProperties": false
}
```

`maxItems: 10` ở ví dụ trên được thay bằng giá trị `searchBatchSize` thực tế của campaign.

### 6.2. SearchAttempt

```json
{
  "round": 2,
  "keyword": "khoe thành tích học tập của con",
  "cursorUsed": "cursor-01",
  "nextCursor": "cursor-02"
}
```

Cặp `(normalizedKeyword, cursorUsed)` là khóa chống lặp. Keyword được chuẩn hóa bằng trim và lowercase để so sánh. Một keyword được dùng lại chỉ khi AI sử dụng `nextCursor` chưa từng dùng của chính keyword đó.

### 6.3. Search requestContext

```json
{
  "accountContext": {
    "accountId": "...",
    "accountType": "FACEBOOK",
    "accountUsername": "...",
    "accountPassword": "..."
  },
  "campaign": {
    "campaignId": "...",
    "niche": "LIFESTYLE",
    "searchCriteria": "...",
    "targetCount": 20,
    "qualifiedCount": 8,
    "remainingCount": 12
  },
  "searchControl": {
    "round": 4,
    "maxCandidates": 10,
    "searchHistory": [],
    "seenProfileIds": [],
    "seenProfileUrls": []
  }
}
```

Quy tắc cho AI Search:

1. Trả tối đa `maxCandidates` ứng viên.
2. Không trả profile nằm trong `seenProfileIds` hoặc `seenProfileUrls`.
3. Ưu tiên `nextCursor` chưa dùng. Nếu không còn cursor thì tạo keyword mới chưa dùng.
4. Ghi mọi keyword/cursor thực sự đã thử vào `searches`, kể cả khi không tìm thấy ứng viên.
5. Nếu Facebook MCP yêu cầu đăng nhập, trả `status=FAILED` và `errorCode=MCP_FACEBOOK_LOGIN_REQUIRED`.

`SubmitAiTaskDelegate` chỉ chuyển `requestContext`; không tự bổ sung business context.

## 7. AI Review contract

### 7.1. Review requestContext

`PrepareReviewContextDelegate` dựng context riêng cho Review từ `accountContext`, tiêu chí campaign và `uniqueCandidates`. Search history không cần gửi vào Review.

```json
{
  "accountContext": {},
  "campaign": {
    "campaignId": "...",
    "reviewCriteria": "...",
    "minScore": 70
  },
  "candidates": []
}
```

### 7.2. Review output

```json
{
  "status": "SUCCESS",
  "errorCode": "NONE",
  "errorMessage": "",
  "candidates": [
    {
      "externalProfileId": "fb-123",
      "fullName": "Candidate A",
      "profileUrl": "https://facebook.com/...",
      "score": 82,
      "isQualified": true,
      "strengths": ["..."],
      "risks": ["..."],
      "reviewNote": "..."
    }
  ]
}
```

Review được phép trả từ 0 đến `uniqueCandidates.size()` ứng viên đạt chuẩn. Backend chỉ tích lũy item có `isQualified=true` và không trùng `externalProfileId` hoặc `profileUrl`.

## 8. Trách nhiệm Delegate

### 8.1. `InitializeDiscoveryStateDelegate`

- Validate input bắt buộc và giá trị dương.
- Khởi tạo `searchRound=0`, `roundLimit=maxSearchRounds`.
- Khởi tạo collection rỗng cho history, seen profiles và qualified candidates.
- Không ghi đè state khi process đang tiếp tục từ User Task.

### 8.2. `PrepareSearchContextDelegate`

- Dựng `requestContext` Search từ dữ liệu process đã được khai báo.
- Tính `remainingCount`.
- Tạo `searchOutputSchema` có `maxItems=searchBatchSize`.
- Không query toàn bộ KOC trong database và không chèn dữ liệu ngoài contract.

### 8.3. `RecordSearchOutputDelegate`

- Parse output theo contract mạnh.
- Reset rồi đặt `loginRequired` cho lượt Search hiện tại.
- Append `searches` vào `searchHistory`, không lặp khóa `(keyword, cursorUsed)`.
- Append ID/URL của mọi candidate hợp lệ vào seen sets trước bước lọc DB.
- Nếu lỗi không phải login hoặc output không hợp lệ: ghi `lastError*`, đặt batch Search rỗng.
- Không giả lập candidate và không đổi lỗi thành success.

### 8.4. `FilterDuplicateCandidatesDelegate`

- Lọc trùng trong batch.
- Lọc trùng với `qualifiedCandidates` của workflow.
- Lọc unique toàn collection `koc_candidates` qua Service/Storage hiện có.
- Gán `uniqueCandidates` và `hasNewCandidates`.

### 8.5. `PrepareReviewContextDelegate`

- Dựng `requestContext` Review chứa đúng batch `uniqueCandidates` và review criteria.
- Tạo `reviewOutputSchema`.
- Reset cờ phân loại của Review.

### 8.6. `ProcessReviewResultsDelegate`

- Phân loại login required và lỗi thường.
- Lỗi thường không thay đổi `qualifiedCandidates`.
- Thành công chỉ tích lũy candidate đạt chuẩn và chưa có trong danh sách.
- Gán `qualifiedCount` và `enoughCandidates`.

### 8.7. `AdvanceSearchRoundDelegate`

- Tăng `searchRound` đúng một lần.
- Gán `roundsRemaining`.

### 8.8. `ExtendSearchCycleDelegate`

- Thực hiện `roundLimit += maxSearchRounds` khi `discoveryDecision=FIND_MORE`.
- Không reset bất kỳ kết quả hoặc history nào.

### 8.9. `UpdateCampaignStatusDelegate`

- Chỉ nhận `status` qua `flowable:field`.
- Lấy `campaignId` trực tiếp từ process variable.
- Không cần field expression `${execution.getVariable('campaignId')}`.

`ExpandSearchCriteriaDelegate` cũ bị loại bỏ vì prompt/context của lượt mới được dựng từ state có cấu trúc, không nối thêm prompt tự do.

## 9. Xử lý lỗi

### 9.1. Kết quả AI task

| Kết quả | Xử lý BPMN |
|---|---|
| `MCP_FACEBOOK_LOGIN_REQUIRED` | Gọi Facebook Login, sau đó Advance Round |
| Rate limit, timeout, lỗi tool khác | Ghi `lastError*`, bỏ batch, Advance Round |
| Output sai schema | Ghi lỗi invalid output, bỏ batch, Advance Round |
| Search thành công nhưng rỗng | Ghi history, bỏ qua Review, Advance Round |
| Search chỉ trả candidate trùng | Bỏ qua Review, Advance Round |
| Review lỗi | Không tích lũy batch, Advance Round |
| Review thành công nhưng chưa đủ | Tích lũy batch, Advance Round |

Không có `taskUpdateStatusFailed`, `endFailed` hoặc campaign status `FAILED` do kết quả AI task.

### 9.2. Lỗi hạ tầng

Lỗi làm Delegate không thể thực hiện trách nhiệm, ví dụ MongoDB không lưu được, thiếu bean bắt buộc hoặc Flowable không deploy được process, phải throw exception để Flowable tạo incident. Không catch rồi giả lập `SUCCESS`, không bỏ qua lỗi lưu dữ liệu và không tạo dữ liệu fallback.

## 10. Campaign lifecycle

| Trạng thái | Khi nào dùng |
|---|---|
| `RUNNING` | Search, Login, Review và xử lý tự động; đặt lại khi người dùng chọn `FIND_MORE` |
| `USER_TASK` | Chờ quyết định `FIND_MORE/STOP` hoặc chờ phê duyệt candidate |
| `COMPLETED` | Đã lưu xong danh sách người dùng phê duyệt, kể cả danh sách 0 người |
| `TERMINATED` | Người dùng từ chối/hủy tại bước phê duyệt |

Nếu User Task chưa được hoàn thành, campaign giữ `USER_TASK` và process giữ trạng thái chạy/chờ của Flowable.

## 11. Campaign model và API

Thêm hai field vào Entity, Create DTO, Update DTO và Response:

```text
searchBatchSize: Integer, default 10, min 1
maxSearchRounds: Integer, default 3, min 1
```

Business default được áp dụng và lưu rõ khi tạo campaign; đây không phải fallback khi AI lỗi. Process start luôn truyền hai giá trị đã validate. Dữ liệu campaign cũ được backfill giá trị 10 và 3 trước khi dùng flow v2.

## 12. User Tasks

### 12.1. `userTaskDiscoveryDecision`

Input hiển thị:

- `qualifiedCandidates`
- `qualifiedCount`
- `targetCount`
- `searchRound`
- `lastErrorCode`, `lastErrorMessage`

Output bắt buộc:

```text
discoveryDecision = FIND_MORE | STOP
```

### 12.2. `userTaskApproveCandidates`

Input là `qualifiedCandidates`. Output giữ contract hiện tại gồm `approved` và danh sách ứng viên được chọn. `STOP` không tự động lưu ứng viên; luôn đi qua bước phê duyệt.

## 13. Phạm vi code thay đổi

1. Thiết kế lại `koc_candidate_discovery_process.bpmn20.xml` theo luồng tại mục 3.
2. Thêm các Delegate quản lý state/search context/review context/round.
3. Chuẩn hóa `ProcessReviewResultsDelegate`, `FilterDuplicateCandidatesDelegate` và `UpdateCampaignStatusDelegate` theo trách nhiệm mới.
4. Xóa `ExpandSearchCriteriaDelegate` sau khi không còn reference.
5. Thêm `searchBatchSize`, `maxSearchRounds` vào campaign Entity và API DTO.
6. Truyền hai cấu hình mới trong `KocCampaignService` khi start workflow.
7. Đồng bộ BPMN XML mới vào `workflow_versions` sau khi build/deploy service thành công.

Không thay đổi cơ chế gọi AI qua `AI_WORKFLOW_PROCESS`; business process vẫn dùng Call Activity.

## 14. Kiểm thử

### 14.1. Unit tests

- Initialize state với cấu hình hợp lệ và reject giá trị không dương.
- Prepare Search Context truyền đúng N, remaining count, history và seen sets.
- Record Search Output lưu từng keyword/cursor, không lặp cặp đã dùng.
- Record Search Output phân loại đúng login required và lỗi thường.
- Filter Duplicate loại trùng trong batch, trong workflow và toàn DB.
- Process Review chỉ tích lũy `isQualified=true`, không tạo trùng.
- Advance Round tăng đúng một lần và tính đúng `roundsRemaining`.
- Extend Cycle tăng đúng `maxSearchRounds` và giữ state.
- Campaign service lưu và truyền `searchBatchSize`, `maxSearchRounds`.

### 14.2. Flowable integration tests

1. Search lỗi thường bỏ qua Review rồi chạy lượt kế tiếp.
2. Search login required gọi Login rồi chạy Search mới cùng `threadId`.
3. Review login required gọi Login, bỏ batch Review và chạy Search mới.
4. Search rỗng hoặc toàn candidate trùng bỏ qua Review.
5. Nhiều lượt Search/Review tích lũy đủ target rồi chuyển Approval.
6. Hết chu kỳ chưa đủ tạo `userTaskDiscoveryDecision`.
7. `FIND_MORE` giữ state, đặt campaign `RUNNING` và cấp thêm đúng một chu kỳ.
8. `STOP` chuyển sang Approval với danh sách hiện có.
9. Approval thành công lưu candidate và đặt `COMPLETED`.
10. Approval từ chối đặt `TERMINATED`.
11. BPMN không chứa `execution.getVariable`, `endFailed`, `taskUpdateStatusFailed`, `retryCount` hoặc `maxRetries`.
12. BPMN parse/deploy được trên Flowable thật.

Validation cuối:

```text
ai-agent-mcrs: .\mvnw.cmd test
ai-agent-sdk-service: npm run typecheck && npm test
```

## 15. Tiêu chí chấp nhận

- Một AI Search không thể trả quá N candidate theo output schema của lượt chạy.
- Workflow không tự động chạy quá `roundLimit`.
- Người dùng có thể cấp thêm từng chu kỳ hoặc dừng để duyệt kết quả hiện có.
- Không có nhánh kết thúc thất bại do AI task.
- Login required luôn qua subprocess Facebook Login.
- Lỗi AI khác không làm mất candidate/history đã tích lũy.
- Search context vòng sau chứa keyword/cursor và profile đã thấy của workflow.
- Cùng cặp keyword/cursor không được sử dụng lại; cùng keyword chỉ được tiếp tục bằng cursor mới.
- Backend vẫn bảo đảm candidate unique toàn bảng.
- Sơ đồ BPMN không còn expression truy cập `execution` trực tiếp.
- Mọi lỗi hạ tầng vẫn hiển thị minh bạch dưới dạng Flowable incident.
