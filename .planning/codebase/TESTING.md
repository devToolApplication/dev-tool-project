# Testing Patterns

**Analysis Date:** 2026-09-05

## Test Framework

**Runner:**
- Frontend: Vitest `^4.0.8` (configured in `web/dev-tool-web/package.json`) & Playwright Test `^1.60.0` (configured in `web/dev-tool-web/playwright.config.ts`).
- Backend: JUnit 5 (`junit-jupiter`), Spring Boot Test Starter (`spring-boot-starter-test` on Spring Boot 3.5.0, Java 21) via Maven surefire (`services/ai-agent-mcrs/pom.xml`, `libs/develop-tool-core-lib/pom.xml`).

**Assertion Library:**
- Frontend: Vitest standard assertions (`expect()`) & Playwright assertions (`expect(page)...`).
- Backend: JUnit Jupiter assertions (`org.junit.jupiter.api.Assertions.*`) & Mockito verification.

**Run Commands:**
```bash
# Frontend Unit & Integration Tests
npm --prefix web/dev-tool-web test                  # Run unit tests via Vitest
npm --prefix web/dev-tool-web run test-storybook    # Run storybook interaction tests
npm --prefix web/dev-tool-web run e2e               # Run local Playwright E2E tests

# Backend Unit & Integration Tests
./mvnw test -f services/ai-agent-mcrs/pom.xml       # Run ai-agent-mcrs tests
./mvnw test -f libs/develop-tool-core-lib/pom.xml   # Run core library tests
```

## Test File Organization

**Location:**
- Frontend: Co-located next to implementation files under `web/dev-tool-web/src/app/**/*.spec.ts` for unit/integration tests; dedicated `web/dev-tool-web/e2e/*.spec.ts` for Playwright end-to-end suites.
- Backend: Standard Maven test directory structure under `services/{service-name}/src/test/java/`.

**Naming:**
- Frontend unit tests: `{name}.spec.ts` (e.g., `account.service.spec.ts`, `workflow-editor.store.spec.ts`).
- Frontend E2E tests: `{feature}.spec.ts` (e.g., `workflow-runs.spec.ts`, `flow-builder-canvas.spec.ts`).
- Backend unit & contract tests: `*Test.java` (e.g., `AccountServiceTest.java`, `WorkflowAdminServiceTest.java`, `FlowableRealEngineTest.java`).

**Structure:**
```
web/dev-tool-web/
├── src/app/features/{feature}/
│   ├── pages/{page}.component.ts
│   ├── pages/{page}.component.spec.ts
│   ├── services/{service}.service.ts
│   └── services/{service}.service.spec.ts
└── e2e/
    └── {feature-scenario}.spec.ts

services/ai-agent-mcrs/src/
├── main/java/com/lamld/aiAgent/modules/{module}/...
└── test/java/com/lamld/aiAgent/modules/{module}/
    ├── application/{Module}ServiceTest.java
    ├── api/{Module}ControllerContractTest.java
    └── integration/{Module}IntegrationTest.java
```

## Test Structure

**Suite Organization (Frontend):**
```typescript
import { TestBed } from '@angular/core/testing';
import { provideHttpClient } from '@angular/common/http';
import { HttpTestingController, provideHttpClientTesting } from '@angular/common/http/testing';
import { AccountService } from './account.service';

describe('AccountService', () => {
  let service: AccountService;
  let httpMock: HttpTestingController;

  beforeEach(() => {
    TestBed.configureTestingModule({
      providers: [
        AccountService,
        provideHttpClient(),
        provideHttpClientTesting(),
      ],
    });
    service = TestBed.inject(AccountService);
    httpMock = TestBed.inject(HttpTestingController);
  });

  afterEach(() => {
    httpMock.verify();
  });

  it('creates new account', () => {
    const payload = { name: 'Dev', type: 'OPENAI', username: 'dev@test.com', password: 'pwd' };
    service.create(payload).subscribe((res) => {
      expect(res.id).toBe('acc-1');
    });

    const req = httpMock.expectOne((r) => r.url.endsWith('/accounts'));
    expect(req.request.method).toBe('POST');
    req.flush({ data: { id: 'acc-1', ...payload } });
  });
});
```

