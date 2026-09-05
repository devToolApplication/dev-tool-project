# Codebase Structure

**Analysis Date:** 2026-09-05

## Directory Layout

```text
D:/Code/
├── .planning/                              # GSD planning, codebase maps, and phase specs
│   └── codebase/                           # Architectural, stack, conventions, and concerns docs
├── docs/                                   # Project documentation, guides, and specifications
│   ├── note/                               # Mandatory guidelines (fe-note.md, be-note.md)
│   └── superpowers/                        # Feature design specs and execution plans
├── infra/                                  # Infrastructure configurations and deployment scripts
│   └── server-install/                     # Submodule: K8s manifests, Helm charts, Prometheus configs
├── libs/                                   # Shared core libraries
│   ├── develop-tool-core-lib/              # Submodule: Java Spring Boot core foundation (BaseService, types)
│   └── develop-tool-nodejs-core-lib/       # Submodule: Node.js / TypeScript shared utilities
├── services/                               # Microservices backend implementations
│   ├── ai-agent-mcrs/                      # Submodule: Spring Boot Flowable BPMN AI orchestrator
│   ├── codex-sdk-service/                  # Submodule: TypeScript CLI execution runtime & MCP server
│   ├── develop-tool-consumer/              # Submodule: Spring Boot Kafka message consumer
│   ├── file-mcrs/                          # Submodule: Spring Boot file storage service
│   ├── job-service/                        # Submodule: Node.js Agenda distributed scheduler
│   ├── mcp-platform/                       # Submodule: Model Context Protocol (MCP) integrations
│   └── trade-bot-mcrs/                     # Submodule: Spring Boot algorithmic trading microservice
├── tools/                                  # Submodule tools & agent assets
│   └── agent-skill/                        # AI skills, prompt templates, and agent rules
├── web/                                    # Frontend web applications
│   └── dev-tool-web/                       # Submodule: Angular 21 web application with BPMN Studio
├── .gitmodules                             # Git submodule definitions
├── AGENTS.md                               # Dedicated subagent routing rules & development standards
└── CLAUDE.md                               # Project-wide coding and testing constraints
```

## Directory Purposes

**`web/dev-tool-web/`:**
- Purpose: Angular 21 Single Page Application for user interface, workflow designing, and monitoring.
- Contains: Standalone Angular components, services, stores, shared UI widgets, and Playwright E2E tests.
- Key files: `web/dev-tool-web/src/main.ts`, `web/dev-tool-web/src/app/app.config.ts`, `web/dev-tool-web/src/app/features/workflow-studio/store/workflow-editor.store.ts`.

**`services/ai-agent-mcrs/`:**
- Purpose: Primary Spring Boot microservice running the Flowable BPMN engine and delegating AI executions.
- Contains: Spring controllers, application services, Mongo storage classes, and Flowable `JavaDelegate` components.
- Key files: `services/ai-agent-mcrs/src/main/java/com/lamld/aiAgent/AiAgentApplication.java`, `services/ai-agent-mcrs/src/main/java/com/lamld/aiAgent/modules/workflowprocess/infrastructure/flowable/delegate/SubmitAiTaskDelegate.java`.

**`services/codex-sdk-service/`:**
- Purpose: Node.js service providing headless agent execution runtime, CLI process management, and Playwright MCP tools.
- Contains: Express routes, TSOA controllers, CLI process runner, and agent catalog resolvers.
- Key files: `services/codex-sdk-service/src/server.ts`, `services/codex-sdk-service/src/modules/agent-runtime/agentCliRuntime.ts`, `services/codex-sdk-service/src/modules/ai-task/aiTaskService.ts`.

**`services/trade-bot-mcrs/`:**
- Purpose: Spring Boot trading platform microservice for strategy backtesting, paper trading, and real-time execution.
- Contains: Market data integrations (Binance, Yahoo), trading simulators, rule evaluators, and portfolio tracking.
- Key files: `services/trade-bot-mcrs/src/main/java/com/lamld/tradebotmcrs/TradeBotMcrsApplication.java`.

