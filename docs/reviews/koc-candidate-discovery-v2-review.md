# Code Review: KOC Candidate Discovery Loop v2 (BE & FE)

**Target Branch:** `design/koc-discovery-loop-v2`  
**Scope:** `services/ai-agent-mcrs` (Backend) & `web/dev-tool-web` (Frontend)  
**Status:** All Resolved (10/10)  
**Last Updated:** 2026-09-08  

---

## 1. Backend Findings (`services/ai-agent-mcrs`)

### [BE-01] [High - Security] Rò rỉ thông tin đăng nhập tài khoản vào Flowable Node Output và Run Detail
- **File & Line:** [LoadAccountContextDelegate.java:80-107](services/ai-agent-mcrs/src/main/java/com/lamld/aiAgent/modules/workflowprocess/infrastructure/flowable/delegate/LoadAccountContextDelegate.java#L80-L107)
- **Vấn đề:** Mật khẩu plaintext (`account.getPassword()`), mã 2FA secret (`twoFactorSecret`), và backup codes được ghi trực tiếp vào `accountData` rồi gán vào execution variable `node_${activityId}_output` và `accountContext`. Khi client truy vấn chi tiết workflow run qua REST API (`WorkflowRunService.getRunDetail`), toàn bộ thông tin nhạy cảm này bị trả về trong audit history.
- **Đã xử lý:** Loại bỏ `CTX_ACCOUNT_PASSWORD`, `twoFactorSecret`, `backupCodes` khỏi audit output map trước khi lưu vào execution variables.
- **Trạng thái:** RESOLVED

### [BE-02] [High - Concurrency] Race condition trên Singleton Delegates do thiếu `@Scope(ConfigurableBeanFactory.SCOPE_PROTOTYPE)`
- **File & Line:**
  - [InitializeDiscoveryStateDelegate.java:31](services/ai-agent-mcrs/src/main/java/com/lamld/aiAgent/modules/workflowprocess/infrastructure/flowable/delegate/InitializeDiscoveryStateDelegate.java#L31)
  - [ProcessReviewResultsDelegate.java:31](services/ai-agent-mcrs/src/main/java/com/lamld/aiAgent/modules/workflowprocess/infrastructure/flowable/delegate/ProcessReviewResultsDelegate.java#L31)
- **Vấn đề:** Hai delegate này khai báo `@Setter private Expression ...` nhưng không có `@Scope(ConfigurableBeanFactory.SCOPE_PROTOTYPE)`. Mặc định Spring quản lý bean dạng Singleton. Khi nhiều instance workflow chạy đồng thời trên Flowable JobExecutor threads, các field `Expression` bị đè chéo giữa các chiến dịch, gây sai lệch context thực thi.
- **Đã xử lý:** Bổ sung annotation `@Scope(ConfigurableBeanFactory.SCOPE_PROTOTYPE)` vào cả hai class delegate.
- **Trạng thái:** RESOLVED

### [BE-03] [High - Fixed] Điều kiện Exclusive Gateway không nhận biến khi Complete User Task
- **File & Line:** [koc_candidate_discovery_process.bpmn20.xml:171](services/ai-agent-mcrs/src/main/resources/processes/koc_candidate_discovery_process.bpmn20.xml#L171)
- **Vấn đề:** Gateway `gwCheckDiscoveryDecision` ban đầu chỉ kiểm tra `${flowData.variableData.discoveryDecision == 'FIND_MORE'}`.
- **Đã xử lý:** Đã đồng bộ biểu thức CDATA hỗ trợ cả biến root `discoveryDecision` lẫn `flowData.variableData`, đồng thời bổ sung `syncDiscoveryDecisionToFlowData` trong `WorkflowRunService`.
- **Trạng thái:** RESOLVED

### [BE-04] [Medium - Architecture] Vi phạm quy chuẩn 3 lớp và BaseService (`be-note.md`)
- **File & Line:**
  - [WorkflowAdminService.java:34-40](services/ai-agent-mcrs/src/main/java/com/lamld/aiAgent/modules/workflowprocess/application/admin/WorkflowAdminService.java#L34-L40)
  - [WorkflowRunService.java:60](services/ai-agent-mcrs/src/main/java/com/lamld/aiAgent/modules/workflowprocess/application/admin/WorkflowRunService.java#L60)
- **Vấn đề:**
  1. `WorkflowAdminService` không kế thừa `BaseService`, tự inject `MapperUtil` thủ công.
  2. Cả `WorkflowAdminService` và `WorkflowRunService` inject trực tiếp `WorkflowDefinitionRepository` và `WorkflowVersionRepository` thay vì đi qua tầng trung gian `Storage` theo quy chuẩn `docs/note/be-note.md` mục 1 & 2.
- **Đã xử lý:** Tạo `WorkflowStorage`, chuyển `WorkflowAdminService extends BaseService` và truy xuất qua `WorkflowStorage`.
- **Trạng thái:** RESOLVED

### [BE-05] [Medium - Reliability] Mất context và thiếu step update khi trigger workflow bất đồng bộ
- **File & Line:** [KocCampaignService.java:94-148](services/ai-agent-mcrs/src/main/java/com/lamld/aiAgent/modules/koccampaign/application/KocCampaignService.java#L94-L148)
- **Vấn đề:** Sử dụng `CompletableFuture.runAsync()` với ForkJoinPool ngầm định.
  1. Thất thoát RequestFilter / MDC logging context của request gốc.
  2. Khi `startWorkflow` ném Exception (catch block), chỉ cập nhật `workflowStatus = "FAILED"`, không cập nhật `KocCampaignStep.TERMINATED` và chi tiết lỗi qua `KocCampaignStorage.updateWorkflowStep()`, dẫn đến UI bảng chiến dịch vẫn hiển thị step cũ hoặc null.
- **Đã xử lý:** Thêm gọi `storage.updateWorkflowStep(campaignId, "FAILED", KocCampaignStep.TERMINATED, ...)` trong catch block của `runAsync`.
- **Trạng thái:** RESOLVED

### [BE-06] [Low - Security] Hardcoded default secret key & credentials trong source code
- **File & Line:**
  - [AiAgentSecretService.java:41, 50](services/ai-agent-mcrs/src/main/java/com/lamld/aiAgent/modules/secret/application/AiAgentSecretService.java#L41) (`"AntigravityKey12"`)
  - [CodexSdkService.java:32, 38](services/ai-agent-mcrs/src/main/java/com/lamld/aiAgent/modules/codexsdk/application/CodexSdkService.java#L32) (`"Zzxx25102001"`, `"ai_agent_service-secret"`)
- **Vấn đề:** Các chuỗi nhạy cảm mặc định được hardcode trực tiếp trong mã nguồn Java.
- **Đã xử lý:** Chuyển sang đọc hoàn toàn từ cấu hình `@Value("${...:}")`, loại bỏ mọi credential/secret mặc định.
- **Trạng thái:** RESOLVED

---

## 2. FE/BE Integration Findings

### [INT-01] [High - Functional] Không khớp tên biến Candidate được phê duyệt (`approvedCandidates` vs `selectedCandidates`)
- **File & Line:**
  - FE: [koc-campaign.service.ts:111-120](web/dev-tool-web/src/app/features/koc-campaign/services/koc-campaign.service.ts#L111-L120)
  - BE: [SaveKocCandidatesDelegate.java:160-176](services/ai-agent-mcrs/src/main/java/com/lamld/aiAgent/modules/workflowprocess/infrastructure/flowable/delegate/SaveKocCandidatesDelegate.java#L160-L176)
- **Vấn đề:** FE gửi payload user task hoàn thành với key `approvedCandidates`. Nhưng BE trong `resolveSelectedCandidatesMap()` chỉ kiểm tra `VAR_SELECTED_CANDIDATES` ("selectedCandidates"), sau đó fallback tự động lưu toàn bộ `qualifiedCandidates`. Kết quả: Sự lựa chọn lọc bỏ ứng viên thủ công của user trên FE bị bỏ qua hoàn toàn.
- **Đã xử lý:** Trong `SaveKocCandidatesDelegate.resolveSelectedCandidatesMap()`, bổ sung kiểm tra fallback: `execution.getVariable("approvedCandidates")` đồng thời FE cũng gửi song song cả `approvedCandidates` và `selectedCandidates`.
- **Trạng thái:** RESOLVED

### [INT-02] [Medium - Functional] Mất dữ liệu KOC của các vòng tìm kiếm trước trên giao diện phê duyệt
- **File & Line:** [koc-candidate-approval.component.ts:92](web/dev-tool-web/src/app/features/koc-campaign/pages/koc-candidate-approval/koc-candidate-approval.component.ts#L92)
- **Vấn đề:** FE lấy danh sách ứng viên từ `vars['reviewedCandidates']`. Biến này chỉ lưu ứng viên của vòng tìm kiếm hiện tại. Khi workflow lặp qua nhiều vòng, các ứng viên đạt chuẩn từ vòng trước bị biến mất khỏi bảng phê duyệt.
- **Đã xử lý:** Ưu tiên đọc từ `vars['qualifiedCandidates']` (danh sách tích lũy tất cả ứng viên đạt chuẩn qua các vòng).
- **Trạng thái:** RESOLVED

---

## 3. Frontend Standards & UX Findings (`web/dev-tool-web`)

### [FE-01] [Medium - Standards] Sử dụng `window.confirm()` thô vi phạm chuẩn Shared UI Component
- **File & Line:**
  - [koc-candidate-approval.component.ts:172, 196](web/dev-tool-web/src/app/features/koc-campaign/pages/koc-candidate-approval/koc-candidate-approval.component.ts#L172)
  - [koc-campaign-list.component.ts:274](web/dev-tool-web/src/app/features/koc-campaign/pages/koc-campaign-list/koc-campaign-list.component.ts#L274)
- **Vấn đề:** Dùng popup trình duyệt gốc (`window.confirm()`) thay vì `app-dialog` hoặc `ConfirmationService` theo quy chuẩn `docs/note/fe-note.md` mục 1.
- **Đã xử lý:** Thay thế 100% các lệnh `window.confirm()` bằng `<app-dialog>` modal và `<app-button>` actions.
- **Trạng thái:** RESOLVED

### [FE-02] [Medium - Standards] Hardcode chuỗi tiếng Việt vi phạm chuẩn i18n
- **File & Line:**
  - [koc-campaign-list.component.ts:70-78](web/dev-tool-web/src/app/features/koc-campaign/pages/koc-campaign-list/koc-campaign-list.component.ts#L70-L78) (`nicheOptions` label)
  - [koc-campaign-list.component.ts:228](web/dev-tool-web/src/app/features/koc-campaign/pages/koc-campaign-list/koc-campaign-list.component.ts#L228) (`'(Bản sao)'`)
  - [koc-candidate-approval.component.ts:172, 196](web/dev-tool-web/src/app/features/koc-campaign/pages/koc-campaign-list/koc-campaign-list.component.ts#L172)
- **Vấn đề:** Không đưa chuỗi văn bản vào file dịch `src/app/core/i18n/features/kocCampaign.i18n.json` vi phạm quy chuẩn `docs/note/fe-note.md` mục 4.
- **Đã xử lý:** Khai báo đầy đủ translation keys song ngữ (`vi`, `en`) trong `koc-campaign.i18n.json` và gọi qua `I18nService` / `translateContent` pipe.
- **Trạng thái:** RESOLVED
