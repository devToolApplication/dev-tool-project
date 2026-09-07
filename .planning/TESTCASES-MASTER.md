# Tổng Hợp Test Cases: Codex SDK Chat History & Workbench

Tài liệu quản lý ma trận kiểm thử cho tính năng **Codex SDK Chat History & Workbench** (`/codex-sdk/threads`). Tuân thủ quy định kiểm thử Playwright E2E thực tế trên trình duyệt cho mọi luồng giao diện người dùng.

---

## 1. Bản Đồ Kiểm Thử Theo Phase

| Phase | Mã Phase | File Đặc Tả Test Cases | Trọng Tâm Kiểm Thử | Công Cụ Kiểm Thử |
| :--- | :--- | :--- | :--- | :--- |
| **Phase 01** | `01-backend-verification` | [.planning/phases/01-backend-verification/01-TESTCASES.md](phases/01-backend-verification/01-TESTCASES.md) | Backend Gateway API, FeignClient delegation, bóc tách thread ID an toàn | JUnit 5, Mockito, Spring MVC Contract |
| **Phase 02** | `02-frontend-core-data` | [.planning/phases/02-frontend-core-data/02-TESTCASES.md](phases/02-frontend-core-data/02-TESTCASES.md) | Models, HTTP Service, Native `fetch()` ReadableStream, AbortController | Vitest, HttpTestingController, Fetch Mock |
| **Phase 03** | `03-chat-drawer-workbench` | [.planning/phases/03-chat-drawer-workbench/03-TESTCASES.md](phases/03-chat-drawer-workbench/03-TESTCASES.md) | E2E Chat Timeline, Tool Call Accordion, Streaming prompt, Abort & Retry | Playwright E2E (`codex-sdk-drawer.spec.ts`) |
| **Phase 04** | `04-thread-list-page` | [.planning/phases/04-thread-list-page/04-TESTCASES.md](phases/04-thread-list-page/04-TESTCASES.md) | E2E `app-table`, Phân trang Cursor Toolbar, Filter Panel search & reset | Playwright E2E (`codex-sdk-list.spec.ts`) |
| **Phase 05** | `05-routing-i18n-e2e` | [.planning/phases/05-routing-i18n-e2e/05-TESTCASES.md](phases/05-routing-i18n-e2e/05-TESTCASES.md) | Tích hợp Route, Sidebar Menu, Song ngữ i18n, Full E2E Flow, Mobile | Playwright E2E (`codex-sdk-integration.spec.ts`) |

---

## 2. Ma Trận Kịch Bản Kiểm Thử

### Phase 01: Backend Verification & Contract Hardening (`ai-agent-mcrs`)
- **TC-BE-01:** Lấy danh sách threads có phân trang cursor qua FeignClient (`listThreads`).
- **TC-BE-02:** Lấy chi tiết hội thoại của threadId qua FeignClient (`getThreadHistory`).
- **TC-BE-03:** Trích xuất threadId linh hoạt từ Flat hoặc Nested JSON payload (`extractThreadId`).
- **TC-BE-04:** Chuyển tiếp prompt đồng bộ qua FeignClient (`execute`).
- **TC-BE-05:** Contract Test cho REST endpoints và SSE `MediaType.TEXT_EVENT_STREAM_VALUE` trên Controller.

### Phase 02: Frontend Core Data & Native Streaming Engine (`dev-tool-web`)
- **TC-FE-CORE-01:** Gọi API `getThreads` với Query Parameters (limit, cursor, searchTerm, archived).
- **TC-FE-CORE-02:** Gọi API `getThreadHistory` theo ID với URL encode an toàn.
- **TC-FE-CORE-03:** Khởi tạo Native `fetch()` và `AbortController` trong `streamPrompt`.
- **TC-FE-CORE-04:** Phân tách chunk SSE theo buffer `\n\n` và kích hoạt callback `onToken`.
- **TC-FE-CORE-05:** Xử lý ngắt kết nối an toàn khi gọi `controller.abort()`.