**`services/job-service/`:**
- Purpose: Node.js distributed job scheduler backed by MongoDB Agenda.
- Contains: Job execution handlers, token cache refreshes, and cron trigger policies.
- Key files: `services/job-service/src/server.ts`, `services/job-service/src/modules/job-execution/jobExecutionService.ts`.

**`libs/develop-tool-core-lib/`:**
- Purpose: Central Java library shared across all Spring Boot microservices.
- Contains: `BaseService`, `BaseController`, `BaseResponse`, `BusinessException`, `MapperUtil`, and security filters.
- Key files: `libs/develop-tool-core-lib/src/main/java/vn/devTool/core/base/BaseService.java`, `libs/develop-tool-core-lib/src/main/java/vn/devTool/core/utils/MapperUtil.java`.

**`libs/develop-tool-nodejs-core-lib/`:**
- Purpose: Central Node.js library shared across TypeScript microservices.
- Contains: Express error middlewares, JWT authentication verifiers, MongoDB connection pools, and logging helpers.
- Key files: `libs/develop-tool-nodejs-core-lib/src/index.ts`, `libs/develop-tool-nodejs-core-lib/src/auth/authMiddleware.ts`.

**`docs/`:**
- Purpose: Development standards, design specifications, and implementation notes.
- Contains: Mandatory development rules (`docs/note/fe-note.md`, `docs/note/be-note.md`), architecture designs.

## Key File Locations

**Entry Points:**
- `web/dev-tool-web/src/main.ts`: Angular frontend entry point.
- `services/ai-agent-mcrs/src/main/java/com/lamld/aiAgent/AiAgentApplication.java`: AI Agent microservice Spring Boot entry point.
- `services/codex-sdk-service/src/server.ts`: Codex SDK execution service entry point.
- `services/job-service/src/server.ts`: Job scheduler service entry point.
- `services/trade-bot-mcrs/src/main/java/com/lamld/tradebotmcrs/TradeBotMcrsApplication.java`: Trade Bot service entry point.
- `services/file-mcrs/src/main/java/com/lamld/filemcrs/FileMcrsApplication.java`: File service entry point.

**Configuration:**
- `web/dev-tool-web/angular.json`: Angular build and workspace config.
- `web/dev-tool-web/src/app/app.config.ts`: Angular application runtime providers and routes.
- `services/ai-agent-mcrs/src/main/resources/application.properties`: Spring Boot properties (MongoDB, Flowable, Security, Feign).
- `services/codex-sdk-service/tsoa.json`: TSOA OpenAPI generator configuration.
- `services/codex-sdk-service/tsconfig.json`: TypeScript compiler options for Codex SDK.

**Core Logic:**
- `services/ai-agent-mcrs/src/main/java/com/lamld/aiAgent/modules/workflowprocess/infrastructure/flowable/delegate/SubmitAiTaskDelegate.java`: Flowable BPMN AI delegate executor.
- `services/ai-agent-mcrs/src/main/java/com/lamld/aiAgent/modules/workflowprocess/application/admin/WorkflowRunService.java`: Flowable process instance and task lifecycle management.
- `services/codex-sdk-service/src/modules/agent-runtime/agentCliRuntime.ts`: CLI runtime executor for Claude/Agy agents.
- `web/dev-tool-web/src/app/features/workflow-studio/store/workflow-editor.store.ts`: Frontend reactive state store for BPMN workflow studio.

**Testing:**
- `web/dev-tool-web/src/app/features/workflow-studio/store/workflow-editor.store.spec.ts`: Unit tests for Angular store.
- `web/dev-tool-web/e2e/`: Playwright end-to-end integration tests.
- `services/codex-sdk-service/src/modules/ai-task/aiTaskService.test.ts`: Unit tests for AI task service.
- `services/ai-agent-mcrs/src/test/java/com/lamld/aiAgent/`: Spring Boot unit tests (JUnit 5 + Mockito).

## Naming Conventions

