<!-- refreshed: 2026-09-05 -->
# Architecture

**Analysis Date:** 2026-09-05

## System Overview

```text
┌──────────────────────────────────────────────────────────────────────────────────┐
│                            Frontend Web (Angular 21)                             │
│                         `web/dev-tool-web/src/app`                               │
│  - App Shell / Navigation (`app-shell/`)                                         │
│  - Shared UI Primitives/Layout/Data-Display (`shared/ui/`)                       │
│  - Workflow Studio & Visual BPMN Designer (`features/workflow-studio/`)          │
│  - Account & Service Management Pages (`features/`)                              │
└────────────────────────────────────────┬─────────────────────────────────────────┘
                                         │ HTTP / REST / OpenID Connect
                                         ▼
┌──────────────────────────────────────────────────────────────────────────────────┐
│                             Microservices Layer                                  │
├────────────────────────────────┬─────────────────────────────────────────────────┤
│       ai-agent-mcrs            │             trade-bot-mcrs                      │
│ `services/ai-agent-mcrs`       │ `services/trade-bot-mcrs`                       │
│ - Workflow Execution (Flowable)│ - Market Data & Order Replay                    │
│ - Account & Secret Management  │ - Backtesting & Real-time Execution             │
├────────────────────────────────┼─────────────────────────────────────────────────┤
│       job-service              │             codex-sdk-service                   │
│ `services/job-service`         │ `services/codex-sdk-service`                    │
│ - Agenda.js Distributed Jobs   │ - Headless Agent / Codex CLI Runtime Wrapper    │
│ - Outbound Auth & Retry Queue  │ - Playwright MCP Server & Facebook Discovery    │
├────────────────────────────────┼─────────────────────────────────────────────────┤
│       file-mcrs                │        develop-tool-consumer                    │
│ `services/file-mcrs`           │ `services/develop-tool-consumer`                │
│ - File Upload / Storage Gateway│ - Async Kafka Event Consumer                    │
└────────────────────────────────┴─────────────────────────────────────────────────┘
         │ (Spring Data / Feign)                  │ (Native Driver / TSOA)
         ▼                                        ▼
┌──────────────────────────────────────────────────────────────────────────────────┐
│                               Shared Core Libraries                              │
│ - Java Framework & Base Classes: `libs/develop-tool-core-lib`                   │
│ - Node.js Shared Utilities & DB: `libs/develop-tool-nodejs-core-lib`            │
└────────────────────────────────────────┬─────────────────────────────────────────┘
                                         │
                                         ▼
┌──────────────────────────────────────────────────────────────────────────────────┐
│                         Persistence & External Services                          │
│  - MongoDB (Primary Document Store) / PostgreSQL (Flowable Engine State DB)      │
│  - Redis (Distributed Token & Rate Limit Cache)                                  │
│  - Kafka (Event Streaming Bus) & Keycloak (Identity & Access Management)         │
└──────────────────────────────────────────────────────────────────────────────────┘
```

## Component Responsibilities

| Component | Responsibility | File |
|-----------|----------------|------|
| `dev-tool-web` | Client-side SPA providing visual BPMN diagramming, workflow execution monitoring, and account management | `web/dev-tool-web/src/app/app.config.ts` |
| `ai-agent-mcrs` | Main orchestration microservice: Flowable BPMN workflow engine integration, AI task dispatching, account credential resolution | `services/ai-agent-mcrs/src/main/java/com/lamld/aiAgent/AiAgentApplication.java` |
| `codex-sdk-service` | Headless execution harness for AI CLI runtimes, task lifecycle orchestration, and MCP integrations (Playwright / Facebook) | `services/codex-sdk-service/src/server.ts` |
| `trade-bot-mcrs` | Algorithmic trading orchestration, market data stream adapters (Binance/Yahoo), backtesting, paper trading | `services/trade-bot-mcrs/src/main/java/com/lamld/tradebotmcrs/TradeBotMcrsApplication.java` |
| `job-service` | Scheduled task execution and recurring workflow triggers using Agenda.js and MongoDB | `services/job-service/src/server.ts` |
| `file-mcrs` | File upload, asset validation, and document storage service | `services/file-mcrs/src/main/java/com/lamld/filemcrs/FileMcrsApplication.java` |
| `develop-tool-consumer` | Kafka message consumer handling asynchronous domain events and background worker tasks | `services/develop-tool-consumer/src/main/java/com/lamld/filemcrs/DevelopToolConsumerApplication.java` |
| `develop-tool-core-lib` | Standardized Java library defining `BaseService`, `BaseController`, `BaseResponse`, `BusinessException`, and security filters | `libs/develop-tool-core-lib/src/main/java/vn/devTool/core/base/BaseService.java` |
| `develop-tool-nodejs-core-lib` | Shared TypeScript foundation for Node services (auth middleware, logging, MongoDB connection helpers) | `libs/develop-tool-nodejs-core-lib/src/index.ts` |

