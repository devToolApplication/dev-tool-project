# Design: Quản lý Chiến dịch & Danh sách KOC Phê duyệt (KOC Campaign Management & Candidate Approval)

- **Date:** 2026-09-07
- **Branch:** main
- **Repo:** devToolApplication/dev-tool-project
- **Status:** APPROVED
- **Mode:** Startup / Enterprise Product
- **Supersedes:** Hello-main-design-20260906-230858.md

---

## 1. Problem Statement & Mục tiêu

Hệ thống đã có quy trình BPMN tự động hoá tìm kiếm, thẩm định và phê duyệt ứng viên KOC (`kocCandidateDiscoveryProcess`). Tuy nhiên, người dùng hiện tại chưa có giao diện trực quan để thao tác. Hệ thống cần xây dựng:
1. **Màn hình Khởi tạo Chiến dịch (Create Campaign):** Cho phép nhập thông tin chiến dịch, tiêu chí tìm kiếm KOC. Khi người dùng ấn hoàn thành sẽ lưu chiến dịch và tự động kích hoạt quy trình Flowable BPMN.
2. **Màn hình Danh sách Chiến dịch (Campaign List & Detail View):** Xem danh sách các chiến dịch (Đang chạy, Chờ duyệt, Hoàn thành, Thất bại...). Khi bấm vào một chiến dịch sẽ xem được chi tiết và **danh sách các KOC đã được phê duyệt** của chiến dịch đó.
3. **Phân tách rạch ròi 2 màn hình KOC:**
   - **Màn hình Phê duyệt UserTask:** Dành riêng cho việc xem các ứng viên AI vừa tìm kiếm và chấm điểm xong (lấy từ biến runtime của process instance), cung cấp checkbox để người duyệt lựa chọn và ấn Duyệt.
   - **Màn hình View ở Menu Chiến dịch:** Chỉ hiển thị danh sách các KOC **đã được phê duyệt chính thức** và lưu trữ thành công trong database (`koc_candidates`).
4. **Ràng buộc toàn vẹn dữ liệu cốt lõi:** **KOC profile là UNIQUE trên toàn bảng** `koc_candidates`. Một profile KOC (theo `externalProfileId` hoặc `profileUrl`) chỉ tồn tại duy nhất 1 lần trên toàn hệ thống, không bị trùng lặp giữa các chiến dịch.

---

## 2. Demand Evidence & Giá trị Nghiệp vụ

- Chuyên viên Marketing / Campaign Manager không thể thao tác qua cURL/Postman mà cần giao diện đồ thị hóa trực quan để khởi chạy và kiểm soát ngân sách, tiến độ tuyển KOC.
- Việc trùng lặp KOC giữa các chiến dịch gây lãng phí chi phí liên hệ, làm phiền đối tác sáng tạo nội dung và giảm uy tín của thương hiệu. Ràng buộc unique toàn bảng đảm bảo mỗi KOC là một thực thể độc nhất trong hệ thống.
- Phân định rõ ràng giữa "ứng viên đang được AI đề xuất" (chưa cam kết lưu trữ lâu dài) và "ứng viên chính thức đã duyệt" (tài sản dữ liệu đã xác thực) giúp tối ưu hóa hiệu năng lưu trữ và tính minh bạch.

---

## 3. Status Quo (Hiện trạng Hệ thống)

- Quy trình BPMN `kocCandidateDiscoveryProcess` (Workflow ID: `6a9e31053b91b87f7eaadd02`) đã hoàn thiện và chạy live thành công trên Flowable Engine.
- Tác vụ tìm kiếm (`callAiSearchKoc`), khử trùng lặp (`taskDeduplicateCandidates`), đánh giá AI (`callAiReviewKoc`), và lưu DB (`taskSaveKocCandidates`) đã vận hành chuẩn xác.
- Khởi chạy workflow và phê duyệt UserTask (`userTaskApproveCandidates`) hiện tại đang phải gọi API backend thủ công.
- Chưa có bảng thực thể `koc_campaigns` quản lý metadata chiến dịch ở tầng Backend.

---

## 4. Target User & Narrowest Wedge

