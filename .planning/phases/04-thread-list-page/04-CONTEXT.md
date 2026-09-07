# Phase 04: Thread List & Cursor Navigation Workbench - Context

**Gathered:** 2026-09-06
**Status:** Ready for execution
**Target Module:** `web/dev-tool-web` (Angular 21)

<domain>
## Phase Boundary

Xây dựng trang bảng danh sách phiên hội thoại (`CodexThreadListPageComponent`) theo chuẩn `app-page-shell`, `app-action-toolbar`, `app-filter-panel`, và `app-table`. Hỗ trợ phân trang cursor-based thông qua các nút điều hướng "Trang trước" / "Trang sau" trên toolbar mà không làm vỡ kiến trúc của `app-table`.
</domain>

<decisions>
## Implementation Decisions

### Page Layout & Action Toolbar
- **D-04.1:** Bọc toàn bộ trong `app-page-shell` với tiêu đề và phụ đề đa ngôn ngữ.
- **D-04.2:** `app-action-toolbar` chứa 4 hành động:
  - "Làm mới": Tải lại danh sách theo cursor hiện tại.
  - "Mở Workbench test": Mở Drawer trống để gửi turn đầu cho phiên mới.
  - "Trang trước": Disabled khi `cursorHistory.length === 0`.
  - "Trang sau": Disabled khi `nextCursor === null`.

### Filter & Table (`app-filter-panel`, `app-table`)
- **D-04.3:** Bộ lọc gồm `searchTerm` (input text tìm theo ID/preview) và `archived` (dropdown: Tất cả, Hoạt động, Đã lưu trữ). Khi thay đổi bộ lọc, reset lại `cursorHistory`.
- **D-04.4:** `TableConfig<CodexThreadItem>` định nghĩa 5 cột: `id`, `preview`, `turnCount`, `createdAt`, `actions`. Cột `actions` có nút "Xem chi tiết" mở Drawer tương ứng.
</decisions>

<canonical_refs>
## Canonical References
- `docs/designs/codex-sdk-chat-history-workbench.md` §2 — Kiến trúc Information Architecture.
- `docs/note/fe-note.md` §1 & §2 — Chuẩn cấu hình TableConfig và Shared Components.
</canonical_refs>

<code_context>
## Existing Code Insights
- Sử dụng Signal reactivity cho danh sách threads, loading và cursor history.
</code_context>

<deferred>
## Deferred Ideas
- Batch delete hoặc lưu trữ nhiều thread cùng lúc.
</deferred>