## Pattern Overview

**Overall:** Microservices Architecture with Clean Layered Domain Modules (Backend) and Reactive Component-Store Pattern (Frontend).

**Key Characteristics:**
- **3-Tier Backend Storage Pattern:** Java services strictly segregate API controllers, domain application services, and storage abstractions (`BaseService` -> `{Module}Storage` -> `MongoTemplate` / `Repository`). Direct repository injection in services is forbidden.
- **BPMN 2.0 Process-Driven AI Execution:** Flowable BPMN 2.0 Engine is embedded directly in Spring Boot (`ai-agent-mcrs`), with custom JavaDelegates (`SubmitAiTaskDelegate`) executing steps via REST FeignClient to runtime providers.
- **Strict Shared UI Wrappers:** Frontend is strictly component-driven; direct third-party UI component calls (e.g. raw PrimeNG or HTML table elements) are banned in favor of uniform project wrappers (`app-table`, `app-action-toolbar`, `app-dialog`, `app-drawer`).
- **Signal-Based Frontend State Management:** Angular 21 Signals and reactive stores (`WorkflowEditorStore`) govern state with undo/redo snapshot capabilities.

## Layers

### Frontend Web (`web/dev-tool-web`)
- Purpose: User interface, visual workflow modeling, dashboard reporting, and administration.
- Location: `web/dev-tool-web/src/app`
- Contains:
  - `core/`: Auth interceptors, HTTP clients, notification services, i18n dictionary loader (`I18nService`).
  - `shared/ui/`: Standardized UI components (data-display, feedback, forms, layout, overlay, primitives).
  - `features/`: Domain-specific UI modules (`workflow-studio`, `account-management`, `service-management`).
  - `app-shell/`: Navigation, side-menu, headers, responsive layouts.
- Depends on: PrimeNG primitives (encapsulated in `shared/ui`), Tailwind CSS, BPMN.js.
- Used by: End users and administrators via web browsers.

### Backend Application Services (`services/*`)
- Purpose: Execute business logic, manage authentication/authorization, coordinate workflows, and interface with datastores.
- Location: `services/ai-agent-mcrs`, `services/codex-sdk-service`, `services/job-service`, `services/trade-bot-mcrs`
- Contains:
  - `api/`: REST Controllers, OpenAPI specifications, request validation DTOs (`*Request`, `*Dto`).
  - `application/`: Domain services extending `BaseService`, handling transactions and business rules.
  - `domain/`: Domain models, value objects, and business entities.
  - `infrastructure/`: Storage classes (`*Storage`), Spring Data Repositories, Feign clients, and Flowable delegates.
- Depends on: `libs/develop-tool-core-lib`, `libs/develop-tool-nodejs-core-lib`, MongoDB, PostgreSQL, Redis, Kafka.
- Used by: Frontend SPA, scheduler triggers, inter-service HTTP/Kafka calls.

### Core Libraries (`libs/*`)
- Purpose: Enforce cross-cutting consistency across all Java and Node microservices.
- Location: `libs/develop-tool-core-lib`, `libs/develop-tool-nodejs-core-lib`
- Contains:
  - Base classes (`BaseService`, `BaseController`, `BaseResponse`, `BaseEntity`).
  - Error and exception models (`BusinessException`, `BusinessErrorCode`).
  - Object mapping utilities (`MapperUtil`).
  - Common security filters, JWT validation, MDC logging filters.
- Depends on: Spring Boot Starters, Jackson, ModelMapper, MongoDB driver, Jose (JWT).
- Used by: All microservices in `services/`.

## Data Flow

### Primary Request Path (Workflow Execution Flow)