- **Target User:** Campaign Manager, Marketing Lead, Chuyên viên quản lý Influencer/KOC.
- **Narrowest Wedge:**
  - **Màn 1: Dialog / Form Khởi tạo Chiến dịch:** Thu thập Tên chiến dịch, Lĩnh vực (Niche), Số lượng cần tìm (`targetCount`), Điểm sàn (`minScore`), Tiêu chí tìm kiếm (`searchPrompt`), và Yêu cầu đánh giá (`reviewPrompt`).
  - **Màn 2: Danh sách Chiến dịch & Chi tiết KOC:** Bảng quản lý chiến dịch với trạng thái trực quan + Drawer/Trang chi tiết hiển thị danh sách KOC đã duyệt từ collection `koc_candidates`.
  - **Màn Phê duyệt: UserTask Approval View:** Nằm trong khu vực Workflow Tasks hiện tại (`/ai-agent-mcrs/workflows/tasks`), hỗ trợ xem danh sách KOC ứng viên kèm điểm số/phân tích AI, tích chọn các KOC đạt chuẩn và hoàn thành UserTask.

---

## 5. Constraints & Quy chuẩn Tuân thủ

1. **Frontend (tuân thủ `docs/note/fe-note.md`):**
   - 100% sử dụng Shared UI Components (`app-page-shell`, `app-action-toolbar`, `app-filter-panel`, `app-table`, `app-drawer`, `app-dialog`, `app-button`, `app-copyable-text`, `app-status-badge`).
   - Tuyệt đối không import `primeng/*` trực tiếp ra ngoài template feature.
   - Không sử dụng `::ng-deep` hay `:host-context`.
   - Chuẩn State Management: Angular Signals (`signal`, `computed`, `effect`).
   - Đa ngôn ngữ qua i18n (`vi`, `en`).
   - Responsive & Mobile-First.
2. **Backend (tuân thủ `docs/note/be-note.md`):**
   - Kiến trúc 3 lớp: Service gọi qua Storage (`infrastructure/storage`), không inject trực tiếp Repository vào Service.
   - Mọi Service kế thừa `BaseService`, sử dụng `mapperUtil` (`map`, `mapTo`, `mapList`, `mapPage`).
   - Xử lý lỗi bằng `BusinessException` và `BusinessErrorCode`.
3. **Database Constraints:**
   - MongoDB collection `koc_candidates`: Bắt buộc tạo **Unique Compound / Single Index** trên `external_profile_id` (và `platform`).
   - `FilterDuplicateCandidatesDelegate`: Truy vấn đối soát trùng lặp trên toàn bộ collection `koc_candidates` (không giới hạn trong `campaignId`).

---

## 6. Premises (Tiền đề Thiết kế)

1. **Chiến dịch là thực thể chủ quản:** Mỗi chiến dịch lưu trữ thông tin nghiệp vụ độc lập trong collection `koc_campaigns`, liên kết 1-1 với Flowable Process Instance qua `workflowRunId`.
2. **Tách biệt 2 trạng thái dữ liệu KOC:**
   - *Ứng viên đề xuất (Candidates in-review):* Tồn tại dưới dạng biến tạm thời trong Flowable runtime variables (`reviewedCandidates`).
   - *KOC chính thức (Approved KOCs):* Tồn tại cố định trong collection `koc_candidates` sau khi UserTask được Approve.
3. **Tính Unique toàn bảng:** Một khi KOC đã được phê duyệt và lưu vào DB, các chiến dịch chạy sau nếu AI có quét trúng KOC này thì bước `taskDeduplicateCandidates` sẽ tự động lọc bỏ ra khỏi danh sách review của chiến dịch mới.

---

## 7. Approaches Considered

### Phương án A: Domain Campaign riêng + KOC Unique Index toàn bảng (ĐÃ CHỌN)
- **Tóm tắt:** Tạo thực thể `KocCampaignEntity` (`koc_campaigns`); tạo Unique Index trên `external_profile_id` trong `koc_candidates`; xây dựng màn hình Danh sách Chiến dịch (kèm xem KOC đã duyệt); màn hình phê duyệt UserTask tích hợp trong Workflow Tasks.
- **Ưu điểm:**
  - KOC profile là duy nhất tuyệt đối trên toàn bộ hệ thống.
  - Phân tách rõ ràng giữa runtime task và persistent database.
  - Dễ triển khai, tuân thủ 100% chuẩn kiến trúc hiện có.
- **Nhược điểm:** 1 KOC đã được duyệt vào 1 chiến dịch thì không thể gắn vào chiến dịch khác (đáp ứng đúng yêu cầu của người dùng).

