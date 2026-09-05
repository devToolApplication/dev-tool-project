# Codebase Concerns

**Analysis Date:** 2026-09-05

## Tech Debt

**Flowable Engine and AI Task Execution Decoupling:**
- Issue: `SubmitAiTaskDelegate` synchronously calls external `CodexSdkFeignClient` with timeouts up to 1 hour (`FEIGN_READ_TIMEOUT: 3600000`). While executing, it holds Flowable thread pool resources and executes synchronous HTTP blocking calls.
- Files: `services/ai-agent-mcrs/src/main/java/com/lamld/aiAgent/modules/workflowprocess/infrastructure/flowable/delegate/SubmitAiTaskDelegate.java`, `services/ai-agent-mcrs/src/main/resources/application.yml`
- Impact: High latency or long-running AI tasks can exhaust HTTP and engine execution threads, risking thread starvation under concurrent workflow triggers.
- Fix approach: Adopt asynchronous callback execution with Flowable intermediate catch events or async message events rather than holding synchronous long-polling HTTP Feign client connections.

**Temporary Plugin Runtime Clones in Codex Service:**
- Issue: `services/codex-sdk-service/agent-runtime/*/codex/.tmp/` contains multiple ephemeral plugin clones and cached directories checked into disk (`plugins-clone-*`).
- Files: `services/codex-sdk-service/agent-runtime/`
- Impact: Substantial disk space usage, slow search operations, potential stale cache state when packaging and syncing agent home directories.
- Fix approach: Configure `.gitignore` to explicitly ignore `.tmp/` inside `agent-runtime/` and add clean-up lifecycle hooks in agent catalog packaging routines (`services/codex-sdk-service/src/modules/agent-catalog/agentHomePackaging.ts`).

**Extensive Monolithic Components in Workflow Studio & Shared UI:**
- Issue: `flowable-properties-provider.ts` (>1580 lines), `service-management.config.ts` (>1330 lines), and `expression.engine.ts` (>930 lines) concentrate high cyclomatic complexity and UI configuration in single files.
- Files: `web/dev-tool-web/src/app/features/workflow-studio/bpmn/flowable/flowable-properties-provider.ts`, `web/dev-tool-web/src/app/features/service-management/model/service-management.config.ts`, `web/dev-tool-web/src/app/shared/ui/patterns/form-input/utils/expression.engine.ts`
- Impact: Elevated risk of regressions when modifying properties panel bindings or expression evaluation rules.
- Fix approach: Refactor property providers into modular node-specific handlers (`UserTaskPropertiesProvider`, `ServiceTaskPropertiesProvider`, `GatewayPropertiesProvider`).

## Known Bugs

**Synchronous Fallback Execution in Facebook Discovery:**
- Symptoms: When Facebook candidate discovery via primary agent fails or timeouts, fallback heuristic logic runs synchronously within the request context.
- Files: `services/codex-sdk-service/src/modules/ai-task/facebookCandidateDiscoveryFallback.ts`
- Trigger: Heavy rate limiting or non-standard HTML responses from Facebook endpoints.
- Workaround: Fallback defaults to hardcoded parser logic, but can cause intermittent HTTP timeouts if responses are delayed.

## Security Considerations

**Account Credential Enrichment in Workflow Delegate:**
- Risk: `SubmitAiTaskDelegate` extracts plaintext credentials (`CTX_ACCOUNT_USERNAME`, `CTX_ACCOUNT_PASSWORD`) from `AccountService` and embeds them into `requestContext` sent over HTTP to Codex SDK service.
- Files: `services/ai-agent-mcrs/src/main/java/com/lamld/aiAgent/modules/workflowprocess/infrastructure/flowable/delegate/SubmitAiTaskDelegate.java`
- Current mitigation: Transmission occurs within internal cluster network or localhost.
- Recommendations: Ensure strict TLS / mutual auth between microservices, vault secret reference resolution at point of use in agent runtime, and mask sensitive credentials in request logs and audit trails.

**Submodule Local Drift and Tracking:**
- Risk: Git submodules (`tools/agent-skill`, `services/ai-agent-mcrs`, `services/codex-sdk-service`, `web/dev-tool-web`) frequently track detached HEAD states or uncommitted local changes across development sessions.
- Files: `.gitmodules`, `push-all-submodules.sh`, `push-all-submodules.bat`
- Current mitigation: Custom push scripts sync submodules manually.
- Recommendations: Enforce strict CI submodule pointer validation gates to prevent breaking inter-service API contracts during deployment.

## Performance Bottlenecks