1. **Workflow Trigger:** Client dispatches workflow start request to `WorkflowAdminController.java` (`services/ai-agent-mcrs/src/main/java/com/lamld/aiAgent/modules/workflowprocess/api/admin/WorkflowAdminController.java:46`).
2. **Process Engine Initiation:** `WorkflowRunService.java` validates definition and starts Flowable process instance via `ProcessEngine` (`services/ai-agent-mcrs/src/main/java/com/lamld/aiAgent/modules/workflowprocess/application/admin/WorkflowRunService.java:56`).
3. **Delegate Execution:** Flowable engine executes `SubmitAiTaskDelegate.java` (`services/ai-agent-mcrs/src/main/java/com/lamld/aiAgent/modules/workflowprocess/infrastructure/flowable/delegate/SubmitAiTaskDelegate.java:41`).
4. **Credential Enrichment:** Delegate fetches required account secrets via `AccountService.java` (`services/ai-agent-mcrs/src/main/java/com/lamld/aiAgent/modules/account/application/AccountService.java:26`).
5. **AI Dispatch:** Delegate invokes `CodexSdkFeignClient` calling `codex-sdk-service` (`services/codex-sdk-service/src/modules/ai-task/aiTask.controller.ts`).
6. **Task Run Execution:** `AgentCliRuntime` spawns CLI subagent process, executes task, captures structured JSON output (`services/codex-sdk-service/src/modules/agent-runtime/agentCliRuntime.ts`).
7. **Flow Update:** Delegate saves step results back into Flowable execution variables and history queries.

### Secondary Flow Name (Frontend Visual Editor Workflow Update)

1. **User Interaction:** User drags/connects nodes in BPMN canvas inside `WorkflowStudioComponent` (`web/dev-tool-web/src/app/features/workflow-studio/pages/workflow-studio.component.ts`).
2. **Store Mutation:** `WorkflowEditorStore.ts` captures change, runs `validateWorkflowConnection`, updates signal state, and pushes history snapshot for undo/redo (`web/dev-tool-web/src/app/features/workflow-studio/store/workflow-editor.store.ts:62`).
3. **Persistence:** `WorkflowPersistenceService.ts` serializes BPMN XML and payload metadata, calling backend REST API (`web/dev-tool-web/src/app/features/workflow-studio/services/workflow-persistence.service.ts`).

**State Management:**
- **Frontend:** Angular 21 Signals with encapsulated stores (`WorkflowEditorStore`) and RxJS reactive streams.
- **Backend Flow State:** Process state stored in Flowable database tables (PostgreSQL/H2/MongoDB), domain models stored in MongoDB collections.

## Key Abstractions

**`BaseService` & `Storage` Layer:**
- Purpose: Standardizes entity persistence, pagination queries, DTO mapping, and exception handling across all Spring Boot microservices.
- Examples:
  - `libs/develop-tool-core-lib/src/main/java/vn/devTool/core/base/BaseService.java`
  - `services/ai-agent-mcrs/src/main/java/com/lamld/aiAgent/modules/account/infrastructure/storage/AccountStorage.java`
- Pattern: Repository / Storage Gateway pattern separating business logic from raw queries.

**`JavaDelegate` AI Bridge:**
- Purpose: Maps BPMN 2.0 ServiceTask definitions to external AI / CLI execution workers with full variable context resolution.
- Examples:
  - `services/ai-agent-mcrs/src/main/java/com/lamld/aiAgent/modules/workflowprocess/infrastructure/flowable/delegate/SubmitAiTaskDelegate.java`
- Pattern: Command / Adapter Pattern.

**Shared UI Design System Component Wrappers:**
- Purpose: Enforces unified layout, accessibility, and theming without binding direct view code to third-party vendor libraries.
- Examples:
  - `web/dev-tool-web/src/app/shared/ui/data-display/table/`
  - `web/dev-tool-web/src/app/shared/ui/layout/page-shell/`
- Pattern: Composite UI Component Pattern.

## Entry Points

**Frontend Application:**
- Location: `web/dev-tool-web/src/main.ts`
- Triggers: Browser loading client bundle.
- Responsibilities: Bootstraps standalone Angular application with `appConfig` (`web/dev-tool-web/src/app/app.config.ts`), initializing routes, Keycloak auth interceptor, and global error handlers.

**`ai-agent-mcrs` Backend:**
- Location: `services/ai-agent-mcrs/src/main/java/com/lamld/aiAgent/AiAgentApplication.java`
- Triggers: JVM startup (`mvn spring-boot:run` / container launch).
- Responsibilities: Initializes Spring Boot context, Flowable ProcessEngine beans, MongoDB connections, and registers REST endpoints under `/v1/admin/*`.

