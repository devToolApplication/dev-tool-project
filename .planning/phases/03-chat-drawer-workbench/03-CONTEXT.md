# Phase 03: Conversation Timeline & Collapsible Inspector - Context

**Gathered:** 2026-09-06
**Status:** Ready for execution
**Target Module:** `web/dev-tool-web` (Angular 21)

<domain>
## Phase Boundary

Xây dựng Drawer chi tiết đàm thoại bên phải (`CodexChatDrawerComponent`), hỗ trợ hiển thị lịch sử turns (User bên phải, Assistant bên trái), Collapsible Inspector cho Tool Calls bằng `app-json-viewer`, cơ chế scroll anchoring mượt mà, partial stream recovery và khung nhập test prompt tinh gọn (~110px) ở đáy.
</domain>

<decisions>
## Implementation Decisions

### UI/UX Rules & Taste Spec (/design-taste-frontend)
- **D-03.1:** 100% sử dụng Shared Components: `app-drawer`, `app-button`, `app-copyable-text`, `app-json-viewer`. Không dùng `primeng/*`, không dùng `::ng-deep`, không dùng em-dash.
- **D-03.2:** Dials: `VARIANCE: 4`, `MOTION_INTENSITY: 4`, `VISUAL_DENSITY: 8`. Bảng màu trung tính điềm tĩnh (Linear/Primer style).
- **D-03.3:** Responsive Drawer: Chiều rộng 650px trên Desktop (>= 768px), tự động mở rộng 100% full-width trên Mobile (< 768px).

### Collapsible Inspector & Chat Timeline
- **D-03.4:** Tool Calls hiển thị dạng accordion nằm gọn trong tin nhắn của Assistant. Mặc định đóng hiển thị tên tool, duration, status; nhấp mở hiển thị payload JSON bằng `app-json-viewer`.
- **D-03.5:** Phục hồi lỗi Partial Stream: Khi stream đứt gãy, giữ nguyên 100% lượng token đã sinh, hiển thị banner cảnh báo inline màu đỏ kèm nút "Thử lại" (Retry).
- **D-03.6:** Scroll Anchoring: Cờ `userScrolledUp` ngăn không tự động cuộn xuống đáy nếu người dùng đang đọc lại lịch sử phía trên.

### Docked Bottom Bar (~110px)
- **D-03.7:** Model selector (`claude-sonnet-5`, `claude-opus-5`, `gpt-5.2`), Reasoning effort selector (`low`, `medium`, `high`) ngay dòng đầu.
- **D-03.8:** Nút cấu hình nâng cao mở popover nhỏ điều chỉnh `instruction` và `sandboxMode`.
- **D-03.9:** Hỗ trợ phím tắt `Ctrl+Enter` gửi prompt. Nút "Dừng stream" màu đỏ xuất hiện khi `isStreaming = true`.
</decisions>

<canonical_refs>
## Canonical References
- `docs/designs/codex-sdk-chat-history-workbench.md` §2 & §3 — Visual spec và Interaction State Table cho Drawer.
- `docs/note/fe-note.md` §1, §5, §7 — Bắt buộc dùng Shared UI Components và Mobile-First.
</canonical_refs>

<code_context>
## Existing Code Insights
- Tích hợp với `CodexSdkService.streamPrompt` và tự động abort khi `ngOnDestroy` hoặc đóng Drawer.
</code_context>

<deferred>
## Deferred Ideas
- Xuất toàn bộ session ra file Markdown/JSON tải về máy.
</deferred>
