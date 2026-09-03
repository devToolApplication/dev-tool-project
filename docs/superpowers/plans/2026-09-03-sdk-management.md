# SDK Management Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a centralized SDK Management module in `dev-tool-web` (`admin/system-management/sdk`) with Agent Catalog, MCP Preflight Health diagnostics, Execute Task console, and Task Run History logs.

**Architecture:** Frontend Angular module inside `system-management` integrating with `codex-sdk-service` APIs using 100% Shared UI Components (`app-page-shell`, `app-tabs`, `app-table`, `app-drawer`, `app-badge`, `app-filter-panel`, `app-json-viewer`), full bilingual i18n support, and comprehensive unit testing.

**Tech Stack:** Angular, TypeScript, RxJS, Shared UI Library, Jasmine/Karma unit tests.

---

### Task 1: SDK Management Models and i18n Translations

**Files:**
- Create: `web/dev-tool-web/src/app/features/system-management/model/sdk-management.model.ts`
- Modify: `web/dev-tool-web/src/app/core/i18n/features/system-management.i18n.json`

- [ ] **Step 1: Write model definitions**

```typescript
export type SdkAgentProvider = 'codex' | 'claude';
export type SdkPreflightStatus = 'READY' | 'DEGRADED' | 'BLOCKED_CONFIG' | 'BLOCKED_MCP';
export type SdkTaskRunStatus =
  | 'BLOCKED_CONFIG'
  | 'BLOCKED_MCP'
  | 'COMPLETED'
  | 'FAILED'
  | 'FAILED_DEPENDENCY'
  | 'RUNNING'
  | 'TIMEOUT';

export interface SdkAgentProviderOption {
  provider: SdkAgentProvider;
  available: boolean;
  health: 'HEALTHY' | 'UNHEALTHY';
}

export interface SdkAgentCatalogItem {
  agentCode: string;
  displayName: string;
  defaultProvider?: SdkAgentProvider;
  supportedProviders: SdkAgentProviderOption[];
  requiredDependencies: string[];
  health: 'HEALTHY' | 'UNHEALTHY';
}

export interface SdkAgentCatalogResponse {
  agents: SdkAgentCatalogItem[];
}

export interface SdkAgentHealthMcpResult {
  name: string;
  status: 'UP' | 'DOWN';
  configured: boolean;
  required: boolean;
  requiredTools: string[];
  missingTools: string[];
  toolCount: number;
  latencyMs: number;
  errorCode?: string;
  error?: string;
}

export interface SdkAgentHealthResponse {
  agentCode: string;
  provider: SdkAgentProvider;
  status: SdkPreflightStatus;
  mcp: SdkAgentHealthMcpResult[];
}

export interface SdkServiceHealthResponse {
  status: string;
  service: string;
  basePath?: string;
  auth: Record<string, unknown>;
  codex: Record<string, unknown>;
  database: Record<string, unknown>;
}

export interface SdkTaskExecuteRequest {
  agentCode: string;
  provider?: SdkAgentProvider;
  prompt: string;
  threadId?: string;
  workingDirectory?: string;
  model?: string;
  reasoningEffort?: string;
  outputSchema?: Record<string, unknown>;
  requestContext?: Record<string, unknown>;
  callbackUrl?: string;
  callbackAuthSecretCode?: string;
}

export interface SdkTaskExecuteResult {
  status: SdkTaskRunStatus;
  agentCode: string;
  provider: SdkAgentProvider;
  model?: string;
  threadId?: string;
  durationMs?: number;
  stdout?: string;
  stderr?: string;
  structuredOutput?: Record<string, unknown>;
  error?: string;
}

export interface SdkTaskRunSummary {
  taskId: string;
  agentCode: string;
  provider: SdkAgentProvider;
  status: SdkTaskRunStatus;
  threadId?: string;
  model?: string;
  reasoningEffort?: string;
  promptPreview: string;
  createdAt: string;
  updatedAt: string;
  completedAt?: string;
  error?: string;
}

export interface SdkTaskRunEvent {
  sequence: number;
  at: string;
  type: 'accepted' | 'preflight' | 'stdout' | 'stderr' | 'result' | 'error';
  data?: string;
  preflight?: {
    status: SdkPreflightStatus;
    agentCode: string;
    provider: SdkAgentProvider;
    mcp: unknown[];
  };
  result?: SdkTaskExecuteResult;
  error?: string;
  statusCode?: number;
}

export interface SdkTaskRunDetail extends SdkTaskRunSummary {
  request?: SdkTaskExecuteRequest;
  events: SdkTaskRunEvent[];
  result?: SdkTaskExecuteResult;
}

export interface SdkTaskRunListResponse {
  items: SdkTaskRunSummary[];
  page: number;
  size: number;
  total: number;
}

export interface SdkTaskRunListQuery {
  page?: number;
  size?: number;
  status?: SdkTaskRunStatus;
  agentCode?: string;
  provider?: SdkAgentProvider;
  threadId?: string;
  createdFrom?: string;
  createdTo?: string;
}
```

