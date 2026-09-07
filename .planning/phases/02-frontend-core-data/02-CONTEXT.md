# Phase 02: Frontend Core Data & Native Streaming Engine - Context

**Gathered:** 2026-09-06
**Status:** Ready for execution
**Target Module:** `web/dev-tool-web` (Angular 21)

<domain>
## Phase Boundary

Xây dựng model định kiểu dữ liệu cho Codex SDK và triển khai service `CodexSdkService` tích hợp cơ chế SSE streaming sử dụng hoàn toàn Native Web API `fetch()` + `ReadableStream` (`response.body.getReader()`), không dùng thư viện ngoài (`@microsoft/fetch-event-source`).
</domain>

<decisions>
## Implementation Decisions

### Model Structure (`codex-sdk.model.ts`)
- **D-02.1:** `CodexThreadItem`: gồm `id`, `preview`, `createdAt`, `updatedAt`, `turnCount`, `archived`.
- **D-02.2:** `CodexTurn`: gồm `id`, `role` (`user` | `assistant` | `system`), `content`, `status` (`completed` | `failed` | `streaming`), `createdAt`, `toolCalls`, `metrics` (model, tokens, latency).
- **D-02.3:** `CodexToolCall`: gồm `name`, `input`, `output`, `durationMs`, `status`.
- **D-02.4:** `CodexPromptRequest`: gồm `prompt`, `threadId`, `model`, `reasoningEffort`, `instruction`, `sandboxMode`.

### Native Streaming Protocol
- **D-02.5:** Phương thức `streamPrompt(request, onToken, onError, onDone): AbortController`:
  - Khởi tạo `AbortController` và truyền `signal: controller.signal` vào `fetch()`.
  - Đọc luồng qua `response.body.getReader()`.
  - Sử dụng `TextDecoder('utf-8', { fatal: false })` giải mã nhị phân.
  - Tách buffer theo ký tự phân cách `\n\n` để xử lý các event SSE `message`, `error`, `done`.
  - Không ném lỗi nếu abort chủ động (`error.name === 'AbortError'`).

### Testing Criteria (`docs/note/fe-note.md`)
- **D-02.6:** Bắt buộc viết test suite `codex-sdk.service.spec.ts` kiểm thử đầy đủ `getThreads`, `getThreadHistory` và mock `fetch()` stream.
</decisions>

<canonical_refs>
## Canonical References
- `docs/designs/codex-sdk-chat-history-workbench.md` §2 & §4 — Kiến trúc và ràng buộc kỹ thuật SSE Native stream.
- `docs/note/fe-note.md` §6 — Quy định bắt buộc viết Unit Test cho Service.
</canonical_refs>

<code_context>
## Existing Code Insights
- Sử dụng `provideHttpClient()` và `provideHttpClientTesting()` cho Angular test.
</code_context>

<deferred>
## Deferred Ideas
- Local caching kết quả stream vào IndexedDB (giữ trong memory của Signal cho phiên hiện tại).
</deferred>
