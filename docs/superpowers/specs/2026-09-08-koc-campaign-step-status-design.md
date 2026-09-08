# Thiết kế: Hiển thị Chi tiết Bước Xử lý Hiện tại của Chiến dịch KOC trên Màn hình Danh sách

## 1. Bối cảnh & Mục tiêu (Context & Motivation)

### 1.1. Hiện trạng
- Trên màn hình Quản lý Chiến dịch KOC (`/koc/campaigns`), cột trạng thái hiện tại chỉ hiển thị mã trạng thái quy trình cấp cao dạng badge (`RUNNING`, `USER_TASK`, `COMPLETED`, `FAILED`, `TERMINATED`).
- Khi một chiến dịch đang ở trạng thái `RUNNING`, người dùng không thể biết chiến dịch đang thực hiện công đoạn nào (Khởi tạo tài khoản Facebook, AI đang quét bài viết, lọc ứng viên trùng lặp, AI đang chấm điểm thẩm định tiêu chí, hay đang chuyển sang vòng quét tiếp theo...).
- Muốn biết chi tiết, người dùng bắt buộc phải sao chép `workflowRunId` rồi chuyển sang màn hình tra cứu tiến trình Flowable, gây đứt gãy luồng trải nghiệm và tốn nhiều thao tác.

### 1.2. Mục tiêu cải tiến
1. **Làm rõ bước nghiệp vụ trực tiếp trên bảng danh sách:**
   - Người xem biết ngay chiến dịch đang ở bước nào (Ví dụ: `Quét tìm KOC (Vòng 1/3)`, `Lọc trùng ứng viên`, `Thẩm định KOC`, `Chờ quyết định tìm tiếp`, `Chờ phê duyệt KOC`).
2. **Trực quan hóa dạng Two-Line Smart Badge + Popover tiến trình:**
   - Dòng 1: Badge màu trạng thái tổng thể (`RUNNING` - info, `USER_TASK` - warning, `COMPLETED` - success...).
   - Dòng 2: Icon động/bước kèm tên bước nghiệp vụ và tiến độ vòng `(Vòng X/Y)`.
   - Popover / Tooltip chi tiết: Cung cấp thông tin bổ sung (chi tiết bước xử lý, số KOC đã duyệt / mục tiêu, Run ID).
3. **Hiệu năng & Đồng bộ ổn định:**
   - Lưu trữ trực tiếp thông tin bước vào thực thể MongoDB `koc_campaigns` thông qua các JavaDelegate của Flowable BPMN.
   - Không gây phát sinh N+1 query vào Flowable engine khi tải danh sách chiến dịch.
   - Cơ chế đồng bộ dữ liệu: Cập nhật thủ công qua nút Refresh có sẵn trên thanh công cụ của bảng (không phát sinh request ngầm hay WebSocket phức tạp).

---

## 2. Thiết kế chi tiết Backend (`services/ai-agent-mcrs`)

### 2.1. Mở rộng Mô hình Dữ liệu MongoDB

#### A. Cập nhật `KocCampaignEntity`
- **File:** `services/ai-agent-mcrs/src/main/java/com/lamld/aiAgent/modules/koccampaign/infrastructure/entity/KocCampaignEntity.java`
- Thêm 5 trường thuộc tính:
```java
@Field("current_step")
private String currentStep;

@Field("current_step_title")
private String currentStepTitle;

@Field("current_round")
private Integer currentRound;

@Field("max_rounds")
private Integer maxRounds;

@Field("step_detail")
private String stepDetail;
```

#### B. Cập nhật DTO `KocCampaignResponse`
- **File:** `services/ai-agent-mcrs/src/main/java/com/lamld/aiAgent/modules/koccampaign/api/response/KocCampaignResponse.java`
- Bổ sung các trường trả về cho client:
```java
private String currentStep;
private String currentStepTitle;
private Integer currentRound;
private Integer maxRounds;
private String stepDetail;
```

