# Design Specification: SDK Management Module (`dev-tool-web`)

- **Author**: Codex Agent
- **Date**: 2026-09-03
- **Status**: Approved
- **Scope**: Frontend (`web/dev-tool-web`) interacting with `codex-sdk-service` APIs

---

## 1. Executive Summary & Goals
Build an enterprise-grade SDK Management screen inside `dev-tool-web` under the **System Management** module (`admin/system-management/sdk`). 
The module provides a centralized portal for administrators and developers to:
1. View and inspect AI Agent Catalog and real-time MCP Preflight Health diagnostics.
2. Interactively execute AI tasks with JSON schema validation, agent auto-completion, and live structured output inspection.
3. Search, filter, and inspect AI Task Run execution history with event timeline logs and stdout/stderr traces.

---

## 2. Architecture & API Specifications

The frontend interacts with existing endpoints provided by `codex-sdk-service`:

| Endpoint | Method | Description |
|---|---|---|
| `/health` | `GET` | Service & sub-component health check (MongoDB, Codex CLI, Auth) |
| `/v1/admin/ai-agents` | `GET` | Retrieve Agent Catalog list (code, displayName, supportedProviders, dependencies) |
| `/v1/admin/ai-agents/{agentCode}/health` | `GET` | Trigger MCP preflight check & retrieve server latency and tools status |
| `/v1/ai/tasks/execute` | `POST` | Execute AI task payload synchronously |
| `/v1/ai/tasks/runs` | `GET` | Query paginated list of task execution runs with filters |
| `/v1/ai/tasks/runs/{taskId}` | `GET` | Retrieve detailed task execution snapshot, result, and timeline events |

---

## 3. UI Component Structure & Folder Layout

All components follow the guidelines in `docs/note/fe-note.md`:
- 100% Shared UI Components (`app-page-shell`, `app-table`, `app-drawer`, `app-badge`, `app-filter-panel`, `app-json-viewer`, `app-copyable-text`).
- Standard `TableConfig<T>` configuration.
- Full bilingual i18n support in `src/app/core/i18n/features/system-management.i18n.json`.
- Responsive Mobile-First layouts.

### Folder Layout:
```text
web/dev-tool-web/src/app/features/system-management/
├── api/
│   ├── sdk-admin-api.service.ts
│   └── sdk-admin-api.service.spec.ts
├── model/
│   └── sdk-management.model.ts
├── pages/
│   ├── sdk-management/
│   │   ├── sdk-management.component.ts
│   │   ├── sdk-management.component.html
│   │   ├── sdk-management.component.css
│   │   ├── sdk-management.component.spec.ts
│   │   └── components/
│   │       ├── sdk-catalog-tab/
│   │       │   ├── sdk-catalog-tab.component.ts
│   │       │   ├── sdk-catalog-tab.component.html
│   │       │   ├── sdk-catalog-tab.component.css
│   │       │   └── sdk-catalog-tab.component.spec.ts
│   │       ├── sdk-execute-tab/
│   │       │   ├── sdk-execute-tab.component.ts
│   │       │   ├── sdk-execute-tab.component.html
│   │       │   ├── sdk-execute-tab.component.css
│   │       │   └── sdk-execute-tab.component.spec.ts
│   │       └── sdk-history-tab/
│   │           ├── sdk-history-tab.component.ts
│   │           ├── sdk-history-tab.component.html
│   │           ├── sdk-history-tab.component.css
│   │           └── sdk-history-tab.component.spec.ts
```

---

## 4. Detailed Feature Specifications

### 4.1. Main Page Shell (`SdkManagementComponent`)
- **Header**: Displays overall SDK Service Health status badge (Healthy / Degraded / Down) and refresh action.
- **Tab Bar (`app-tabs`)**: 3 tabs with active tab tracking:
  - Tab 1: `systemManagement.sdkManagement.tabs.catalog`
  - Tab 2: `systemManagement.sdkManagement.tabs.execute`
  - Tab 3: `systemManagement.sdkManagement.tabs.history`
- **Tab State Coordination**: Selecting "Execute" from Catalog or History automatically switches to Tab 2 and pre-fills the execution form.

### 4.2. Tab 1: Agent Catalog & MCP Health (`SdkCatalogTabComponent`)
- **Data Table (`app-table`)**:
  - Columns: `agentCode`, `displayName`, `supportedProviders` (badges for `codex`/`claude`), `requiredDependencies`, `health` (`HEALTHY`/`UNHEALTHY`), and `actions`.
  - Actions:
    - **Test Health**: Calls `/v1/admin/ai-agents/{agentCode}/health` and opens the Health Drawer.
    - **Run Task**: Triggers event to main container to switch to Execute Tab with prefilled `agentCode`.
- **MCP Health Detail Drawer (`app-drawer`)**:
  - Displays overall preflight status: `READY`, `DEGRADED`, `BLOCKED_MCP`, `BLOCKED_CONFIG`.
  - Lists each MCP server: Server name, status (`UP`/`DOWN`), Latency (`ms`), Available Tools count, Missing Tools (highlighted in red), and Error trace if any.

### 4.3. Tab 2: Execute Task Console (`SdkExecuteTabComponent`)
- **Input Form**:
  - Fields: `agentCode` (select dropdown populated from catalog), `provider` (`codex`/`claude`), `model`, `reasoningEffort`, `prompt` (textarea), `outputSchemaText` (JSON), `requestContextText` (JSON), `callbackUrl`, `callbackAuthSecretCode`.
  - Layout: `grid grid-cols-1 sm:grid-cols-2 gap-3` responsive grid.
  - Actions: "Execute Task", "Reset", "Load Sample Template".
- **Result Panel**:
  - Status badge, duration execution in `ms`.
  - Output display: `app-json-viewer` for structured JSON output, raw stdout/stderr tabs, and `app-copyable-text` for easy payload copying.

### 4.4. Tab 3: Task Run History (`SdkHistoryTabComponent`)
- **Filter Panel (`app-filter-panel`)**:
  - Fields: Status filter (`COMPLETED`, `FAILED`, `BLOCKED_MCP`, `BLOCKED_CONFIG`, `TIMEOUT`), Agent Code search, Provider filter, Date Range.
- **History Table (`app-table`)**:
  - Columns: `taskId`, `agentCode`, `provider`, `status`, `promptPreview`, `createdAt`, `completedAt`, `actions`.
  - Pagination: Server-side pagination controls (`page`, `size`, `total`).
- **Run Detail Drawer (`app-drawer`)**:
  - Request Snapshot viewer.
  - Interactive Events Timeline: `accepted` -> `preflight` -> `stdout` -> `result` / `error`.
  - Action: "Re-run in Console" to clone config into Tab 2.

---

## 5. Non-Functional Requirements & Testing Gates
- **i18n**: All text, tooltips, table headers, error notices are localized in English and Vietnamese.
- **Error Resilience**: Graceful error handling for offline/unavailable SDK service with user-friendly alerts.
- **Unit Testing**:
  - `sdk-admin-api.service.spec.ts` testing all API routes and error transformations.
  - Component specs for `SdkManagementComponent` and all 3 tab components.
  - Mandatory 100% test pass via `npm run test`.