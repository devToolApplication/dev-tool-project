# Phase 01: Backend Verification & Contract Hardening - Context

**Gathered:** 2026-09-06
**Status:** Ready for execution
**Target Module:** `services/ai-agent-mcrs` (Spring Boot 3.5, Java 21)

<domain>
## Phase Boundary

Khóa toàn bộ API contracts giữa Frontend và Backend Orchestrator `ai-agent-mcrs`. Đảm bảo backend gateway bảo vệ an toàn cho execute-service, chuẩn hóa định dạng SSE streaming event và đạt 100% độ phủ Unit Test cho tầng Service trước khi triển khai giao diện.
</domain>

<decisions>
## Implementation Decisions

### API Contract & SSE Format
- **D-01.1:** Endpoint `/v1/codex-sdk/stream` chấp nhận method `POST` với request body `CodexSdkPromptRequest` và trả về `text/event-stream` thông qua `SseEmitter`.
- **D-01.2:** Định dạng các event SSE chuẩn hóa gồm 3 loại:
  - `event: message` kèm `data: <token-string>` (token text sinh ra theo thời gian thực).
  - `event: error` kèm `data: <error-message>` (khi Node.js runtime hoặc WebClient lỗi).
  - `event: done` kèm `data: Stream finished.` (khi kết thúc toàn bộ stream).
- **D-01.3:** Xác thực luồng stream: `CodexSdkService.stream()` trích xuất Bearer token từ `HttpServletRequest` của người dùng; nếu không có, tự động fallback sang service token Keycloak qua `tokenService.getKeycloakToken(clientId, clientSecret)`.

### Unit Test Requirements (`docs/note/be-note.md`)
- **D-01.4:** Tạo test suite `CodexSdkServiceTest.java` sử dụng Mockito và JUnit 5. Test toàn bộ các nhánh:
  - `listThreads()` gọi đúng `feignClient.listThreads()`.
  - `getThreadHistory()` gọi đúng `feignClient.getThread()`.
  - `execute()` gửi đúng payload qua FeignClient.
  - `extractThreadId()` bóc tách chính xác threadId từ root object hoặc `data` wrapper.

### Claude's Discretion
- Chi tiết cấu hình WebClient timeout (mặc định 600_000ms trên SseEmitter).
</decisions>

<canonical_refs>
## Canonical References
- `services/ai-agent-mcrs/src/main/java/com/lamld/aiAgent/modules/codexsdk/api/CodexSdkController.java` — REST & SSE endpoints specification.
- `services/ai-agent-mcrs/src/main/java/com/lamld/aiAgent/modules/codexsdk/application/CodexSdkService.java` — Orchestration logic & WebClient stream consumer.
- `docs/note/be-note.md` §1 & §7 — Quy chuẩn BaseService, MapperUtil và bắt buộc 100% test pass.
</canonical_refs>

<code_context>
## Existing Code Insights
- Controller `CodexSdkController.java` đã khai báo đủ các route: `/health`, `/threads`, `/threads/{threadId}`, `/execute`, `/stream`.
- Đã có integration test mẫu tại `CodexSdkIntegrationTest.java`.
</code_context>

<deferred>
## Deferred Ideas
- Lưu log hội thoại vào database riêng của mcrs (hiện tại do `codex-sdk-service` và Mongo đảm nhiệm).
</deferred>
