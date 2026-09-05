# Technology Stack

**Analysis Date:** 2026-09-05

## Languages

**Primary:**
- Java 21 (LTS) - Backend core library (`libs/develop-tool-core-lib`), AI Agent orchestrator (`services/ai-agent-mcrs`), Trading bot service (`services/trade-bot-mcrs`), Upload/File management service (`services/file-mcrs`), and Kafka consumer (`services/develop-tool-consumer`)
- TypeScript 5.8 / 5.9 - Frontend SPA (`web/dev-tool-web`), Codex SDK service (`services/codex-sdk-service`), Job scheduler (`services/job-service`), Node core library (`libs/develop-tool-nodejs-core-lib`), and MCP platform / servers (`services/mcp-platform`)

**Secondary:**
- Python 3.10+ - MCP platform Facebook legacy bridge (`services/mcp-platform/facebookmcp/bridge.py`)
- Shell / PowerShell / Batch - Deployment automation and submodule tooling (`infra/server-install/k8s-deployment/scripts/`, `push-all-submodules.sh`, `push-all-submodules.bat`)
- YAML / JSON - Kubernetes manifests, Helm charts, OpenAPI specifications, and MCP catalogs (`infra/server-install/`, `services/mcp-platform/catalog.yaml`)

## Runtime

**Environment:**
- OpenJDK 21
- Node.js 20+ / 24+ (ES Modules enabled via `"type": "module"`)
- Python 3.10+ (used by `agentic-facebook` bridge)
- Kubernetes Cluster (Rancher / Longhorn / Ingress NGINX)

**Package Manager:**
- Maven 3.9+ (Java services & shared library) - `pom.xml`
- npm 11.8.0 / 10+ (Frontend & Node microservices) - `package.json` with `package-lock.json`
- pip (Python requirements) - `services/mcp-platform/facebookmcp/requirements.txt`
- Lockfiles: Present across all Node and Python modules

## Frameworks

**Core:**
- Spring Boot 3.5.0 - Primary backend framework across Java microservices (`services/ai-agent-mcrs`, `services/trade-bot-mcrs`, `services/file-mcrs`, `services/develop-tool-consumer`, `libs/develop-tool-core-lib`)
- Angular 21.1.0 / 21.2.13 - Frontend Single Page Application (`web/dev-tool-web`)
- Express 5.2.1 - Web framework for Node.js microservices (`services/codex-sdk-service`, `services/job-service`, `libs/develop-tool-nodejs-core-lib`)
- Flowable BPMN Engine 7.2.0 - Workflow orchestration and process execution (`services/ai-agent-mcrs`)
- Model Context Protocol (MCP) SDK 0.5.0 / 1.21.1 / Spring AI Starter MCP 1.1.8 - LLM tool integration & MCP runtime (`services/codex-sdk-service`, `services/mcp-platform/facebookmcp`, `services/ai-agent-mcrs`)

**Testing:**
- Vitest 4.0.8 / 4.1.11 - Frontend unit & integration testing (`web/dev-tool-web`, `services/mcp-platform/facebookmcp`)
- Playwright 1.52.0 / 1.60.0 - End-to-end (E2E) testing & browser automation (`web/dev-tool-web`, `services/ai-agent-mcrs`)
- Storybook 10.3.6 & Chromatic 16.6.1 - UI component isolation, cataloging, and visual regression testing (`web/dev-tool-web`)
- JUnit Jupiter 5.x & Mockito 5.x - Java unit and integration testing (`services/ai-agent-mcrs`, `services/trade-bot-mcrs`, `libs/develop-tool-core-lib`)
- Node.js Native Test Runner (`node --test --import tsx`) - Node.js microservices unit testing (`services/codex-sdk-service`, `services/job-service`, `libs/develop-tool-nodejs-core-lib`)
- Testcontainers - Integration testing with ephemeral containers (`services/ai-agent-mcrs`)

**Build/Dev:**
- Angular CLI 21.1.3 & Vite / `@angular/build` - Frontend bundling and development server
- Tailwind CSS 4.1.18 & PostCSS 8.5.6 - Utility-first styling framework
- Spring Boot Maven Plugin 3.4.2 / 3.5.0 - Java microservice packaging
- tsx 4.21+ - TypeScript execution runtime for Node.js services without pre-compilation
- tsoa 6.6.0 - TypeScript OpenAPI / Swagger schema generator (`services/codex-sdk-service`)
- Style Dictionary 5.4.1 & Tokens Studio SD Transforms - Design token management and build (`web/dev-tool-web`)

## Key Dependencies

