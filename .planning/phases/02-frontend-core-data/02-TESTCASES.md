# Test Cases - Phase 02: Frontend Core Data & Native Streaming Engine

**Phase:** 02-frontend-core-data  
**Module:** `web/dev-tool-web` (Angular 21)  
**Target:** `CodexSdkService`, `codex-sdk.model.ts`  
**Reference:** [docs/note/fe-note.md](docs/note/fe-note.md) §6, [docs/designs/codex-sdk-chat-history-workbench.md](docs/designs/codex-sdk-chat-history-workbench.md) §2 & §4

---

## Danh sách Test Cases

### TC-FE-CORE-01: Kiểm tra gọi API `getThreads` với Query Parameters
- **Mục đích:** Xác minh `CodexSdkService.getThreads()` tạo đúng HTTP request kèm query params (limit, cursor, searchTerm, archived).
- **Phân loại:** Unit Test (`provideHttpClientTesting`)
- **Tiền điều kiện:** Khởi tạo `TestBed` với `CodexSdkService` và `HttpTestingController`.
- **Dữ liệu đầu vào:** `{ limit: 15, cursor: 'cur-123', searchTerm: 'refactor', archived: true }`
- **Các bước thực hiện:**
  1. Gọi `service.getThreads(...)`.
  2. Dùng `httpMock.expectOne(...)` để bắt request.
  3. Kiểm tra URL và các query parameters.
  4. Flush mock response `{ data: { data: [{ id: 't-1' }], nextCursor: 'cur-456' } }`.
- **Kết quả kỳ vọng:**
  - URL gọi là `/v1/codex-sdk/threads`.
  - Params: `limit=15`, `cursor=cur-123`, `searchTerm=refactor`, `archived=true`.
  - Method là `GET`.
  - Observable emit mảng 1 phần tử với `id = 't-1'`.

---

### TC-FE-CORE-02: Kiểm tra gọi API `getThreadHistory` theo ID
- **Mục đích:** Xác minh `getThreadHistory(threadId)` mã hóa URL an toàn và trả về đầy đủ turns.
- **Phân loại:** Unit Test
- **Dữ liệu đầu vào:** `threadId = 'thread#special/123'`
- **Các bước thực hiện:**
  1. Gọi `service.getThreadHistory('thread#special/123')`.
  2. Bắt request bằng `httpMock.expectOne`.
  3. Flush dữ liệu turns mock.
- **Kết quả kỳ vọng:**
  - URL gọi chính xác là `/v1/codex-sdk/threads/thread%23special%2F123`.
  - Method là `GET`.
  - Dữ liệu trả về khớp với mock response.

---

### TC-FE-CORE-03: Kiểm tra khởi tạo Native `fetch()` và `AbortController` trong `streamPrompt`
- **Mục đích:** Xác minh `streamPrompt` không dùng thư viện ngoài, trả về đối tượng `AbortController` và truyền đúng `signal` cùng header vào `window.fetch`.
- **Phân loại:** Unit Test (Spy window.fetch)
- **Tiền điều kiện:** Spy `window.fetch` trả về mock `ReadableStream`.
- **Dữ liệu đầu vào:** `{ prompt: 'Hello agent', model: 'claude-sonnet-5' }`
- **Các bước thực hiện:**
  1. Gọi `controller = service.streamPrompt(request, onToken, onError, onDone)`.
  2. Kiểm tra `controller` có phải `instanceof AbortController`.
  3. Kiểm tra tham số gọi của `window.fetch`.
- **Kết quả kỳ vọng:**
  - `fetch` được gọi với URL `/v1/codex-sdk/stream`, method `POST`, header `Content-Type: application/json`.
  - `signal` trong fetch options chính là `controller.signal`.

---

### TC-FE-CORE-04: Kiểm tra phân tách chunk SSE và gọi callback `onToken`
- **Mục đích:** Xác minh thuật toán buffer parsing theo `\n\n` tách đúng các event `message` và chuyển token về callback `onToken`.
- **Phân loại:** Unit Test
- **Các bước thực hiện:**
  1. Giả lập stream chunk 1: `event: message\ndata: Xin\n\n`.
  2. Giả lập stream chunk 2: `event: message\ndata: chào!\n\n`.
  3. Giả lập chunk kết thúc: `event: done\ndata: Stream finished.\n\n`.
- **Kết quả kỳ vọng:**
  - `onToken` được gọi lần 1 với `"Xin"`.
  - `onToken` được gọi lần 2 với `"chào!"`.
  - `onDone` được kích hoạt khi nhận event `done`.

---

### TC-FE-CORE-05: Kiểm tra xử lý ngắt kết nối an toàn (`AbortController.abort()`)
- **Mục đích:** Đảm bảo khi hủy stream chủ động, `streamPrompt` không coi đó là lỗi runtime và không gọi callback `onError`.
- **Phân loại:** Unit Test
- **Các bước thực hiện:**
  1. Gọi `controller = service.streamPrompt(...)`.
  2. Ngay lập tức gọi `controller.abort()`.
  3. Giả lập fetch ném lỗi `DOMException: AbortError`.
- **Kết quả kỳ vọng:**
  - `onError` không bị gọi.
  - Ứng dụng không bị crash hoặc văng unhandled rejection.

---

## Lệnh Thực Thi & Tiêu Chí Đạt

```powershell
npm test -- src/app/features/codex-sdk/services/codex-sdk.service.spec.ts
```

**Tiêu chí nghiệm thu:**
- `3/3 passed` trong Vitest runner.
- Zero type errors từ `tsc --noEmit`.
