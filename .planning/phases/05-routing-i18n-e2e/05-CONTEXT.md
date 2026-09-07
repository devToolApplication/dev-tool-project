# Phase 05: Routing, Multi-language & E2E Validation - Context

**Gathered:** 2026-09-06
**Status:** Ready for execution
**Target Module:** `web/dev-tool-web` (Angular 21)

<domain>
## Phase Boundary

Đăng ký `CodexSdkModule`, cấu hình route `/codex-sdk/threads` trong `app-feature.module.ts`, bổ sung menu navigation item trên sidebar (`menu.config.ts`), khai báo song ngữ i18n Transloco (`codex-sdk.i18n.json`) và viết kịch bản kiểm thử Playwright E2E (`e2e/codex-sdk-history.spec.ts`).
</domain>

<decisions>
## Implementation Decisions

### Routing & Menu Integration
- **D-05.1:** Route `/codex-sdk/threads` trỏ đến `CodexThreadListPageComponent`.
- **D-05.2:** Thêm menu item vào nhóm `layout.menu.aiAgentMcrs` với label `layout.menu.codexSdkChat`, icon `pi pi-comments`, routerLink `/codex-sdk/threads`.

### Multi-language i18n (`docs/note/fe-note.md` §4)
- **D-05.3:** Tạo file `codex-sdk.i18n.json` với cả 2 ngôn ngữ `vi` và `en`.
- **D-05.4:** Import và mở rộng vào object `TRANSLATIONS` trong `i18n.service.ts`.

### Testing Verification (E2E & Build)
- **D-05.5:** Tạo kịch bản Playwright `e2e/codex-sdk-history.spec.ts` kiểm thử:
  - Render page shell, action toolbar và table.
  - Nhấp mở Drawer khi click nút "Mở Workbench test".
  - Co giãn responsive full-width của Drawer trên mobile viewport (375x667).
- **D-05.6:** Chạy `npm run build` xác nhận zero build error.
</decisions>

<canonical_refs>
## Canonical References
- `docs/note/fe-note.md` §4 & §6 — Bắt buộc i18n và Playwright E2E.
- `web/dev-tool-web/src/app/app-shell/navigation/config/menu.config.ts` — Cấu hình menu hệ thống.
</canonical_refs>

<code_context>
## Existing Code Insights
- `AppFeatureModule` nạp các feature modules và lazy routes.
</code_context>

<deferred>
## Deferred Ideas
- Thêm widget thống kê token usage vào Dashboard tổng quan.
</deferred>