**Suite Organization (Backend):**
```java
@ExtendWith(MockitoExtension.class)
class AccountServiceTest {
  private AccountStorage storage;
  private AccountService service;

  @BeforeEach
  void setUp() {
    storage = mock(AccountStorage.class);
    MapperUtil mapperUtil = new MapperUtil(new ModelMapper(), new ObjectMapper());
    service = new AccountService(storage);
    ReflectionTestUtils.setField(service, "mapperUtil", mapperUtil);
  }

  @Test
  void getById_notFound_shouldThrowBusinessException() {
    when(storage.findById("non-existent")).thenReturn(Optional.empty());
    assertThrows(BusinessException.class, () -> service.getById("non-existent"));
  }
}
```

## Mocking

**Framework:**
- Frontend: Vitest mocks / Angular `HttpTestingController`.
- Backend: Mockito (`mockito-core`, `mockito-junit-jupiter`).

**Patterns:**
- Mocking external dependencies and storage layer while keeping business logic and mapper utilities real:
```java
when(storage.save(any(AccountEntity.class))).thenAnswer(invocation -> invocation.getArgument(0));
```

**What to Mock:**
- Database storage repositories (`AccountStorage`, `WorkflowDocumentLookup`).
- Remote HTTP services and Feign clients (`CodexSdkFeignClient`).
- External engine subsystems when testing service logic (`ProcessEngine`, `RepositoryService`).

**What NOT to Mock:**
- Data mappers (`MapperUtil` instantiated with real `ModelMapper` and `ObjectMapper`).
- Core business rules, validation logic, and state transitions in Angular signals/stores.
- Actual BPMN execution in engine integration suites (`FlowableRealEngineTest.java`).

## Fixtures and Factories

**Test Data:**
- Real BPMN 2.0 XML constants embedded in test fixtures (`WorkflowAdminServiceTest.java`, `workflow-runs.spec.ts`).
- Strongly typed test fixtures constructed in `beforeEach` or factory helper methods (`loadSampleWorkflow()`, `definition()`, `version()`).

**Location:**
- Embedded in test files or located in `web/dev-tool-web/src/app/shared/testing/`.

## Coverage

**Requirements:**
- Mandatory 100% pass gate on `npm test` and `mvn test` prior to handoff (`docs/note/fe-note.md`, `docs/note/be-note.md`).
- Local Playwright E2E verification required for UI features touching canvas/drawer/modal interactions.

**View Coverage:**
```bash
npm --prefix web/dev-tool-web test -- --coverage
mvn test -f services/ai-agent-mcrs/pom.xml jacoco:report
```

## Test Types

**Unit Tests:**
- Angular Signals & Stores (`WorkflowEditorStore`), Shared UI Components, Angular Services (`AccountService`), Backend Services (`AccountService`, `WorkflowAdminService`).

**Integration Tests:**
- Flowable process engine lifecycle (`FlowableRealEngineTest`, `FlowableRealMultiStepTest`), Feign/WebClient integration with embedded HTTP server (`CodexSdkIntegrationTest`), Shared module public API boundary checks (`shared-module-public-api.spec.ts`).

**E2E Tests:**
- Playwright tests under `web/dev-tool-web/e2e/` testing full user flows against running dev server and Storybook (`workflow-runs.spec.ts`, `flow-builder-canvas.spec.ts`).

## Common Patterns

**Async Testing (Frontend):**
```typescript
it('verifies async stream or http response', () => {
  service.getPage({ page: 0, size: 10 }).subscribe((res) => {
    expect(res.data.length).toBeGreaterThan(0);
  });
  const req = httpMock.expectOne((r) => r.url.includes('/page'));
  req.flush({ data: { data: [{ id: '1' }] } });
});
```

**Error Testing (Backend):**
```java
@Test
void deleteDoesNotResolveWorkflowByName() {
  when(documentLookup.findDefinitionById("demo-check")).thenReturn(Optional.empty());

  assertThrows(BusinessException.class, () ->
    service.delete("demo-check")
  );

  verify(definitionRepository, never()).findByName("demo-check");
}
```

---

*Testing analysis: 2026-09-05*