**Critical:**
- `org.flowable:flowable-spring-boot-starter-process:7.2.0` - BPMN 2.0 workflow execution engine in `services/ai-agent-mcrs`
- `@modelcontextprotocol/sdk` & `spring-ai-starter-mcp-server-webflux:1.1.8` - Model Context Protocol servers and client integration
- `@openai/codex:0.142.5` & `@anthropic-ai/claude-code:2.1.241` - AI Agent SDK execution bridges in `services/codex-sdk-service`
- `dev.langchain4j:langchain4j-core:1.12.2` - Java LLM orchestration in `services/ai-agent-mcrs`
- `bpmn-js:18.25.1` & `bpmn-moddle:10.1.0` - Interactive BPMN visual designer on web frontend (`web/dev-tool-web`)
- `io.github.binance:binance-derivatives-trading-usds-futures:11.0.0` - Binance USD-M Futures exchange integration (`services/trade-bot-mcrs`)
- `agenda:6.2.5` & `@agendajs/mongo-backend:4.0.2` - MongoDB-backed distributed job scheduler in `services/job-service`
- `spring-cloud-starter-openfeign:4.3.0` & `spring-boot-starter-webflux` - Inter-service synchronous and reactive HTTP communication

**Infrastructure:**
- `spring-boot-starter-data-mongodb` & `mongodb:7.2.0` / `mongoose:9.6.2` - MongoDB database drivers across Java and Node services
- `spring-boot-starter-data-redis` & `redis:5.12.1` & `com.github.ben-manes.caffeine` - Distributed caching, pub/sub, and local Caffeine caching
- `org.springframework.kafka:spring-kafka` - Event-driven messaging for background event processing
- `org.postgresql:postgresql` - Relational storage for Flowable BPMN engine tables (`services/ai-agent-mcrs`)
- `spring-boot-starter-oauth2-resource-server` & `keycloak-js:26.2.3` & `jose:6.2.2` - Keycloak OIDC / JWT authentication across frontend, Java, and Node services
- `micrometer-registry-prometheus` & `spring-boot-starter-actuator` - Application monitoring, health checks, and Prometheus metrics
- `org.apache.tika:tika-core:3.2.0` - MIME type detection and document parsing (`services/develop-tool-consumer`)
- `org.modelmapper:modelmapper:3.2.2` & `zod:4.2.1` / `zod:3.25.76` - Data mapping and runtime schema validation

## Configuration

**Environment:**
- Configured via environment variables defined across `application.yml` (Java) and `src/config/env.ts` (Node.js)
- Key configuration groups:
  - MongoDB connection: `MONGODB_URI`, `MONGODB_DATABASE`
  - Redis connection: `REDIS_HOST`, `REDIS_PORT`, `REDIS_PASSWORD`, `REDIS_PREFIX`
  - Keycloak OAuth2 / OIDC: `OAUTH2_ISSUER_URI`, `KEYCLOAK_ISSUER_URI`, `KEYCLOAK_JWKS_URI`
  - PostgreSQL (Flowable): `FLOWABLE_DB_HOST`, `FLOWABLE_DB_PORT`, `FLOWABLE_DB_NAME`, `FLOWABLE_DB_USERNAME`, `FLOWABLE_DB_PASSWORD`
  - Elasticsearch Logging: `LOG_ELASTIC_BASE_URL`, `LOG_ELASTIC_ENABLED`, `LOG_ELASTIC_USERNAME`, `LOG_ELASTIC_PASSWORD`
  - Inter-service URLs: `CODEX_SDK_API_URL`, `AI_AGENT_MCRS_URL`, `BINANCE_USDM_BASE_URL`

**Build:**
- Java: `pom.xml` in root submodule folders; uses Maven Compiler Plugin (Java 21 target)
- Frontend: `web/dev-tool-web/angular.json`, `web/dev-tool-web/tsconfig.json`, `web/dev-tool-web/vite.config.ts`
- Node Services: `tsconfig.json`, `tsoa.json` (Codex OpenAPI generation)
- Git Submodules: `.gitmodules` orchestrating all 10 independent module repositories

## Platform Requirements

**Development:**
- OpenJDK 21+
- Node.js 20+ (LTS) & npm 10+
- Maven 3.9+
- Docker & Docker Compose or local Kubernetes for dependencies (MongoDB, Redis, PostgreSQL, Kafka, Keycloak, Elasticsearch)
- Playwright browsers installed (`npx playwright install`)

**Production:**
- Kubernetes Cluster (managed via Rancher, Helm 3, Longhorn storage, NGINX Ingress Controller)
- Containerized deployment using Docker images built per microservice
- Backup and recovery managed via Velero with Cloudflare R2 object storage

---

*Stack analysis: 2026-09-05*