### Phương án B: Tách biệt Master KOC Directory & Campaign Mapping (N-N)
- **Tóm tắt:** Tách thành bảng `koc_profiles` (Master Directory) và `koc_campaign_candidates` (bảng liên kết chiến dịch).
- **Lý do loại bỏ:** Người dùng yêu cầu KOC là duy nhất trên cả bảng `koc_candidates`; việc tách 2 bảng làm phức tạp hóa mô hình dữ liệu và đòi hỏi sửa đổi nhiều delegate trong BPMN đang chạy ổn định.

### Phương án C: Tinh gọn (Lean Run-Centric) dựa trên Workflow Run sẵn có
- **Tóm tắt:** Không tạo bảng Campaign mới, coi mỗi Workflow Run là 1 chiến dịch.
- **Lý do loại bỏ:** Làm phụ thuộc dữ liệu nghiệp vụ vào vòng đời engine Flowable, không quản lý được các thuộc tính nghiệp vụ riêng của Campaign (ngân sách, mô tả, ngày kết thúc).

---

## 8. Recommended Architecture & Implementation Plan

### 8.1. Backend Architecture (`services/ai-agent-mcrs`)

#### A. Data Models:
1. **`KocCampaignEntity`** (Collection: `koc_campaigns`):
   ```java
   @Document("koc_campaigns")
   public class KocCampaignEntity extends BaseEntity {
       @Id
       private String id;
       private String name;
       private String description;
       private String niche;
       private Integer targetCount;
       private Double minScore;
       private String searchPrompt;
       private String reviewPrompt;
       private String workflowRunId;      // Flowable ProcessInstanceId
       private String workflowStatus;     // RUNNING, WAITING_APPROVAL, COMPLETED, FAILED
       private Integer approvedKocCount;   // Số lượng KOC đã duyệt thành công
       private CampaignStatus status;     // DRAFT, ACTIVE, COMPLETED, CANCELLED
   }
   ```

2. **Index trên `KocCandidateEntity`** (`koc_candidates`):
   - Tạo Unique Index: `external_profile_id` (Unique: true, Sparse: true).

#### B. API Contracts:
- `POST /v1/admin/koc-campaigns`: Tạo chiến dịch mới và kích hoạt Flowable Process.
  - Payload: `{ name, niche, targetCount, minScore, searchPrompt, reviewPrompt, approverAssignee }`
  - Output: `KocCampaignResponse` (bao gồm `id`, `workflowRunId`, `status: RUNNING`).
- `GET /v1/admin/koc-campaigns/page`: Danh sách phân trang chiến dịch (tìm kiếm theo tên, niche, status).
- `GET /v1/admin/koc-campaigns/{id}`: Chi tiết chiến dịch.
- `GET /v1/admin/koc-campaigns/{id}/candidates`: Danh sách các KOC đã được phê duyệt và lưu trong DB cho chiến dịch này (query từ `koc_candidates` theo `campaignId`).
- `GET /v1/admin/workflows/tasks/{taskId}/koc-review`: API chuyên dụng trả về danh sách ứng viên AI đang chờ duyệt kèm điểm số và review note của task đó.

#### C. Delegate Update:
- Trong `FilterDuplicateCandidatesDelegate`: Cập nhật logic tìm kiếm profile đã tồn tại không chỉ trong campaign hiện tại mà trên toàn bộ collection `koc_candidates`:
  ```java
  dbExistingIds = candidateService.findAllExistingProfileIds(extractedProfileIds);
  dbExistingUrls = candidateService.findAllExistingProfileUrls(extractedProfileUrls);
  ```

---

### 8.2. Frontend Architecture (`web/dev-tool-web`)

#### A. Menu & Navigation (`APP_LAYOUT_MENU`):
Thêm cụm Menu **"Quản lý Chiến dịch KOC"** (Icon: `pi pi-megaphone`):
1. **"Danh sách Chiến dịch"** (`/koc-campaigns`): Xem danh sách chiến dịch và danh sách KOC đã duyệt.
2. **"Phê duyệt Ứng viên"** (`/koc-campaigns/approval` hoặc liên kết trực tiếp tới `/ai-agent-mcrs/workflows/tasks` với filter task KOC).

#### B. Màn hình 1: Khởi tạo Chiến dịch (`KocCampaignCreateDialogComponent`):
- Mở dạng Popup Modal (`app-dialog`) từ nút "Tạo Chiến dịch" trên Toolbar.
- Các trường nhập liệu:
  - Tên chiến dịch (Bắt buộc).
  - Ngành hàng / Lĩnh vực (Công nghệ, Đời sống, Làm đẹp, Thời trang...).
  - Số lượng KOC mục tiêu (Mặc định: 5).
  - Điểm phù hợp tối thiểu (Mặc định: 70).
  - Prompt tìm kiếm AI (Có template gợi ý sẵn).
  - Prompt đánh giá & chấm điểm AI.