### 2.2. Thao tác Lưu trữ Nguyên tử tại `KocCampaignStorage`
- **File:** `services/ai-agent-mcrs/src/main/java/com/lamld/aiAgent/modules/koccampaign/infrastructure/storage/KocCampaignStorage.java`
- Thêm phương thức cập nhật bước xử lý nhanh bằng `MongoTemplate.updateFirst` để tránh ghi đè toàn bộ entity và tránh xung đột phiên bản:
```java
public void updateWorkflowStep(
    String campaignId,
    String workflowStatus,
    String currentStep,
    String currentStepTitle,
    Integer currentRound,
    Integer maxRounds,
    String stepDetail
) {
  if (CommonUtil.isBlank(campaignId)) {
    return;
  }
  Query query = new Query(Criteria.where("_id").is(campaignId));
  Update update = new Update();
  if (!CommonUtil.isBlank(workflowStatus)) {
    update.set("workflow_status", workflowStatus);
  }
  if (!CommonUtil.isBlank(currentStep)) {
    update.set("current_step", currentStep);
  }
  if (!CommonUtil.isBlank(currentStepTitle)) {
    update.set("current_step_title", currentStepTitle);
  }
  if (currentRound != null) {
    update.set("current_round", currentRound);
  }
  if (maxRounds != null) {
    update.set("max_rounds", maxRounds);
  }
  if (!CommonUtil.isBlank(stepDetail)) {
    update.set("step_detail", stepDetail);
  }
  update.set("updated_at", Instant.now());
  mongoTemplate.updateFirst(query, update, KocCampaignEntity.class);
}
```

### 2.3. Tích hợp Cập nhật Bước vào các JavaDelegate trong BPMN

Danh sách các delegate cần gọi `campaignStorage.updateWorkflowStep(...)`:

| Delegate | Vị trí trong BPMN | Mã bước (`currentStep`) | Tiêu đề bước (`currentStepTitle`) | Chi tiết bước (`stepDetail`) |
| :--- | :--- | :--- | :--- | :--- |
| `InitializeDiscoveryStateDelegate` | `taskInitializeDiscoveryState` | `INITIALIZING` | `Khởi tạo tiến trình` | `Đang nạp cấu hình chiến dịch và chuẩn bị tài khoản Facebook` |
| `LoadAccountContextDelegate` | `taskLoadAccount` | `LOADING_ACCOUNT` | `Nạp tài khoản Facebook` | `Đang kiểm tra phiên đăng nhập và cookie Facebook` |
| `PrepareSearchContextDelegate` | `taskPrepareSearchContext` | `AI_SEARCH` | `Quét tìm KOC` | `Đang chạy AI agent quét bài viết và bài đăng Facebook` |
| `RecordSearchOutputDelegate` | `taskRecordSearchOutput` | `FILTERING` | `Lọc trùng ứng viên` | `Đã thu thập kết quả tìm kiếm thô, đang đối soát loại trừ ứng viên trùng` |
| `PrepareReviewContextDelegate` | `taskPrepareReviewContext` | `AI_REVIEW` | `Thẩm định KOC` | `Đang chạy AI agent chấm điểm tiêu chí và lọc profile KOC đạt chuẩn` |
| `AdvanceSearchRoundDelegate` | `taskAdvanceSearchRound` | `ADVANCING_ROUND` | `Chuyển vòng quét` | `Chưa đủ số lượng ứng viên mục tiêu, chuyển sang vòng quét kế tiếp` |
| `UpdateCampaignStatusDelegate` | `taskUpdateStatusUserDecision` | `WAITING_DECISION` | `Chờ quyết định tìm tiếp` | `Đã đạt giới hạn vòng quét tự động, chờ người dùng quyết định tìm thêm hay dừng` |
| `UpdateCampaignStatusDelegate` | `taskUpdateStatusUserTask` | `WAITING_APPROVAL` | `Chờ phê duyệt KOC` | `Đã thu thập danh sách KOC đạt chuẩn, chờ người quản trị phê duyệt` |
| `SaveKocCandidatesDelegate` | `taskSaveKocCandidates` | `SAVING_CANDIDATES` | `Lưu ứng viên vào DB` | `Đang lưu trữ danh sách ứng viên đạt chuẩn vào MongoDB` |
| `UpdateCampaignStatusDelegate` | `taskUpdateStatusCompleted` | `COMPLETED` | `Hoàn thành chiến dịch` | `Chiến dịch đã hoàn tất quy trình tìm kiếm và lưu trữ ứng viên` |
| `UpdateCampaignStatusDelegate` | `taskUpdateStatusRejected` | `TERMINATED` | `Đã dừng quy trình` | `Quy trình tìm kiếm KOC đã bị dừng hoặc từ chối` |

---

## 3. Thiết kế chi tiết Frontend (`web/dev-tool-web`)