### Phase 03: Conversation Timeline & Collapsible Inspector (Playwright E2E)
- **TC-FE-DRAWER-E2E-01:** Render lịch sử hội thoại và bong bóng chat User/Assistant trên trình duyệt thực.
- **TC-FE-DRAWER-E2E-02:** Đóng mở độc lập từng Tool Call Accordion hiển thị payload JSON qua `app-json-viewer`.
- **TC-FE-DRAWER-E2E-03:** Gửi prompt, thêm turn streaming và cộng dồn tokens theo thời gian thực.
- **TC-FE-DRAWER-E2E-04:** Nút "Dừng stream" xuất hiện khi streaming và hủy kết nối an toàn.
- **TC-FE-DRAWER-E2E-05:** Phục hồi lỗi Partial Stream: hiển thị banner cảnh báo và nút "Thử lại".
- **TC-FE-DRAWER-E2E-06:** Cơ chế Scroll Anchoring: người dùng cuộn lên đọc lịch sử thì không bị giật xuống đáy.

### Phase 04: Thread List & Cursor Navigation Workbench (Playwright E2E)
- **TC-FE-PAGE-E2E-01:** Render cấu trúc bảng `app-table` đầy đủ cột theo cấu hình `TableConfig`.
- **TC-FE-PAGE-E2E-02:** Phân trang con trỏ: click "Trang sau" nạp cursor mới, mở khóa nút "Trang trước", click "Trang trước" quay lại.
- **TC-FE-PAGE-E2E-03:** Thay đổi bộ lọc tìm kiếm trên `app-filter-panel` và reset toàn bộ lịch sử con trỏ.
- **TC-FE-PAGE-E2E-04:** Nhấp nút "Xem chi tiết" trên hàng để mở Drawer đàm thoại.
- **TC-FE-PAGE-E2E-05:** Nhấp nút "Mở Workbench test" trên toolbar mở Drawer ở chế độ tạo phiên mới.

### Phase 05: Routing, Multi-language & E2E Validation
- **TC-FE-E2E-01:** Playwright E2E: Render hoàn chỉnh cấu trúc trang (`app-page-shell`, `app-action-toolbar`, `app-table`).
- **TC-FE-E2E-02:** Playwright E2E: Tương tác nhấp mở/đóng Drawer trên trình duyệt.
- **TC-FE-E2E-03:** Playwright E2E: Kiểm tra co giãn responsive full-width của Drawer trên Mobile viewport (< 768px).
- **TC-FE-E2E-04:** Playwright E2E: Toàn bộ luồng nghiệp vụ từ bảng danh sách đến gửi prompt nhận stream.
- **TC-FE-INT-01:** Tích hợp mục "Codex SDK Chat" trong menu sidebar hệ thống (`menu.config.ts`).
- **TC-FE-INT-02:** Kiểm tra tính đối xứng 100% giữa 2 từ điển ngôn ngữ `vi` và `en` trong `codex-sdk.i18n.json`.
- **TC-FE-INT-03:** Build Production Angular CLI thành công với 0 lỗi compile và 0 warning.

---

## 3. Lệnh Chạy Toàn Bộ Test Suite

```powershell
# 1. Kiểm thử Backend (ai-agent-mcrs)
mvn test -Dtest=CodexSdkServiceTest -f services/ai-agent-mcrs/pom.xml

# 2. Kiểm thử Frontend Unit Tests Core Data (dev-tool-web)
npm test -- src/app/features/codex-sdk/services/codex-sdk.service.spec.ts --prefix web/dev-tool-web

# 3. Kiểm thử Frontend Playwright E2E Suites
npx playwright test e2e/codex-sdk-drawer.spec.ts
npx playwright test e2e/codex-sdk-list.spec.ts
npx playwright test e2e/codex-sdk-integration.spec.ts

# 4. Kiểm tra Build Production
npm run build --prefix web/dev-tool-web
```