- [ ] **Step 2: Update `system-management.i18n.json` with bilingual keys**

Add `sdkManagement` keys under `"vi"` and `"en"`.

- [ ] **Step 3: Commit**

```bash
git add web/dev-tool-web/src/app/features/system-management/model/sdk-management.model.ts web/dev-tool-web/src/app/core/i18n/features/system-management.i18n.json
git commit -m "feat(system-management): add SDK management models and i18n translations"
```

---

### Task 2: SDK Admin API Service & Unit Tests

**Files:**
- Create: `web/dev-tool-web/src/app/features/system-management/api/sdk-admin-api.service.ts`
- Create: `web/dev-tool-web/src/app/features/system-management/api/sdk-admin-api.service.spec.ts`

- [ ] **Step 1: Write Unit Test for `SdkAdminApiService`**

Cover `getServiceHealth()`, `listAgents()`, `checkAgentHealth()`, `executeTask()`, `listTaskRuns()`, `getTaskRunDetail()`.

- [ ] **Step 2: Implement `SdkAdminApiService`**

Implement HTTP client calls using Angular `HttpClient` and `environment.sdkApiUrl` or relative `/ai-agent-sdk` proxy.

- [ ] **Step 3: Run unit tests**

Run: `npx ng test --include="src/app/features/system-management/api/sdk-admin-api.service.spec.ts" --watch=false --browsers=ChromeHeadless`
Expected: PASS

- [ ] **Step 4: Commit**

```bash
git add web/dev-tool-web/src/app/features/system-management/api/
git commit -m "feat(system-management): implement SdkAdminApiService with unit tests"
```

---

### Task 3: Tab 1 - Agent Catalog & MCP Health Component

**Files:**
- Create: `web/dev-tool-web/src/app/features/system-management/pages/sdk-management/components/sdk-catalog-tab/sdk-catalog-tab.component.ts`
- Create: `web/dev-tool-web/src/app/features/system-management/pages/sdk-management/components/sdk-catalog-tab/sdk-catalog-tab.component.html`
- Create: `web/dev-tool-web/src/app/features/system-management/pages/sdk-management/components/sdk-catalog-tab/sdk-catalog-tab.component.css`
- Create: `web/dev-tool-web/src/app/features/system-management/pages/sdk-management/components/sdk-catalog-tab/sdk-catalog-tab.component.spec.ts`

- [ ] **Step 1: Write failing test for `SdkCatalogTabComponent`**

Test loading catalog items, triggering test health, and opening MCP health drawer.

- [ ] **Step 2: Implement `SdkCatalogTabComponent`**

Use `app-table` with `TableConfig<SdkAgentCatalogItem>`, `app-drawer` for MCP server breakdown, and action event emitter to switch to Execute Tab.

- [ ] **Step 3: Run tests**

Run: `npx ng test --include="src/app/features/system-management/pages/sdk-management/components/sdk-catalog-tab/*.spec.ts" --watch=false --browsers=ChromeHeadless`
Expected: PASS

- [ ] **Step 4: Commit**

```bash
git add web/dev-tool-web/src/app/features/system-management/pages/sdk-management/components/sdk-catalog-tab/
git commit -m "feat(system-management): implement SdkCatalogTabComponent with MCP health drawer"
```

---

### Task 4: Tab 2 - Execute Task Console Component