- Nút bấm: "Hủy" và "Khởi chạy Chiến dịch" (Primary Action Button). Khi submit -> Gọi API tạo và kích hoạt workflow -> Toast thông báo -> Reload bảng chiến dịch.

#### C. Màn hình 2: Danh sách Chiến dịch & Chi tiết KOC (`KocCampaignListPageComponent`):
- Sử dụng `app-page-shell` với tiêu đề "Quản lý Chiến dịch KOC".
- `app-action-toolbar`: Nút "Tạo Chiến dịch" (Primary) + Nút "Tải lại".
- `app-filter-panel`: Lọc theo từ khóa, ngành hàng, trạng thái (Đang chạy, Chờ duyệt, Hoàn thành).
- `app-table`:
  - Cột: Tên chiến dịch, Ngành hàng, Mục tiêu KOC, Đã duyệt (Badge số lượng), Trạng thái Workflow (Badge màu), Thời gian tạo, Hành động (Xem chi tiết, Xem Workflow Run).
- **Drawer Chi tiết Chiến dịch (`app-drawer`):**
  - Mở ra khi click vào một hàng chiến dịch.
  - Header: Tên chiến dịch + Badge trạng thái.
  - Tab 1: **"Danh sách KOC Đã Phê duyệt"**:
    - Sử dụng `app-table` hiển thị các KOC chính thức trong DB:
      - Avatar + Họ tên (Kèm link mở Facebook profile).
      - Follower, Engagement Rate.
      - Điểm AI đánh giá (Tag điểm kèm màu: >=85 Xanh lá, >=70 Xanh dương).
      - Nhận xét (Review note).
      - Điểm mạnh & Rủi ro.
      - Ngày duyệt.
  - Tab 2: **"Thông tin & Tiêu chí"**: Hiển thị các tiêu chí tìm kiếm, prompt và workflow ID.

#### D. Màn hình Phê duyệt UserTask (`KocCandidateApprovalDrawerComponent`):
- Hiển thị khi người dùng mở tác vụ duyệt `userTaskApproveCandidates` từ Task Center (`/ai-agent-mcrs/workflows/tasks`).
- Hiển thị danh sách các KOC ứng viên được AI đề xuất:
  - Checkbox chọn từng ứng viên hoặc chọn tất cả.
  - Thông tin chi tiết KOC: Profile, Followers, Tương tác, Điểm AI đánh giá, Điểm mạnh, Điểm yếu.
- Nút hành động:
  - "Phê duyệt các ứng viên đã chọn" (Gửi biến `approved: true`, `selectedCandidates: [...]`).
  - "Từ chối toàn bộ" (Gửi biến `approved: false`).

---

## 9. Success Criteria

1. **Khởi tạo Chiến dịch:** Người dùng điền form và ấn Khởi chạy -> Campaign được lưu vào DB và Workflow Flowable tự động kích hoạt thành công.
2. **Theo dõi Trạng thái:** Trạng thái của Campaign trên bảng chuyển động tương ứng với Workflow (`RUNNING` -> `WAITING_APPROVAL` -> `COMPLETED`).
3. **Phê duyệt Phân tách:** Màn hình duyệt chỉ hiển thị các ứng viên của task đang chạy. Sau khi duyệt xong, task biến mất khỏi danh sách chờ duyệt.
4. **Hiển thị KOC đã duyệt:** Mở chi tiết Campaign hiển thị đúng và đủ danh sách các KOC vừa được duyệt từ MongoDB `koc_candidates`.
5. **Đảm bảo Unique toàn bảng:** Nếu chạy chiến dịch mới với cùng từ khóa, các KOC đã từng được duyệt ở chiến dịch trước sẽ tự động bị loại bỏ, không bị thêm trùng vào DB.

---

## 10. The Assignment

- **Hành động tiếp theo:** Triển khai các endpoint Backend cho `KocCampaign` trong `services/ai-agent-mcrs`, sau đó xây dựng 2 màn hình UI trên `web/dev-tool-web` theo đúng quy chuẩn `docs/note/be-note.md` và `docs/note/fe-note.md`.