### 3.1. Cập nhật Model & Config
- **File:** `web/dev-tool-web/src/app/features/koc-campaign/models/koc-campaign.model.ts`
  - Thêm vào interface `KocCampaignItem`:
    ```typescript
    currentStep?: string;
    currentStepTitle?: string;
    currentRound?: number;
    maxRounds?: number;
    stepDetail?: string;
    ```
- **File:** `web/dev-tool-web/src/app/features/koc-campaign/models/koc-campaign.config.ts`
  - Đổi cột `workflowStatus` sang `type: 'custom'`, độ rộng `14rem`:
    ```typescript
    {
      field: 'workflowStatus',
      header: 'kocCampaign.column.workflowStatus',
      type: 'custom',
      minWidth: '13rem',
    },
    ```

### 3.2. Cập nhật Template Hiển thị (`koc-campaign-list.component.html`)
- Đăng ký template `workflowStatus: workflowStatusCellTpl` trong `customTemplates` của `app-table`.
- Cấu trúc template `workflowStatusCellTpl`:
  - **Dòng 1:** `app-badge` hiển thị trạng thái chính:
    - `RUNNING`: info
    - `USER_TASK`: warning
    - `COMPLETED`: success
    - `FAILED`: danger
    - `TERMINATED`: muted
  - **Dòng 2:** Thông tin bước chi tiết:
    - Icon động: `pi pi-spin pi-spinner` nếu `RUNNING`, `pi pi-user-edit` nếu `USER_TASK`, `pi pi-check` nếu `COMPLETED`.
    - Text: `{{ row.currentStepTitle || 'Đang khởi tạo' }}`
    - Nếu có `currentRound`: hiển thị kèm `(Vòng {{ row.currentRound }}/{{ row.maxRounds || 3 }})`.
  - **Action Popover / Tooltip:**
    - Icon thông tin (`pi pi-info-circle`) mở Popover/Tooltip chi tiết với các trường:
      - **Bước hiện tại:** `currentStepTitle`
      - **Chi tiết tiến trình:** `stepDetail`
      - **Tiến độ vòng:** `Vòng X / Y`
      - **Số ứng viên đạt chuẩn:** `approvedKocCount / targetCount KOC`
      - **Mã tiến trình (Run ID):** `workflowRunId` kèm nút copy nhanh

### 3.3. Đa ngôn ngữ (i18n)
- **File:** `web/dev-tool-web/src/app/core/i18n/features/koc-campaign.i18n.json`
  - Bổ sung nhãn hiển thị:
    - `"kocCampaign.step.popoverTitle"`: "Chi tiết tiến trình AI"
    - `"kocCampaign.step.currentStep"`: "Bước hiện tại"
    - `"kocCampaign.step.progress"`: "Tiến độ vòng quét"
    - `"kocCampaign.step.detail"`: "Mô tả xử lý"
    - `"kocCampaign.step.candidates"`: "Ứng viên đạt chuẩn"
    - `"kocCampaign.step.runId"`: "Mã phiên chạy"

---

## 4. Kế hoạch Kiểm thử & Tiêu chuẩn Nghiệm thu

### 4.1. Unit Tests Backend
1. `KocCampaignStorageTest`: Kiểm tra `updateWorkflowStep` cập nhật đúng các trường `current_step`, `current_step_title`, `current_round`, `max_rounds`, `step_detail` vào MongoDB.
2. `InitializeDiscoveryStateDelegateTest`: Kiểm tra delegate khởi tạo trạng thái bước `INITIALIZING` với `currentRound = 1`.
3. `UpdateCampaignStatusDelegateTest`: Kiểm tra delegate cập nhật đúng trạng thái `USER_TASK` kèm bước `WAITING_APPROVAL` hoặc `WAITING_DECISION`.

### 4.2. Unit Tests Frontend
1. `koc-campaign-list.component.spec.ts`:
   - Kiểm tra render đúng cột `workflowStatus` với 2 dòng (Badge chính và dòng chi tiết bước).
   - Kiểm tra khi `currentStepTitle` có dữ liệu thì hiển thị đúng tiêu đề bước và số vòng quét.

### 4.3. Playwright E2E Verification
- Kiểm tra trực quan trên trang `/koc/campaigns`:
  - Dòng chiến dịch đang chạy hiển thị badge `RUNNING` màu xanh dương, kèm dòng phụ `Quét tìm KOC (Vòng 1/3)`.
  - Bấm nút Refresh trên bảng nạp lại dữ liệu thành công.
