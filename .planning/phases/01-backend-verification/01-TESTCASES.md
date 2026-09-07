# Test Cases - Phase 01: Backend Verification & Contract Hardening

**Phase:** 01-backend-verification  
**Module:** `services/ai-agent-mcrs` (Java 21 / Spring Boot 3.5)  
**Target:** `CodexSdkService.java`, `CodexSdkController.java`, `CodexSdkFeignClient.java`  
**Reference:** [docs/note/be-note.md](docs/note/be-note.md) §1, §2, §5, §7

---

## Danh sách Test Cases

### TC-BE-01: Kiểm tra lấy danh sách threads có phân trang cursor qua FeignClient
- **Mục đích:** Đảm bảo `CodexSdkService.listThreads` ủy thác chính xác sang `CodexSdkFeignClient` với các query params (limit, cursor, searchTerm, archived).
- **Phân loại:** Unit Test (Mockito)
- **Tiền điều kiện:** Khởi tạo `CodexSdkService` với mocked `CodexSdkFeignClient`.
- **Dữ liệu đầu vào:**
  - `limit`: 10
  - `cursor`: "cursor-abc"
  - `searchTerm`: "debug session"
  - `archived`: false
- **Các bước thực hiện:**
  1. Giả lập `feignClient.listThreads(10, "cursor-abc", "debug session", false)` trả về `Map.of("data", List.of(Map.of("id", "t-001")), "nextCursor", "cursor-xyz")`.
  2. Gọi phương thức `service.listThreads(10, "cursor-abc", "debug session", false)`.
  3. Đối soát kết quả trả về và verify số lần gọi feign client.
- **Kết quả kỳ vọng:**
  - Kết quả không rỗng (`assertNotNull`).
  - Danh sách chứa thread `t-001`, `nextCursor` bằng "cursor-xyz".
  - `verify(feignClient, times(1)).listThreads(...)` được kích hoạt đúng 1 lần với đúng tham số.

---

### TC-BE-02: Kiểm tra lấy chi tiết hội thoại của threadId
- **Mục đích:** Xác minh `getThreadHistory(threadId)` gọi đúng endpoint và trả về đầy đủ turns.
- **Phân loại:** Unit Test (Mockito)
- **Tiền điều kiện:** Mock `feignClient.getThread("t-001")`.
- **Dữ liệu đầu vào:** `threadId` = "t-001"
- **Các bước thực hiện:**
  1. Giả lập `feignClient.getThread("t-001")` trả về payload `Map.of("id", "t-001", "turns", List.of(Map.of("id", "turn-1", "role", "user", "content", "hi")))`.
  2. Gọi `service.getThreadHistory("t-001")`.
- **Kết quả kỳ vọng:**
  - Trả về đối tượng Map khớp với giả lập.
  - FeignClient nhận đúng `t-001`.

---

### TC-BE-03: Kiểm tra trích xuất threadId linh hoạt (Flat vs Nested)
- **Mục đích:** Xác minh phương thức tiện ích `extractThreadId` trích xuất chính xác ID dù payload phẳng (`threadId`) hay lồng trong `data.threadId`, xử lý an toàn khi payload rỗng hoặc null.
- **Phân loại:** Unit Test
- **Tiền điều kiện:** Khởi tạo `CodexSdkService`.
- **Các bước thực hiện:**
  1. Kiểm thử với Map phẳng: `Map.of("threadId", "id-direct")`.
  2. Kiểm thử với Map lồng: `Map.of("data", Map.of("threadId", "id-nested"))`.
  3. Kiểm thử với Map rỗng: `Map.of()`.
  4. Kiểm thử với `null`.
- **Kết quả kỳ vọng:**
  - Case 1: Trả về `"id-direct"`.
  - Case 2: Trả về `"id-nested"`.
  - Case 3 & 4: Trả về `null`, không ném `NullPointerException`.

---

### TC-BE-04: Kiểm tra ủy thác thực thi prompt đồng bộ (Execute API)
- **Mục đích:** Đảm bảo `service.execute(request)` chuyển tiếp đúng DTO `CodexSdkPromptRequest` sang FeignClient.
- **Phân loại:** Unit Test (Mockito)
- **Dữ liệu đầu vào:** `CodexSdkPromptRequest` có `prompt = "ping"`, `model = "claude-sonnet-5"`.
- **Các bước thực hiện:**
  1. Mock `feignClient.execute(request)` trả về `Map.of("outputText", "pong")`.
  2. Gọi `service.execute(request)`.
- **Kết quả kỳ vọng:**
  - Kết quả trả về `outputText = "pong"`.
  - FeignClient nhận đúng instance `request`.

---

### TC-BE-05: Kiểm tra cấu hình REST Endpoint và MediaType SSE trên Controller
- **Mục đích:** Xác minh hợp đồng kiến trúc (Contract Test) của `CodexSdkController` theo đúng chuẩn Spring MVC và Swagger annotations.
- **Phân loại:** Contract Test
- **Các bước thực hiện:**
  1. Đọc annotation `@RequestMapping` trên `CodexSdkController`.
  2. Đọc annotation trên method `stream()`.
- **Kết quả kỳ vọng:**
  - Class mapping là `v1/codex-sdk`.
  - Method `stream` có path `/stream`, method `POST`, `produces = MediaType.TEXT_EVENT_STREAM_VALUE`.
  - Trả về kiểu `SseEmitter`.

---

## Lệnh Thực Thi & Tiêu Chí Đạt

```powershell
mvn test -Dtest=CodexSdkServiceTest -f services/ai-agent-mcrs/pom.xml
```

**Tiêu chí nghiệm thu:**
- `BUILD SUCCESS`
- `Tests run: 4+, Failures: 0, Errors: 0, Skipped: 0`
- Thời gian chạy dưới 5 giây.
