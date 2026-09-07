# Roadmap: Codex SDK Chat History & Workbench

**Target:** `services/ai-agent-mcrs` (Java 21) & `web/dev-tool-web` (Angular 21)  
**Spec Reference:** [docs/designs/codex-sdk-chat-history-workbench.md](docs/designs/codex-sdk-chat-history-workbench.md)  
**Implementation Plan:** [docs/superpowers/plans/2026-09-05-codex-sdk-chat-history-workbench.md](docs/superpowers/plans/2026-09-05-codex-sdk-chat-history-workbench.md)  
**Status:** Hoàn tất (Completed)

---

## Phase Overview & Dependency Graph

```
Phase 01: Backend Verification (Wave 1)
   |
Phase 02: Frontend Core Data & Streaming (Wave 1)
   |
   +---------------------------------------+
   |                                       |
   v                                       v
Phase 03: Chat Drawer Workbench       Phase 04: Thread List Page
   | (Wave 2)                              | (Wave 2)
   +---------------------------------------+
   |
   v
Phase 05: Routing, Multi-language & E2E Validation (Wave 3)
```

---

## Phases Breakdown

### [Phase 01: Backend Verification & Contract Hardening](phases/01-backend-verification/01-CONTEXT.md)
- **Module:** `services/ai-agent-mcrs`
- **Goal:** Khóa contract API `/v1/codex-sdk/*`, bổ sung test suite `CodexSdkServiceTest.java` (Mockito + JUnit 5) đạt 100% pass theo chuẩn `docs/note/be-note.md`.
- **Plans:**
  - `01-01-PLAN.md`: Viết và chạy `CodexSdkServiceTest`.

### [Phase 02: Frontend Core Data & Native Streaming Engine](phases/02-frontend-core-data/02-CONTEXT.md)
- **Module:** `web/dev-tool-web`
- **Goal:** Tạo model kiểu dữ liệu (`codex-sdk.model.ts`) và service `CodexSdkService` tích hợp SSE streaming qua Native Web API `fetch()` + `ReadableStream` (`response.body.getReader()`), không dùng thư viện ngoài.
- **Plans:**
  - `02-01-PLAN.md`: Tạo models, viết `codex-sdk.service.spec.ts` và triển khai `CodexSdkService.ts`.

### [Phase 03: Conversation Timeline & Collapsible Inspector](phases/03-chat-drawer-workbench/03-CONTEXT.md)
- **Module:** `web/dev-tool-web`
- **Goal:** Xây dựng `CodexChatDrawerComponent` (.ts, .html, .scss, .spec.ts) với bong bóng chat, collapsible inspector cho tool calls bằng `app-json-viewer`, docked bottom bar (~110px) và cơ chế partial stream error recovery.
- **Plans:**
  - `03-01-PLAN.md`: Viết spec test và triển khai Drawer component.

### [Phase 04: Thread List & Cursor Navigation Workbench](phases/04-thread-list-page/04-CONTEXT.md)
- **Module:** `web/dev-tool-web`
- **Goal:** Xây dựng `CodexThreadListPageComponent` (.ts, .html, .scss, .spec.ts) với `app-page-shell`, `app-action-toolbar` chứa nút phân trang cursor, `app-filter-panel`, `app-table`.
- **Plans:**
  - `04-01-PLAN.md`: Viết spec test và triển khai List page component.

### [Phase 05: Routing, Multi-language & E2E Validation](phases/05-routing-i18n-e2e/05-CONTEXT.md)
- **Module:** `web/dev-tool-web`
- **Goal:** Đăng ký module, cấu hình route `/codex-sdk/threads`, thêm menu item sidebar, bổ sung i18n Vi/En và chạy kiểm thử tự động Playwright E2E.
- **Plans:**
  - `05-01-PLAN.md`: Module setup, route, menu, i18n và `e2e/codex-sdk-history.spec.ts`.