**Files:**
- Create: `web/dev-tool-web/src/app/features/system-management/pages/sdk-management/components/sdk-execute-tab/sdk-execute-tab.component.ts`
- Create: `web/dev-tool-web/src/app/features/system-management/pages/sdk-management/components/sdk-execute-tab/sdk-execute-tab.component.html`
- Create: `web/dev-tool-web/src/app/features/system-management/pages/sdk-management/components/sdk-execute-tab/sdk-execute-tab.component.css`
- Create: `web/dev-tool-web/src/app/features/system-management/pages/sdk-management/components/sdk-execute-tab/sdk-execute-tab.component.spec.ts`

- [ ] **Step 1: Write failing test for `SdkExecuteTabComponent`**

Test form inputs, validation, task submission, structured JSON output rendering, and presets.

- [ ] **Step 2: Implement `SdkExecuteTabComponent`**

Responsive form with `grid-cols-1 sm:grid-cols-2`, `app-json-viewer`, and `app-copyable-text`.

- [ ] **Step 3: Run tests**

Run: `npx ng test --include="src/app/features/system-management/pages/sdk-management/components/sdk-execute-tab/*.spec.ts" --watch=false --browsers=ChromeHeadless`
Expected: PASS

- [ ] **Step 4: Commit**

```bash
git add web/dev-tool-web/src/app/features/system-management/pages/sdk-management/components/sdk-execute-tab/
git commit -m "feat(system-management): implement SdkExecuteTabComponent with structured result viewer"
```

---

### Task 5: Tab 3 - Task Run History Component

**Files:**
- Create: `web/dev-tool-web/src/app/features/system-management/pages/sdk-management/components/sdk-history-tab/sdk-history-tab.component.ts`
- Create: `web/dev-tool-web/src/app/features/system-management/pages/sdk-management/components/sdk-history-tab/sdk-history-tab.component.html`
- Create: `web/dev-tool-web/src/app/features/system-management/pages/sdk-management/components/sdk-history-tab/sdk-history-tab.component.css`
- Create: `web/dev-tool-web/src/app/features/system-management/pages/sdk-management/components/sdk-history-tab/sdk-history-tab.component.spec.ts`

- [ ] **Step 1: Write failing test for `SdkHistoryTabComponent`**

Test filter updates, loading task run list, drawer opening with timeline events, and re-run trigger.

- [ ] **Step 2: Implement `SdkHistoryTabComponent`**

`app-filter-panel`, `app-table` with server pagination, and `app-drawer` with timeline logs.

- [ ] **Step 3: Run tests**

Run: `npx ng test --include="src/app/features/system-management/pages/sdk-management/components/sdk-history-tab/*.spec.ts" --watch=false --browsers=ChromeHeadless`
Expected: PASS

- [ ] **Step 4: Commit**

```bash
git add web/dev-tool-web/src/app/features/system-management/pages/sdk-management/components/sdk-history-tab/
git commit -m "feat(system-management): implement SdkHistoryTabComponent with timeline drawer"
```

---

### Task 6: Main Container Component, Routing & Integration

**Files:**
- Create: `web/dev-tool-web/src/app/features/system-management/pages/sdk-management/sdk-management.component.ts`
- Create: `web/dev-tool-web/src/app/features/system-management/pages/sdk-management/sdk-management.component.html`
- Create: `web/dev-tool-web/src/app/features/system-management/pages/sdk-management/sdk-management.component.css`
- Create: `web/dev-tool-web/src/app/features/system-management/pages/sdk-management/sdk-management.component.spec.ts`
- Modify: `web/dev-tool-web/src/app/features/system-management/system-management.module.ts`
- Modify: `web/dev-tool-web/src/app/features/system-management/system-management.routes.ts`
- Modify: `web/dev-tool-web/src/app/features/system-management/system-management.routes.spec.ts`

- [ ] **Step 1: Implement `SdkManagementComponent` shell and tab orchestration**

Use `app-page-shell` + `app-tabs`. Coordinate events when user selects "Run Task" from Catalog or "Re-run" from History.

- [ ] **Step 2: Update Module and Routes**

Register components in `SystemManagementModule` and configure `systemManagementRoutes` for `admin/system-management/sdk` with backward-compatible redirect from `ai-agent-execution`.

- [ ] **Step 3: Run all system management tests and full build**

Run: `npm test` and `npm run build` in `web/dev-tool-web`.
Expected: 100% PASS and clean build.

- [ ] **Step 4: Commit**

```bash
git add web/dev-tool-web/src/app/features/system-management/
git commit -m "feat(system-management): integrate SdkManagementComponent container with routing and tests"
```