**Backtest Calculation Execution in Trade Bot:**
- Problem: Backtest execution processes tick and candle arrays in memory with intensive iterative calculations (`BacktestService`, `FastBacktestSummaryService`).
- Files: `services/trade-bot-mcrs/src/main/java/com/lamld/tradebotmcrs/modules/backtest/application/BacktestService.java`, `services/trade-bot-mcrs/src/main/java/com/lamld/tradebotmcrs/modules/sandbox/application/FastBacktestSummaryService.java`
- Cause: Complex rule evaluations (`ExpressionRuleLogic.java`) executing per candle across large historical windows.
- Improvement path: Leverage batch vectorized calculations or pre-aggregated indicator cache stored in Redis.

**Elasticsearch Log Queue Overflow under Burst Load:**
- Problem: `ElasticsearchLogAppender` uses an in-memory `ArrayBlockingQueue`. When logging bursts exceed queue capacity, events are dropped.
- Files: `libs/develop-tool-core-lib/src/main/java/vn/devTool/core/logging/ElasticsearchLogAppender.java`
- Cause: Synchronous retry HTTP connection inside `drainLoop()` can stall if Elasticsearch cluster latency spikes.
- Improvement path: Implement non-blocking backpressure or delegate log aggregation to stdout/Logstash/FluentBit sidecar.

## Fragile Areas

**BPMN XML Serialization and Moddle Extensions:**
- Files: `web/dev-tool-web/src/app/features/workflow-studio/bpmn/flowable/flowable-service-task-mapper.ts`, `web/dev-tool-web/src/app/features/workflow-studio/bpmn/flowable/flowable-properties-provider.ts`
- Why fragile: Tight coupling with `bpmn-js` internal moddle definitions (`flowable:field`, `flowable:string`, `flowable:expression`). Any schema mismatch between Angular BPMN canvas and Flowable engine XML parser causes execution failure or dropped parameters.
- Safe modification: Validate generated BPMN XML against standard Flowable schema in contract tests before saving versions.
- Test coverage: Partially covered by `WorkflowVersionJsonPersistenceContractTest.java` and `FlowableRealEngineTest.java`.

**Multi-Repository Submodule Dependencies:**
- Files: `.gitmodules`, `libs/develop-tool-core-lib`, `libs/develop-tool-nodejs-core-lib`
- Why fragile: Core shared libraries are linked as submodules. Upstream changes in `BaseService` or common response DTOs require synchronized builds across 5+ independent services.
- Safe modification: Version shared libraries via local Nexus/Maven/NPM registries rather than direct Git submodule checkouts.
- Test coverage: Gaps in end-to-end integration across all submodules simultaneously.

## Scaling Limits

**Codex CLI Subprocess Concurrency:**
- Current capacity: Limited by host CPU/memory per concurrent `CliProcessRunner` spawn instance.
- Limit: Spawning multiple parallel headless browsers or AI agent CLI processes exhausts OS process limits and memory.
- Scaling path: Distribute agent execution across containerized worker pods (Kubernetes Job / Celery / BullMQ queue) instead of single-instance Node.js supervisor.

## Dependencies at Risk

**OpenFeign Extended Timeout Configuration:**
- Risk: Global Feign read timeout configured to 3600 seconds (`readTimeout: 3600000`).
- Impact: Network partitions or unresponsive downstream services can cause connection leaks and hung worker threads.
- Migration plan: Move long-running tasks to asynchronous job queuing and reduce HTTP Feign timeouts to maximum 30–60 seconds.

## Missing Critical Features

**Distributed Tracing Across Microservices:**
- Problem: Lack of unified distributed tracing (OpenTelemetry / Jaeger trace propagation) across Angular FE -> Spring Boot -> Node.js Codex SDK -> Flowable Engine.
- Blocks: Rapid root-cause diagnosis for failed multi-step agent workflows spanning multiple service boundaries.

## Test Coverage Gaps

**Microservice Backend Services Without Complete Service Tests:**
- What's not tested: `services/file-mcrs` (0 unit tests) and `services/trade-bot-mcrs` (1 test for ~390 classes).
- Files: `services/file-mcrs/src/main/java/`, `services/trade-bot-mcrs/src/main/java/`
- Risk: Business logic breakages, unhandled database exceptions, and regression during refactoring.
- Priority: High

**End-to-End Workflow Execution Test Gaps:**
- What's not tested: Complex BPMN gateway branches with manual checkpoints (`NEED_MANUAL_ACTION`) integrated with real frontend user task actions.
- Files: `web/dev-tool-web/src/app/features/workflow-studio/`, `services/ai-agent-mcrs/src/main/java/com/lamld/aiAgent/modules/workflowprocess/`
- Risk: Inconsistent UI state when resuming paused executions.
- Priority: Medium

---

*Concerns audit: 2026-09-05*