**`codex-sdk-service` Server:**
- Location: `services/codex-sdk-service/src/server.ts`
- Triggers: Node runtime initialization (`npm run dev` / `node dist/server.js`).
- Responsibilities: Boots Express/TSOA server, configures OpenAPI docs, mounts authentication middleware, and registers AI Task runner routes.

**`job-service` Scheduler:**
- Location: `services/job-service/src/server.ts`
- Triggers: Node startup.
- Responsibilities: Connects to MongoDB Agenda.js instance, registers recurring cron jobs, and dispatches HTTP tasks.

## Architectural Constraints

- **Storage Isolation Rule:** Services MUST NOT inject `Repository` classes directly. All DB operations must pass through `{Module}Storage` using `MongoTemplate` and `Repository`.
- **Frontend Direct Execute Prohibition:** Frontend web application (`dev-tool-web`) MUST NEVER call `codex-sdk-service` directly. All executions must route through `ai-agent-mcrs` via authenticated server-to-server Feign/REST channels.
- **BPMN Standard Compliance:** Flowable execution must use standard BPMN 2.0 constructs (`ServiceTask`, `UserTask`, `CallActivity`, `ExclusiveGateway`). Custom ad-hoc DAG engines or intermediate JSON execution trees are strictly prohibited.
- **Encoding Standard:** All source files created on Windows environments must be UTF-8 No BOM to prevent Java compilation errors (`﻿`).
- **Global State Isolation:** Delegate beans in Spring (`SubmitAiTaskDelegate`) are singletons; mutable execution state must only be stored in `DelegateExecution` variables to ensure thread-safety.

## Anti-Patterns

### Direct Repository Injection in Services
**What happens:** Developer injects `AccountRepository` directly into `AccountService`.
**Why it's wrong:** Breaks the 3-layer architecture, couples query mechanics with business logic, and makes mocking during unit tests cumbersome.
**Do this instead:** Inject `AccountStorage` into `AccountService` (`services/ai-agent-mcrs/src/main/java/com/lamld/aiAgent/modules/account/application/AccountService.java`).

### Unwrapped Third-Party UI Components
**What happens:** Direct import and usage of `<p-table>` or raw `<table>` in feature templates.
**Why it's wrong:** Violates design system rules, breaks responsive mobile-first behavior, and bypasses project-wide i18n pipes.
**Do this instead:** Use `app-table` with `TableConfig<T>` interface (`web/dev-tool-web/src/app/shared/ui/data-display/table/`).

### Hardcoded i18n Strings
**What happens:** Writing hardcoded Vietnamese or English strings directly in HTML templates.
**Why it's wrong:** Prevents runtime locale switching and breaks multi-language consistency.
**Do this instead:** Declare translations in `src/app/core/i18n/features/{feature}.i18n.json` and use the `translateContent` pipe.

## Error Handling

**Strategy:** Centralized Business Exception Handling with typed error codes.

**Patterns:**
- **Backend Standard:** Services throw `BusinessException(BusinessErrorCode.DATA_NOT_FOUND, "...")` which is caught by global exception handlers (`libs/develop-tool-core-lib/src/main/java/vn/devTool/core/exceptions/`) returning standard `BaseResponse` with `httpStatus: 400/404/500` and detailed `errorMessage`.
- **Flowable Delegate Errors:** Delegates catch runtime exceptions and set execution variables `aiStatus = FAILED`, `finalOutcome = FAIL`, and `errorMessage` so Exclusive Gateways can branch to compensation or error paths.
- **Frontend Toast Notifications:** Errors intercepted from HTTP responses are passed directly to `NotificationService` / Toast component using BE `errorMessage`.

## Cross-Cutting Concerns

**Logging:** Slf4j + Logback in Java services; Winston / custom logger in Node services. Request tracing using MDC filter (`libs/develop-tool-core-lib/src/main/java/vn/devTool/core/filter/`).
**Validation:** Jakarta Bean Validation (`@Valid`, `@NotNull`, `@NotBlank`) on Java request DTOs; Zod / TSOA schema validations on Node.js services.
**Authentication:** Keycloak OpenID Connect / OAuth2 JWT bearer tokens. In Spring Boot, `vn.devTool.core.sercurities` filters parse JWT claims and enforce role checks (`@PreAuthorize(UserRole.HAS_AI_AGENT_ADMIN)`). Node services validate bearer tokens using `jose`.

---

*Architecture analysis: 2026-09-05*
