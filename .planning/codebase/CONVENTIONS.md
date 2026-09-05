# Coding Conventions

**Analysis Date:** 2026-09-05

## Naming Patterns

**Files:**
- Angular Components/Services/Guards: kebab-case with type suffix: `src/app/features/account-management/pages/account-list/account-list.component.ts`, `src/app/features/account-management/services/account.service.ts`, `src/app/features/service-management/guards/service-management-unsaved-changes.guard.ts`.
- Angular i18n Feature Files: kebab-case with `.i18n.json` suffix: `src/app/core/i18n/features/account-management.i18n.json`, `src/app/core/i18n/features/workflow-studio.i18n.json`.
- Java Classes: UpperCamelCase matching Spring Boot standard stereotypes: `AccountService.java`, `AccountStorage.java`, `AccountEntity.java`, `AccountController.java`.
- Java DTOs / Requests / Responses: UpperCamelCase with descriptive suffixes: `AccountCreateDto.java`, `AccountUpdateDto.java`, `AccountResponse.java`, `WorkflowAdminUpsertRequest.java`.
- Subproject & Module directories: kebab-case across monorepo: `services/ai-agent-mcrs`, `libs/develop-tool-core-lib`, `web/dev-tool-web`.

**Functions & Methods:**
- TypeScript / Angular: camelCase action-first names: `getPage()`, `getById()`, `create()`, `update()`, `delete()`, `handleUnauthorized()`, `translateContent()`.
- Java: camelCase verb-noun naming: `findPageWithFilter()`, `findById()`, `create()`, `save()`, `mapToResponse()`, `getRequestUserId()`.

**Variables & Properties:**
- TypeScript: camelCase for local variables, properties, signals, and computed signals: `baseUrl`, `httpParams`, `dirty`, `workflow`, `saving`.
- Java: camelCase for instance variables and method arguments: `storage`, `mapperUtil`, `accountEntity`, `pageable`.
- Constants: UPPER_SNAKE_CASE in TypeScript and Java: `STORAGE_KEY`, `DEFAULT_VIEWPORT`, `USER_ID`.

**Types & Interfaces:**
- TypeScript: PascalCase for types, interfaces, and enums: `TableConfig<T>`, `ActionToolbarAction`, `FilterPanelField`, `AppLanguage`, `WorkflowEditorSnapshot`, `WorkflowDetail`.
- Java: PascalCase for classes, records, and enum types: `BusinessErrorCode`, `Status`, `WorkflowDefinitionEntity`, `WorkflowVersionStatus`.

## Code Style

**Formatting:**
- Frontend: Prettier (`web/dev-tool-web/package.json`) configured with `printWidth: 100`, `singleQuote: true`, Angular HTML parser overrides.
- Backend: Java standard with 2 or 4 spaces indentation, UTF-8 No BOM mandatory (`docs/note/be-note.md`).

**Linting:**
- Frontend: ESLint Flat Config (`web/dev-tool-web/eslint.config.mjs`) extending `@eslint/js`, `typescript-eslint`, and `angular-eslint`.
- Strict architecture boundary rules in `web/dev-tool-web/eslint.config.mjs`:
  - Shared UI (`src/app/shared/**/*.ts`) is forbidden from importing `@features/**`, `@core/auth/**`, and `@core/http/**`.
  - Type imports enforced in shared modules (`@typescript-eslint/consistent-type-imports`).
- Backend: Maven compiler flags targeting Java 21 (`services/ai-agent-mcrs/pom.xml`, `libs/develop-tool-core-lib/pom.xml`).

## Import Organization

**Order:**
1. Angular framework and standard Java/Node libraries (`@angular/core`, `@angular/common/http`, `java.util.*`, `org.springframework.*`).
2. Third-party packages (`rxjs`, `org.flowable.*`, `bpmn-js`, `keycloak-js`).
3. Core/Shared library aliases (`@core/http/*`, `@core/auth/*`, `@shared/*`, `vn.devTool.core.*`).
4. Feature-level local imports (`../models/*`, `./workflow-studio.model`).

**Path Aliases:**
- Defined in `web/dev-tool-web/tsconfig.json`:
  - `@core/*` -> `src/app/core/*`
  - `@shared/*` -> `src/app/shared/*`
  - `@features/*` -> `src/app/features/*`
  - `@env/*` -> `src/enviroment/*`

## Error Handling

**Patterns:**
- Frontend:
  - Centralized interceptor error interception in `web/dev-tool-web/src/app/core/http/auth.interceptor.ts`.
  - Toast notifications display server error messages (`errorMessage`) extracted from 400 bad request responses rather than hardcoded text (`MEMORY.md`).
- Backend:
  - Canonical `BusinessException` throwing with standardized error codes: `throw new BusinessException(BusinessErrorCode.DATA_NOT_FOUND)`.
  - Service tasks in Flowable BPMN must assign `aiStatus = FAILED`, `finalOutcome = FAIL` and persist `errorMessage` or throw `BpmnError` (`docs/note/be-note.md`).

## Logging

**Framework:**
- Log4j2 + SLF4J (`libs/develop-tool-core-lib/pom.xml`, `services/ai-agent-mcrs/pom.xml`).

**Patterns:**
- Logging structured context using `requestFilter.get()` centralized context rather than raw `MDC.get()` (`MEMORY.md`).
- Logging contract tests verify configuration via `services/ai-agent-mcrs/src/test/java/com/lamld/aiAgent/shared/infrastructure/LoggingConfigurationContractTest.java`.

## Comments

**When to Comment:**
- Use comments to clarify BPMN execution semantics, complex regex/data transformations, or configuration contracts.
- Document reasons for deliberate simplifications with ponytail comments when applicable.

**JSDoc/TSDoc:**
- Used for shared interface declarations and public utility functions in `web/dev-tool-web/src/app/shared/`.

## Function Design

**Size:**
- Single Responsibility: Keep controller actions, service methods, and component handlers small and focused on orchestration.

**Parameters:**
- Frontend: Use typed options/request objects (`AccountQueryParams`, `WorkflowUpsertPayload`).
- Backend: Use Spring Pageable (`Pageable pageable`) and explicit typed DTOs (`AccountCreateDto`, `WorkflowAdminUpsertRequest`).

**Return Values:**
- Frontend: Observable wrappers of `BaseResponse<T>` or direct unpacked `T` (`Observable<BasePageResponse<AccountItem>>`).
- Backend: Direct Response DTOs or Spring Page containers (`AccountResponse`, `Page<AccountResponse>`).

## Module Design

**Exports:**
- Frontend Shared Module: Explicit separation of public components (`SHARED_UI_COMPONENTS` exported by `web/dev-tool-web/src/app/shared/shared.module.ts`) versus internal renderers (`SHARED_INTERNAL_UI_COMPONENTS` verified by `shared-module-public-api.spec.ts`).
- Shared UI Rule: 100% shared wrapper components (`app-page-shell`, `app-action-toolbar`, `app-filter-panel`, `app-table`, `app-drawer`, `app-dialog`, `app-button`, `app-copyable-text`). Direct use of raw 3rd-party UI primitives or raw HTML tables is forbidden.
- Backend Architecture: 3-tier structure (`Controller` -> `Service` (extends `BaseService`) -> `Storage` -> `MongoTemplate` / `Repository`).

---

*Convention analysis: 2026-09-05*