**Files:**
- Angular Components: `kebab-case.component.ts` (e.g. `workflow-studio.component.ts`)
- Angular Services / Stores: `kebab-case.service.ts` / `kebab-case.store.ts` (e.g. `workflow-editor.store.ts`)
- Angular Templates / Styles: `kebab-case.component.html` / `kebab-case.component.scss`
- Java Classes: `PascalCase.java` (e.g. `WorkflowAdminController.java`, `AccountStorage.java`, `AccountEntity.java`)
- TypeScript Modules: `camelCase.ts` or `kebab-case.ts` (e.g. `agentCliRuntime.ts`, `aiTask.controller.ts`)
- Test Files: `*.spec.ts` (Angular Vitest/Jasmine), `*.test.ts` (Node Jest/Vitest), `*Test.java` (Spring Boot JUnit)

**Directories:**
- Java Packages: `lowercase` (e.g. `com/lamld/aiAgent/modules/workflowprocess/`)
- Angular & Node Modules: `kebab-case` (e.g. `workflow-studio`, `account-management`, `agent-runtime`)

## Where to Add New Code

**New Feature in Frontend:**
- Primary code: `web/dev-tool-web/src/app/features/{feature-name}/`
  - Pages / Containers: `pages/`
  - Reactive Signals / Stores: `store/`
  - Backend API Clients: `services/` or `api/`
  - TypeScript Models: `models/`
- Translations: `web/dev-tool-web/src/app/core/i18n/features/{feature-name}.i18n.json`
- Tests: Co-located `*.spec.ts` files and `web/dev-tool-web/e2e/{feature-name}.spec.ts`

**New Feature in Backend (Java Spring Boot):**
- Implementation: `services/{service-name}/src/main/java/com/lamld/{serviceName}/modules/{moduleName}/`
  - REST Endpoints: `api/{ModuleName}AdminController.java`
  - Request / Response DTOs: `api/request/` and `api/response/`
  - Application Service: `application/{ModuleName}Service.java` (MUST `extends BaseService`)
  - Storage Layer: `infrastructure/storage/{ModuleName}Storage.java` (encapsulates `MongoTemplate` / `Repository`)
  - Entities: `infrastructure/entity/{ModuleName}Entity.java`
  - Repositories: `infrastructure/repository/{ModuleName}Repository.java`
- Tests: `services/{service-name}/src/test/java/.../{ModuleName}ServiceTest.java`

**New Feature in Backend (Node.js / TypeScript):**
- Controller & Routing: `services/{service-name}/src/modules/{moduleName}/{moduleName}.controller.ts`
- Business Logic: `services/{service-name}/src/modules/{moduleName}/{moduleName}Service.ts`
- Data Access: `services/{service-name}/src/modules/{moduleName}/{moduleName}Repository.ts`
- Tests: Co-located `{moduleName}Service.test.ts`

**Utilities & Shared Code:**
- Java Shared Utilities: `libs/develop-tool-core-lib/src/main/java/vn/devTool/core/utils/`
- Node.js Shared Helpers: `libs/develop-tool-nodejs-core-lib/src/utils/`
- Frontend Shared UI Primitives: `web/dev-tool-web/src/app/shared/ui/`
- Frontend Helper Functions: `web/dev-tool-web/src/app/shared/utils/`

## Special Directories

**`infra/server-install/`:**
- Purpose: Kubernetes manifests, Helm charts, Docker compose configurations, and Prometheus deployment values.
- Generated: No
- Committed: Yes (Git Submodule)

**`tools/agent-skill/`:**
- Purpose: Agent prompt skills, role configurations, and rule mappings.
- Generated: No
- Committed: Yes (Git Submodule)

**`web/dev-tool-web/dist/` / `web/dev-tool-web/.angular/`:**
- Purpose: Compiled frontend bundles and Angular compiler cache.
- Generated: Yes
- Committed: No

**`services/*/target/` / `services/*/dist/`:**
- Purpose: Compiled Java JAR binaries and TypeScript transpile artifacts.
- Generated: Yes
- Committed: No

---

*Structure analysis: 2026-09-05*
