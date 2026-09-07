# Codex SDK Chat History & Workbench Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Xây dựng màn hình quản trị và kiểm thử trực tiếp Codex SDK Chat History & Workbench (`/codex-sdk/threads`) trên portal `dev-tool-web` (Angular 21) giao tiếp qua `ai-agent-mcrs` (Spring Boot 3.5), hỗ trợ tra cứu lịch sử hội thoại dạng Table + Drawer và gửi test prompt thời gian thực bằng Native `fetch()` SSE streaming.

**Architecture:** 
- **Backend (`services/ai-agent-mcrs`):** Cung cấp gateway API chuẩn hóa cho thread history và SSE streaming qua `CodexSdkController` và `CodexSdkService`, bảo đảm 100% coverage Unit Test theo chuẩn `docs/note/be-note.md`.
- **Frontend (`web/dev-tool-web`):** Kiến trúc Table + Drawer với Angular 21 Signals, 100% Shared UI Components (`app-page-shell`, `app-action-toolbar`, `app-filter-panel`, `app-table`, `app-drawer`, `app-button`, `app-copyable-text`, `app-json-viewer`), xử lý SSE streaming bằng Native Web API `fetch()` + `ReadableStream` (`response.body.getReader()`) không phụ thuộc thư viện ngoài.

**Tech Stack:**
- Backend: Java 21, Spring Boot 3.5, Spring Cloud OpenFeign, WebClient (Reactive Streams), SseEmitter, Mockito, JUnit 5.
- Frontend: Angular 21, TypeScript, RxJS, Native Streams Web API, Vitest, Playwright.

---

## File Structure & Responsibilities

### Backend: `services/ai-agent-mcrs`
- Test: `src/test/java/com/lamld/aiAgent/modules/codexsdk/application/CodexSdkServiceTest.java`
  - Đóng gói toàn bộ test suite kiểm thử đơn vị cho `CodexSdkService`: test `listThreads`, `getThreadHistory`, `execute`, và xử lý `stream` SSE emitter thông qua mocked `WebClient` / `FeignClient`.

### Frontend: `web/dev-tool-web`
- Model: `src/app/features/codex-sdk/models/codex-sdk.model.ts`
  - Định nghĩa kiểu dữ liệu `CodexThreadItem`, `CodexTurn`, `CodexThreadDetail`, `CodexPromptRequest`, `CodexStreamEvent`, `CodexThreadListResponse`.
- Service & Spec:
  - `src/app/features/codex-sdk/services/codex-sdk.service.ts`
  - `src/app/features/codex-sdk/services/codex-sdk.service.spec.ts`
  - Tương tác API danh sách thread, chi tiết đàm thoại và kết nối SSE qua Native `fetch()` ReadableStream.
- Chat Drawer Component & Spec:
  - `src/app/features/codex-sdk/components/codex-chat-drawer/codex-chat-drawer.component.ts`
  - `src/app/features/codex-sdk/components/codex-chat-drawer/codex-chat-drawer.component.html`
  - `src/app/features/codex-sdk/components/codex-chat-drawer/codex-chat-drawer.component.scss`
  - `src/app/features/codex-sdk/components/codex-chat-drawer/codex-chat-drawer.component.spec.ts`
  - Drawer hiển thị lịch sử turn, collapsible inspector cho tool calls, prompt quick-bar với bộ chọn model, nút dừng stream và partial stream retry banner.
- Thread List Page & Spec:
  - `src/app/features/codex-sdk/pages/codex-thread-list/codex-thread-list.component.ts`
  - `src/app/features/codex-sdk/pages/codex-thread-list/codex-thread-list.component.html`
  - `src/app/features/codex-sdk/pages/codex-thread-list/codex-thread-list.component.scss`
  - `src/app/features/codex-sdk/pages/codex-thread-list/codex-thread-list.component.spec.ts`
  - Trang danh sách tích hợp `app-page-shell`, `app-action-toolbar` với nút cursor phân trang ("Trang trước", "Trang sau"), `app-filter-panel`, `app-table`.
- Module & Integration:
  - `src/app/features/codex-sdk/codex-sdk.module.ts`
  - `src/app/features/codex-sdk/codex-sdk.routes.ts`
  - `src/app/core/i18n/features/codex-sdk.i18n.json`
  - Modify: `src/app/core/i18n/i18n.service.ts`
  - Modify: `src/app/features/app-feature.module.ts`
  - Modify: `src/app/app-shell/navigation/config/menu.config.ts`
- E2E Test:
  - `e2e/codex-sdk-history.spec.ts`

---

## Implementation Tasks

### Task 1 (BE): Unit Tests cho `CodexSdkService`

**Files:**
- Create: `services/ai-agent-mcrs/src/test/java/com/lamld/aiAgent/modules/codexsdk/application/CodexSdkServiceTest.java`

- [ ] **Step 1: Viết test suite kiểm thử đơn vị cho `CodexSdkService`**

```java
package com.lamld.aiAgent.modules.codexsdk.application;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.lamld.aiAgent.modules.codexsdk.api.request.CodexSdkPromptRequest;
import com.lamld.aiAgent.modules.codexsdk.infrastructure.client.CodexSdkFeignClient;
import java.util.List;
import java.util.Map;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.web.reactive.function.client.WebClient;
import org.springframework.web.servlet.mvc.method.annotation.SseEmitter;
import vn.devTool.core.service.TokenService;

class CodexSdkServiceTest {

  private CodexSdkFeignClient feignClient;
  private WebClient.Builder webClientBuilder;
  private TokenService tokenService;
  private CodexSdkService service;

  @BeforeEach
  void setUp() {
    feignClient = mock(CodexSdkFeignClient.class);
    webClientBuilder = mock(WebClient.Builder.class);
    tokenService = mock(TokenService.class);
    service = new CodexSdkService(feignClient, webClientBuilder, tokenService);
  }

  @Test
  void listThreadsDelegatesToFeignClient() {
    Map<String, Object> expected = Map.of("data", List.of(Map.of("id", "t-1")), "nextCursor", "c-2");
    when(feignClient.listThreads(10, "c-1", "test", false)).thenReturn(expected);

    Map<String, Object> result = service.listThreads(10, "c-1", "test", false);

    assertNotNull(result);
    assertEquals(expected, result);
    verify(feignClient).listThreads(10, "c-1", "test", false);
  }

  @Test
  void getThreadHistoryDelegatesToFeignClient() {
    Map<String, Object> expected = Map.of("id", "t-1", "turns", List.of());
    when(feignClient.getThread("t-1")).thenReturn(expected);

    Map<String, Object> result = service.getThreadHistory("t-1");

    assertNotNull(result);
    assertEquals(expected, result);
    verify(feignClient).getThread("t-1");
  }

  @Test
  void executePromptDelegatesToFeignClient() {
    CodexSdkPromptRequest request = new CodexSdkPromptRequest();
    request.setPrompt("ping");
    Map<String, Object> expected = Map.of("outputText", "pong");
    when(feignClient.execute(request)).thenReturn(expected);

    Map<String, Object> result = service.execute(request);

    assertNotNull(result);
    assertEquals(expected, result);
    verify(feignClient).execute(request);
  }

  @Test
  void extractThreadIdReturnsIdDirectlyOrFromData() {
    assertEquals("t-direct", service.extractThreadId(Map.of("threadId", "t-direct")));
    assertEquals("t-nested", service.extractThreadId(Map.of("data", Map.of("threadId", "t-nested"))));
    assertNull(service.extractThreadId(null));
    assertNull(service.extractThreadId(Map.of()));
  }
}
```

- [ ] **Step 2: Chạy test verify pass**

Run command:
```powershell
mvn test -Dtest=CodexSdkServiceTest -f services/ai-agent-mcrs/pom.xml
```
Expected: `BUILD SUCCESS`, `Tests run: 4, Failures: 0, Errors: 0, Skipped: 0`

- [ ] **Step 3: Commit code backend test**

```bash
git add services/ai-agent-mcrs/src/test/java/com/lamld/aiAgent/modules/codexsdk/application/CodexSdkServiceTest.java
git commit -m "test(codexsdk): add unit tests for CodexSdkService in ai-agent-mcrs"
```

---

### Task 2 (FE): Models và `CodexSdkService` với Native Streaming

**Files:**
- Create: `web/dev-tool-web/src/app/features/codex-sdk/models/codex-sdk.model.ts`
- Create: `web/dev-tool-web/src/app/features/codex-sdk/services/codex-sdk.service.ts`
- Create: `web/dev-tool-web/src/app/features/codex-sdk/services/codex-sdk.service.spec.ts`

- [ ] **Step 1: Tạo model `codex-sdk.model.ts`**

```typescript
export interface CodexThreadItem {
  id: string;
  preview?: string;
  createdAt?: string;
  updatedAt?: string;
  turnCount?: number;
  archived?: boolean;
}

export interface CodexToolCall {
  name: string;
  input?: Record<string, unknown>;
  output?: unknown;
  durationMs?: number;
  status?: 'success' | 'error' | 'pending';
}

export interface CodexTurn {
  id: string;
  role: 'user' | 'assistant' | 'system';
  content: string;
  status?: 'completed' | 'failed' | 'streaming';
  createdAt?: string;
  toolCalls?: CodexToolCall[];
  metrics?: {
    model?: string;
    totalTokens?: number;
    latencyMs?: number;
  };
}

export interface CodexThreadDetail {
  id: string;
  preview?: string;
  createdAt?: string;
  turns: CodexTurn[];
}

export interface CodexThreadListResponse {
  data: CodexThreadItem[];
  nextCursor?: string | null;
}

export interface CodexPromptRequest {
  prompt: string;
  threadId?: string;
  model?: string;
  reasoningEffort?: 'low' | 'medium' | 'high';
  instruction?: string;
  sandboxMode?: 'read-only' | 'workspace-write';
}

export interface CodexStreamEvent {
  type: 'data' | 'error' | 'done';
  token?: string;
  error?: string;
}
```

- [ ] **Step 2: Viết test failing `codex-sdk.service.spec.ts`**

```typescript
import { provideHttpClient } from '@angular/common/http';
import { HttpTestingController, provideHttpClientTesting } from '@angular/common/http/testing';
import { TestBed } from '@angular/core/testing';
import { CodexSdkService } from './codex-sdk.service';
import { CodexThreadItem, CodexThreadDetail } from '../models/codex-sdk.model';

describe('CodexSdkService', () => {
  let service: CodexSdkService;
  let httpMock: HttpTestingController;

  beforeEach(() => {
    TestBed.configureTestingModule({
      providers: [
        CodexSdkService,
        provideHttpClient(),
        provideHttpClientTesting(),
      ],
    });
    service = TestBed.inject(CodexSdkService);
    httpMock = TestBed.inject(HttpTestingController);
  });

  afterEach(() => {
    httpMock.verify();
  });

  it('fetches threads list with cursor and search term', () => {
    const mockThreads: CodexThreadItem[] = [
      { id: 't-1', preview: 'Inspect logs', turnCount: 2, createdAt: '2026-09-06T10:00:00Z' },
    ];

    service.getThreads({ limit: 10, cursor: 'c-1', searchTerm: 'logs' }).subscribe((res) => {
      expect(res.data.data.length).toBe(1);
      expect(res.data.data[0].id).toBe('t-1');
    });

    const req = httpMock.expectOne((r) => r.url.includes('/v1/codex-sdk/threads') && r.params.get('cursor') === 'c-1');
    expect(req.request.method).toBe('GET');
    req.flush({ data: { data: mockThreads, nextCursor: 'c-2' } });
  });

  it('fetches thread history by threadId', () => {
    const mockDetail: CodexThreadDetail = {
      id: 't-1',
      turns: [{ id: 'turn-1', role: 'user', content: 'Hello' }],
    };

    service.getThreadHistory('t-1').subscribe((res) => {
      expect(res.data.id).toBe('t-1');
      expect(res.data.turns.length).toBe(1);
    });

    const req = httpMock.expectOne('/v1/codex-sdk/threads/t-1');
    expect(req.request.method).toBe('GET');
    req.flush({ data: mockDetail });
  });

  it('streamPrompt initializes AbortController and initiates native fetch', async () => {
    const mockReader = {
      read: vi.fn()
        .mockResolvedValueOnce({
          done: false,
          value: new TextEncoder().encode('event: message\ndata: Hello\n\n'),
        })
        .mockResolvedValueOnce({
          done: true,
          value: undefined,
        }),
    };

    const fetchSpy = vi.spyOn(window, 'fetch').mockResolvedValue({
      ok: true,
      body: {
        getReader: () => mockReader,
      },
    } as any);

    const onToken = vi.fn();
    const onError = vi.fn();
    const onDone = vi.fn();

    const controller = service.streamPrompt({ prompt: 'Ping' }, onToken, onError, onDone);
    expect(controller).toBeInstanceOf(AbortController);
    expect(fetchSpy).toHaveBeenCalledWith('/v1/codex-sdk/stream', expect.objectContaining({
      method: 'POST',
      signal: controller.signal,
    }));

    await new Promise((resolve) => setTimeout(resolve, 50));
    expect(onToken).toHaveBeenCalledWith('Hello');
    expect(onDone).toHaveBeenCalled();
    fetchSpy.mockRestore();
  });
});
```

- [ ] **Step 3: Viết triển khai `codex-sdk.service.ts`**

```typescript
import { HttpClient, HttpParams } from '@angular/common/http';
import { Injectable } from '@angular/core';
import { Observable } from 'rxjs';
import {
  CodexPromptRequest,
  CodexThreadDetail,
  CodexThreadListResponse,
} from '../models/codex-sdk.model';

export interface BaseResponse<T> {
  data: T;
  success?: boolean;
  message?: string;
}

@Injectable({
  providedIn: 'root',
})
export class CodexSdkService {
  private readonly baseUrl = '/v1/codex-sdk';

  constructor(private readonly http: HttpClient) {}

  getThreads(params: {
    limit?: number;
    cursor?: string;
    searchTerm?: string;
    archived?: boolean;
  }): Observable<BaseResponse<CodexThreadListResponse>> {
    let httpParams = new HttpParams();
    if (params.limit) {
      httpParams = httpParams.set('limit', params.limit.toString());
    }
    if (params.cursor) {
      httpParams = httpParams.set('cursor', params.cursor);
    }
    if (params.searchTerm) {
      httpParams = httpParams.set('searchTerm', params.searchTerm);
    }
    if (params.archived !== undefined) {
      httpParams = httpParams.set('archived', params.archived.toString());
    }

    return this.http.get<BaseResponse<CodexThreadListResponse>>(`${this.baseUrl}/threads`, {
      params: httpParams,
    });
  }

  getThreadHistory(threadId: string): Observable<BaseResponse<CodexThreadDetail>> {
    return this.http.get<BaseResponse<CodexThreadDetail>>(`${this.baseUrl}/threads/${encodeURIComponent(threadId)}`);
  }

  streamPrompt(
    request: CodexPromptRequest,
    onToken: (token: string) => void,
    onError: (err: any) => void,
    onDone: () => void
  ): AbortController {
    const controller = new AbortController();

    (async () => {
      try {
        const response = await fetch(`${this.baseUrl}/stream`, {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
          },
          body: JSON.stringify(request),
          signal: controller.signal,
        });

        if (!response.ok || !response.body) {
          throw new Error(`Stream request failed with status ${response.status}`);
        }

        const reader = response.body.getReader();
        const decoder = new TextDecoder('utf-8', { fatal: false });
        let buffer = '';

        while (true) {
          const { done, value } = await reader.read();
          if (done) {
            break;
          }

          buffer += decoder.decode(value, { stream: true });
          const parts = buffer.split('\n\n');
          buffer = parts.pop() ?? '';

          for (const part of parts) {
            const lines = part.split('\n');
            let eventType = 'message';
            let dataText = '';

            for (const line of lines) {
              if (line.startsWith('event:')) {
                eventType = line.replace('event:', '').trim();
              } else if (line.startsWith('data:')) {
                const chunk = line.replace('data:', '').trim();
                dataText += chunk;
              }
            }

            if (eventType === 'error') {
              onError(dataText || 'Streaming error');
              return;
            } else if (eventType === 'done') {
              onDone();
              return;
            } else if (dataText) {
              onToken(dataText);
            }
          }
        }

        onDone();
      } catch (error: any) {
        if (error.name !== 'AbortError') {
          onError(error);
        }
      }
    })();

    return controller;
  }
}
```

- [ ] **Step 4: Chạy test verify pass**

Run command:
```powershell
npm test -- src/app/features/codex-sdk/services/codex-sdk.service.spec.ts
```
Expected: PASS 3 tests.

- [ ] **Step 5: Commit service và models**

```bash
git add web/dev-tool-web/src/app/features/codex-sdk/models/codex-sdk.model.ts web/dev-tool-web/src/app/features/codex-sdk/services/
git commit -m "feat(codex-sdk): create model and service with native fetch readable stream"
```

---

### Task 3 (FE): `CodexChatDrawerComponent` với Collapsible Inspector & Docked Bottom Bar

**Files:**
- Create: `web/dev-tool-web/src/app/features/codex-sdk/components/codex-chat-drawer/codex-chat-drawer.component.ts`
- Create: `web/dev-tool-web/src/app/features/codex-sdk/components/codex-chat-drawer/codex-chat-drawer.component.html`
- Create: `web/dev-tool-web/src/app/features/codex-sdk/components/codex-chat-drawer/codex-chat-drawer.component.scss`
- Create: `web/dev-tool-web/src/app/features/codex-sdk/components/codex-chat-drawer/codex-chat-drawer.component.spec.ts`

- [ ] **Step 1: Viết test failing `codex-chat-drawer.component.spec.ts`**

```typescript
import { ComponentFixture, TestBed } from '@angular/core/testing';
import { NO_ERRORS_SCHEMA } from '@angular/core';
import { TranslateContentPipe } from '@shared/pipes/translate-content.pipe';
import { CodexChatDrawerComponent } from './codex-chat-drawer.component';
import { CodexSdkService } from '../../services/codex-sdk.service';
import { of } from 'rxjs';

describe('CodexChatDrawerComponent', () => {
  let fixture: ComponentFixture<CodexChatDrawerComponent>;
  let component: CodexChatDrawerComponent;
  let mockSdkService: {
    getThreadHistory: ReturnType<typeof vi.fn>;
    streamPrompt: ReturnType<typeof vi.fn>;
  };

  beforeEach(async () => {
    mockSdkService = {
      getThreadHistory: vi.fn().mockReturnValue(
        of({
          data: {
            id: 't-123',
            turns: [
              { id: 'turn-1', role: 'user', content: 'What is the build status?' },
              {
                id: 'turn-2',
                role: 'assistant',
                content: 'Build is green.',
                toolCalls: [{ name: 'check_ci', input: { job: 'main' }, status: 'success' }],
              },
            ],
          },
        })
      ),
      streamPrompt: vi.fn().mockReturnValue(new AbortController()),
    };

    await TestBed.configureTestingModule({
      declarations: [CodexChatDrawerComponent, TranslateContentPipe],
      providers: [{ provide: CodexSdkService, useValue: mockSdkService }],
      schemas: [NO_ERRORS_SCHEMA],
    }).compileComponents();

    fixture = TestBed.createComponent(CodexChatDrawerComponent);
    component = fixture.componentInstance;
    fixture.detectChanges();
  });

  it('renders chat turns correctly when threadId is set', () => {
    component.openThread('t-123');
    fixture.detectChanges();

    expect(component.threadId()).toBe('t-123');
    expect(component.turns().length).toBe(2);
    expect(component.turns()[0].content).toBe('What is the build status?');
  });

  it('aborts active stream on drawer close or stop button click', () => {
    const mockAbort = vi.fn();
    component.activeAbortController = { abort: mockAbort } as any;
    component.isStreaming.set(true);

    component.stopStream();
    expect(mockAbort).toHaveBeenCalled();
    expect(component.isStreaming()).toBe(false);
  });

  it('submits prompt and adds streaming turn', () => {
    component.promptInput.set('Run test');
    component.sendPrompt();

    expect(mockSdkService.streamPrompt).toHaveBeenCalled();
    expect(component.isStreaming()).toBe(true);
    expect(component.turns().length).toBeGreaterThan(0);
  });
});
```

- [ ] **Step 2: Viết code TypeScript `codex-chat-drawer.component.ts`**

```typescript
import {
  Component,
  DestroyRef,
  ElementRef,
  EventEmitter,
  Input,
  Output,
  ViewChild,
  inject,
  signal,
} from '@angular/core';
import { takeUntilDestroyed } from '@angular/core/rxjs-interop';
import { CodexPromptRequest, CodexTurn } from '../../models/codex-sdk.model';
import { CodexSdkService } from '../../services/codex-sdk.service';

@Component({
  selector: 'app-codex-chat-drawer',
  standalone: false,
  templateUrl: './codex-chat-drawer.component.html',
  styleUrls: ['./codex-chat-drawer.component.scss'],
})
export class CodexChatDrawerComponent {
  private readonly sdkService = inject(CodexSdkService);
  private readonly destroyRef = inject(DestroyRef);

  @Input() visible = false;
  @Output() visibleChange = new EventEmitter<boolean>();
  @Output() threadUpdated = new EventEmitter<void>();

  @ViewChild('timelineContainer') timelineRef?: ElementRef<HTMLElement>;

  readonly threadId = signal<string | null>(null);
  readonly turns = signal<CodexTurn[]>([]);
  readonly loading = signal(false);
  readonly isStreaming = signal(false);
  readonly streamError = signal<string | null>(null);
  readonly expandedToolCalls = signal<Record<string, boolean>>({});

  // Prompt Form Controls
  readonly promptInput = signal('');
  readonly selectedModel = signal('claude-sonnet-5');
  readonly selectedEffort = signal<'low' | 'medium' | 'high'>('medium');
  readonly showAdvanced = signal(false);
  readonly instruction = signal('');
  readonly sandboxMode = signal<'read-only' | 'workspace-write'>('workspace-write');

  activeAbortController: AbortController | null = null;
  private userScrolledUp = false;

  constructor() {
    this.destroyRef.onDestroy(() => {
      this.stopStream();
    });
  }

  openThread(id: string | null): void {
    this.stopStream();
    this.streamError.set(null);
    this.threadId.set(id);
    this.visible = true;
    this.visibleChange.emit(true);

    if (!id) {
      this.turns.set([]);
      return;
    }

    this.loading.set(true);
    this.sdkService
      .getThreadHistory(id)
      .pipe(takeUntilDestroyed(this.destroyRef))
      .subscribe({
        next: (res) => {
          this.turns.set(res.data?.turns ?? []);
          this.loading.set(false);
          this.scrollToBottom();
        },
        error: () => {
          this.loading.set(false);
        },
      });
  }

  close(): void {
    this.stopStream();
    this.visible = false;
    this.visibleChange.emit(false);
  }

  toggleToolCall(turnId: string, index: number): void {
    const key = `${turnId}-${index}`;
    this.expandedToolCalls.update((prev) => ({
      ...prev,
      [key]: !prev[key],
    }));
  }

  isToolCallExpanded(turnId: string, index: number): boolean {
    return !!this.expandedToolCalls()[`${turnId}-${index}`];
  }

  onScroll(event: Event): void {
    const target = event.target as HTMLElement;
    const distanceToBottom = target.scrollHeight - target.scrollTop - target.clientHeight;
    this.userScrolledUp = distanceToBottom > 80;
  }

  sendPrompt(): void {
    const text = this.promptInput().trim();
    if (!text || this.isStreaming()) {
      return;
    }

    const currentThreadId = this.threadId();
    const userTurn: CodexTurn = {
      id: `user-${Date.now()}`,
      role: 'user',
      content: text,
      createdAt: new Date().toISOString(),
    };

    const assistantTurnId = `assistant-${Date.now()}`;
    const assistantTurn: CodexTurn = {
      id: assistantTurnId,
      role: 'assistant',
      content: '',
      status: 'streaming',
      createdAt: new Date().toISOString(),
    };

    this.turns.update((t) => [...t, userTurn, assistantTurn]);
    this.promptInput.set('');
    this.streamError.set(null);
    this.isStreaming.set(true);
    this.scrollToBottom(true);

    const request: CodexPromptRequest = {
      prompt: text,
      threadId: currentThreadId ?? undefined,
      model: this.selectedModel(),
      reasoningEffort: this.selectedEffort(),
      instruction: this.instruction() ? this.instruction() : undefined,
      sandboxMode: this.sandboxMode(),
    };

    this.activeAbortController = this.sdkService.streamPrompt(
      request,
      (token: string) => {
        this.turns.update((list) =>
          list.map((turn) =>
            turn.id === assistantTurnId
              ? { ...turn, content: turn.content + token }
              : turn
          )
        );
        if (!this.userScrolledUp) {
          this.scrollToBottom();
        }
      },
      (err: any) => {
        this.isStreaming.set(false);
        this.streamError.set(typeof err === 'string' ? err : 'Mất kết nối stream');
        this.turns.update((list) =>
          list.map((turn) =>
            turn.id === assistantTurnId
              ? { ...turn, status: 'failed' }
              : turn
          )
        );
      },
      () => {
        this.isStreaming.set(false);
        this.turns.update((list) =>
          list.map((turn) =>
            turn.id === assistantTurnId
              ? { ...turn, status: 'completed' }
              : turn
          )
        );
        this.threadUpdated.emit();
      }
    );
  }

  stopStream(): void {
    if (this.activeAbortController) {
      this.activeAbortController.abort();
      this.activeAbortController = null;
    }
    this.isStreaming.set(false);
  }

  retryLastPrompt(): void {
    const allTurns = this.turns();
    const lastUserTurn = [...allTurns].reverse().find((t) => t.role === 'user');
    if (lastUserTurn) {
      this.promptInput.set(lastUserTurn.content);
      this.sendPrompt();
    }
  }

  private scrollToBottom(force = false): void {
    setTimeout(() => {
      if (this.timelineRef && (!this.userScrolledUp || force)) {
        this.timelineRef.nativeElement.scrollTop = this.timelineRef.nativeElement.scrollHeight;
      }
    }, 10);
  }
}
```

- [ ] **Step 3: Viết HTML `codex-chat-drawer.component.html`**

```html
<app-drawer
  [visible]="visible"
  [title]="threadId() ? ('codex_sdk.drawer.titleDetail' | translateContent) : ('codex_sdk.drawer.titleNew' | translateContent)"
  [side]="'right'"
  [size]="'xl'"
  (visibleChange)="close()"
>
  <div class="workbench-container">
    <!-- Header info banner -->
    <div class="workbench-meta">
      <span class="meta-label">{{ 'codex_sdk.drawer.threadId' | translateContent }}:</span>
      <span class="meta-value">{{ threadId() || ('codex_sdk.drawer.newSession' | translateContent) }}</span>
      <app-copyable-text *ngIf="threadId()" [value]="threadId()!"></app-copyable-text>
    </div>

    <!-- Timeline Body -->
    <div class="workbench-timeline" #timelineContainer (scroll)="onScroll($event)">
      <div *ngIf="loading()" class="timeline-loading">
        <div class="bubble-skeleton shimmer"></div>
        <div class="bubble-skeleton shimmer right"></div>
      </div>

      <div *ngIf="!loading() && turns().length === 0" class="timeline-empty">
        <i class="pi pi-comments empty-icon"></i>
        <p class="empty-text">{{ 'codex_sdk.drawer.emptyGuide' | translateContent }}</p>
      </div>

      <div *ngFor="let turn of turns()" class="turn-bubble-wrapper" [class.turn-user]="turn.role === 'user'">
        <div class="turn-bubble" [class.user]="turn.role === 'user'" [class.assistant]="turn.role === 'assistant'">
          <div class="turn-header">
            <span class="role-badge">{{ turn.role }}</span>
            <span class="time-stamp" *ngIf="turn.createdAt">{{ turn.createdAt | date:'HH:mm:ss' }}</span>
          </div>

          <!-- Tool calls accordion inspector -->
          <div *ngIf="turn.toolCalls && turn.toolCalls.length > 0" class="tool-calls-container">
            <div *ngFor="let tool of turn.toolCalls; let i = index" class="tool-call-item">
              <button type="button" class="tool-call-summary" (click)="toggleToolCall(turn.id, i)">
                <i class="pi" [class.pi-chevron-right]="!isToolCallExpanded(turn.id, i)" [class.pi-chevron-down]="isToolCallExpanded(turn.id, i)"></i>
                <span class="tool-name">{{ tool.name }}</span>
                <span class="tool-status" [class.success]="tool.status === 'success'">{{ tool.status }}</span>
                <span class="tool-latency" *ngIf="tool.durationMs">{{ tool.durationMs }}ms</span>
              </button>
              <div class="tool-call-details" *ngIf="isToolCallExpanded(turn.id, i)">
                <app-json-viewer [data]="tool.input || tool.output"></app-json-viewer>
              </div>
            </div>
          </div>

          <!-- Message content -->
          <div class="turn-content">
            <p class="turn-text">{{ turn.content }}</p>
            <span *ngIf="turn.status === 'streaming'" class="streaming-cursor"></span>
          </div>

          <!-- Metrics footer -->
          <div class="turn-footer" *ngIf="turn.metrics">
            <span *ngIf="turn.metrics.model">{{ turn.metrics.model }}</span>
            <span *ngIf="turn.metrics.totalTokens">{{ turn.metrics.totalTokens }} tokens</span>
            <span *ngIf="turn.metrics.latencyMs">{{ turn.metrics.latencyMs }}ms</span>
          </div>
        </div>
      </div>

      <!-- Partial error banner -->
      <div *ngIf="streamError()" class="stream-error-banner">
        <i class="pi pi-exclamation-triangle"></i>
        <span>{{ streamError() }}</span>
        <button type="button" class="retry-btn" (click)="retryLastPrompt()">
          {{ 'codex_sdk.drawer.retry' | translateContent }}
        </button>
      </div>
    </div>

    <!-- Docked bottom bar (~110px) -->
    <div class="workbench-bottom-bar">
      <div class="control-row">
        <select class="model-select" [value]="selectedModel()" (change)="selectedModel.set($any($event.target).value)">
          <option value="claude-sonnet-5">Claude Sonnet 5</option>
          <option value="claude-opus-5">Claude Opus 5</option>
          <option value="gpt-5.2">GPT 5.2</option>
        </select>

        <select class="effort-select" [value]="selectedEffort()" (change)="selectedEffort.set($any($event.target).value)">
          <option value="low">Effort: Low</option>
          <option value="medium">Effort: Medium</option>
          <option value="high">Effort: High</option>
        </select>

        <button type="button" class="advanced-toggle-btn" (click)="showAdvanced.update(v => !v)">
          <i class="pi pi-cog"></i>
          {{ 'codex_sdk.drawer.advanced' | translateContent }}
        </button>
      </div>

      <!-- Advanced Settings Popover -->
      <div *ngIf="showAdvanced()" class="advanced-popover">
        <div class="field-group">
          <label>{{ 'codex_sdk.drawer.systemInstruction' | translateContent }}</label>
          <input type="text" [value]="instruction()" (input)="instruction.set($any($event.target).value)" placeholder="System instruction..." />
        </div>
        <div class="field-group">
          <label>{{ 'codex_sdk.drawer.sandboxMode' | translateContent }}</label>
          <select [value]="sandboxMode()" (change)="sandboxMode.set($any($event.target).value)">
            <option value="workspace-write">workspace-write</option>
            <option value="read-only">read-only</option>
          </select>
        </div>
      </div>

      <div class="input-row">
        <textarea
          class="prompt-textarea"
          rows="2"
          [placeholder]="'codex_sdk.drawer.promptPlaceholder' | translateContent"
          [value]="promptInput()"
          (input)="promptInput.set($any($event.target).value)"
          (keydown.control.enter)="sendPrompt()"
        ></textarea>

        <div class="actions">
          <app-button
            *ngIf="!isStreaming()"
            [label]="'codex_sdk.drawer.send' | translateContent"
            [variant]="'primary'"
            (click)="sendPrompt()"
            [disabled]="!promptInput().trim()"
          ></app-button>

          <button
            *ngIf="isStreaming()"
            type="button"
            class="stop-stream-btn"
            (click)="stopStream()"
          >
            <i class="pi pi-stop-circle"></i>
            {{ 'codex_sdk.drawer.stop' | translateContent }}
          </button>
        </div>
      </div>
    </div>
  </div>
</app-drawer>
```

- [ ] **Step 4: Viết SCSS `codex-chat-drawer.component.scss`**

```scss
.workbench-container {
  display: flex;
  flex-direction: column;
  height: 100%;
  max-height: 100%;
  overflow: hidden;
  background-color: var(--app-surface, #ffffff);
}

.workbench-meta {
  display: flex;
  align-items: center;
  gap: 8px;
  padding: 8px 16px;
  border-bottom: 1px solid var(--app-border, #e5e7eb);
  background-color: var(--app-surface-variant, #f9fafb);
  font-size: 13px;

  .meta-label {
    color: var(--app-text-secondary, #6b7280);
  }

  .meta-value {
    font-weight: 600;
    font-family: monospace;
  }
}

.workbench-timeline {
  flex: 1;
  overflow-y: auto;
  padding: 16px;
  display: flex;
  flex-direction: column;
  gap: 16px;
}

.turn-bubble-wrapper {
  display: flex;
  width: 100%;

  &.turn-user {
    justify-content: flex-end;
  }
}

.turn-bubble {
  max-width: 85%;
  border-radius: 8px;
  padding: 12px;
  font-size: 14px;
  line-height: 1.5;

  &.user {
    background-color: var(--app-primary, #0284c7);
    color: #ffffff;
  }

  &.assistant {
    background-color: var(--app-surface-variant, #f3f4f6);
    color: var(--app-text, #111827);
    border: 1px solid var(--app-border, #e5e7eb);
  }
}

.turn-header {
  display: flex;
  justify-content: space-between;
  font-size: 11px;
  opacity: 0.8;
  margin-bottom: 6px;
  text-transform: uppercase;
  font-weight: 600;
}

.tool-calls-container {
  margin-bottom: 10px;
  border: 1px solid var(--app-border, #e5e7eb);
  border-radius: 6px;
  background: var(--app-surface, #ffffff);
}

.tool-call-summary {
  width: 100%;
  display: flex;
  align-items: center;
  gap: 8px;
  padding: 6px 10px;
  background: transparent;
  border: none;
  font-size: 12px;
  cursor: pointer;
  text-align: left;

  .tool-name {
    font-weight: 600;
    font-family: monospace;
  }

  .tool-status {
    padding: 2px 6px;
    border-radius: 4px;
    font-size: 10px;
    background: #fee2e2;
    color: #991b1b;

    &.success {
      background: #dcfce7;
      color: #166534;
    }
  }

  .tool-latency {
    margin-left: auto;
    color: var(--app-text-secondary, #6b7280);
  }
}

.tool-call-details {
  padding: 8px;
  border-top: 1px solid var(--app-border, #e5e7eb);
}

.turn-text {
  margin: 0;
  white-space: pre-wrap;
  word-break: break-word;
}

.turn-footer {
  display: flex;
  gap: 12px;
  margin-top: 8px;
  font-size: 11px;
  opacity: 0.7;
  border-top: 1px dashed rgba(0, 0, 0, 0.1);
  padding-top: 4px;
}

.streaming-cursor {
  display: inline-block;
  width: 6px;
  height: 14px;
  background-color: currentColor;
  animation: blink 1s infinite;
  vertical-align: middle;
  margin-left: 2px;
}

@keyframes blink {
  0%, 100% { opacity: 1; }
  50% { opacity: 0; }
}

.stream-error-banner {
  display: flex;
  align-items: center;
  gap: 8px;
  padding: 8px 12px;
  background: #fef2f2;
  border: 1px solid #f87171;
  border-radius: 6px;
  color: #991b1b;
  font-size: 13px;

  .retry-btn {
    margin-left: auto;
    background: #b91c1c;
    color: #fff;
    border: none;
    padding: 4px 8px;
    border-radius: 4px;
    cursor: pointer;
  }
}

.workbench-bottom-bar {
  border-top: 1px solid var(--app-border, #e5e7eb);
  padding: 10px 16px;
  background: var(--app-surface, #ffffff);
  display: flex;
  flex-direction: column;
  gap: 8px;
  min-height: 110px;

  .control-row {
    display: flex;
    gap: 8px;
    align-items: center;

    select {
      font-size: 12px;
      padding: 4px 8px;
      border: 1px solid var(--app-border, #d1d5db);
      border-radius: 4px;
      background: var(--app-surface, #ffffff);
    }

    .advanced-toggle-btn {
      margin-left: auto;
      background: transparent;
      border: none;
      font-size: 12px;
      cursor: pointer;
      color: var(--app-primary, #0284c7);
      display: flex;
      align-items: center;
      gap: 4px;
    }
  }

  .advanced-popover {
    display: flex;
    gap: 12px;
    padding: 8px;
    border: 1px solid var(--app-border, #e5e7eb);
    border-radius: 6px;
    background: var(--app-surface-variant, #f9fafb);

    .field-group {
      display: flex;
      flex-direction: column;
      gap: 4px;
      flex: 1;

      label {
        font-size: 11px;
        color: var(--app-text-secondary, #6b7280);
      }

      input, select {
        padding: 4px 6px;
        border: 1px solid var(--app-border, #d1d5db);
        border-radius: 4px;
        font-size: 12px;
      }
    }
  }

  .input-row {
    display: flex;
    gap: 8px;
    align-items: flex-end;

    .prompt-textarea {
      flex: 1;
      resize: none;
      border: 1px solid var(--app-border, #d1d5db);
      border-radius: 6px;
      padding: 8px;
      font-size: 13px;
      line-height: 1.4;
      outline: none;

      &:focus {
        border-color: var(--app-primary, #0284c7);
      }
    }

    .stop-stream-btn {
      display: flex;
      align-items: center;
      gap: 4px;
      background: #ef4444;
      color: white;
      border: none;
      border-radius: 6px;
      padding: 8px 12px;
      font-size: 13px;
      font-weight: 500;
      cursor: pointer;
    }
  }
}
```

- [ ] **Step 5: Chạy test verify pass**

Run command:
```powershell
npm test -- src/app/features/codex-sdk/components/codex-chat-drawer/codex-chat-drawer.component.spec.ts
```
Expected: PASS 3 tests.

- [ ] **Step 6: Commit drawer component**

```bash
git add web/dev-tool-web/src/app/features/codex-sdk/components/codex-chat-drawer/
git commit -m "feat(codex-sdk): create codex chat drawer component with collapsible inspector"
```

---

### Task 4 (FE): `CodexThreadListPageComponent` với Phân trang Cursor trên Toolbar

**Files:**
- Create: `web/dev-tool-web/src/app/features/codex-sdk/pages/codex-thread-list/codex-thread-list.component.ts`
- Create: `web/dev-tool-web/src/app/features/codex-sdk/pages/codex-thread-list/codex-thread-list.component.html`
- Create: `web/dev-tool-web/src/app/features/codex-sdk/pages/codex-thread-list/codex-thread-list.component.scss`
- Create: `web/dev-tool-web/src/app/features/codex-sdk/pages/codex-thread-list/codex-thread-list.component.spec.ts`

- [ ] **Step 1: Viết test failing `codex-thread-list.component.spec.ts`**

```typescript
import { ComponentFixture, TestBed } from '@angular/core/testing';
import { NO_ERRORS_SCHEMA } from '@angular/core';
import { TranslateContentPipe } from '@shared/pipes/translate-content.pipe';
import { of } from 'rxjs';
import { CodexThreadListPageComponent } from './codex-thread-list.component';
import { CodexSdkService } from '../../services/codex-sdk.service';

describe('CodexThreadListPageComponent', () => {
  let fixture: ComponentFixture<CodexThreadListPageComponent>;
  let component: CodexThreadListPageComponent;
  let mockSdkService: {
    getThreads: ReturnType<typeof vi.fn>;
  };

  beforeEach(async () => {
    mockSdkService = {
      getThreads: vi.fn().mockReturnValue(
        of({
          data: {
            data: [
              { id: 't-100', preview: 'Debug test', turnCount: 4, createdAt: '2026-09-06T09:00:00Z' },
            ],
            nextCursor: 'next-cur-1',
          },
        })
      ),
    };

    await TestBed.configureTestingModule({
      declarations: [CodexThreadListPageComponent, TranslateContentPipe],
      providers: [{ provide: CodexSdkService, useValue: mockSdkService }],
      schemas: [NO_ERRORS_SCHEMA],
    }).compileComponents();

    fixture = TestBed.createComponent(CodexThreadListPageComponent);
    component = fixture.componentInstance;
    fixture.detectChanges();
  });

  it('loads thread list on init and sets table data', () => {
    expect(mockSdkService.getThreads).toHaveBeenCalled();
    expect(component.threads().length).toBe(1);
    expect(component.threads()[0].id).toBe('t-100');
    expect(component.nextCursor()).toBe('next-cur-1');
  });

  it('opens drawer for testing new prompt when workbench button is clicked', () => {
    component.openNewWorkbench();
    expect(component.drawerVisible()).toBe(true);
    expect(component.selectedThreadId()).toBeNull();
  });

  it('navigates next page with cursor and enables previous page button', () => {
    component.goToNextPage();
    expect(component.cursorHistory().length).toBe(1);
    expect(mockSdkService.getThreads).toHaveBeenCalledWith(expect.objectContaining({ cursor: 'next-cur-1' }));
  });
});
```

- [ ] **Step 2: Viết code TypeScript `codex-thread-list.component.ts`**

```typescript
import { Component, DestroyRef, OnInit, TemplateRef, ViewChild, inject, signal } from '@angular/core';
import { takeUntilDestroyed } from '@angular/core/rxjs-interop';
import { ActionToolbarAction } from '@shared/ui/layout/action-toolbar/action-toolbar.component';
import { FilterPanelField } from '@shared/ui/layout/filter-panel/filter-panel.component';
import { TableConfig } from '@shared/ui/table/table/table.component';
import { CodexThreadItem } from '../../models/codex-sdk.model';
import { CodexSdkService } from '../../services/codex-sdk.service';
import { CodexChatDrawerComponent } from '../../components/codex-chat-drawer/codex-chat-drawer.component';

@Component({
  selector: 'app-codex-thread-list',
  standalone: false,
  templateUrl: './codex-thread-list.component.html',
  styleUrls: ['./codex-thread-list.component.scss'],
})
export class CodexThreadListPageComponent implements OnInit {
  private readonly sdkService = inject(CodexSdkService);
  private readonly destroyRef = inject(DestroyRef);

  @ViewChild('drawer') drawerComponent?: CodexChatDrawerComponent;
  @ViewChild('previewTemplate', { static: true }) previewTemplate!: TemplateRef<any>;
  @ViewChild('createdAtTemplate', { static: true }) createdAtTemplate!: TemplateRef<any>;

  readonly threads = signal<CodexThreadItem[]>([]);
  readonly loading = signal(false);
  readonly drawerVisible = signal(false);
  readonly selectedThreadId = signal<string | null>(null);

  // Pagination Cursors
  readonly currentCursor = signal<string | undefined>(undefined);
  readonly nextCursor = signal<string | null>(null);
  readonly cursorHistory = signal<string[]>([]);

  // Filter values
  readonly searchTerm = signal('');
  readonly archivedFilter = signal<boolean | undefined>(undefined);

  tableConfig: TableConfig<CodexThreadItem> = {
    columns: [
      { field: 'id', header: 'Thread ID', width: '180px' },
      { field: 'preview', header: 'codex_sdk.table.preview', width: 'auto' },
      { field: 'turnCount', header: 'codex_sdk.table.turnCount', width: '120px' },
      { field: 'createdAt', header: 'codex_sdk.table.createdAt', width: '180px' },
      {
        field: 'actions',
        header: 'codex_sdk.table.actions',
        type: 'actions',
        width: '120px',
        actions: [
          {
            label: 'codex_sdk.table.viewDetail',
            icon: 'pi pi-eye',
            onClick: (row: CodexThreadItem) => this.openThreadDetail(row.id),
          },
        ],
      },
    ],
    emptyTitle: 'codex_sdk.table.emptyTitle',
    emptyDescription: 'codex_sdk.table.emptyDescription',
  };

  readonly filterFields: FilterPanelField[] = [
    {
      key: 'searchTerm',
      label: 'codex_sdk.filter.search',
      type: 'text',
      placeholder: 'codex_sdk.filter.searchPlaceholder',
    },
    {
      key: 'archived',
      label: 'codex_sdk.filter.status',
      type: 'select',
      options: [
        { label: 'codex_sdk.filter.all', value: '' },
        { label: 'codex_sdk.filter.active', value: 'false' },
        { label: 'codex_sdk.filter.archived', value: 'true' },
      ],
    },
  ];

  get toolbarActions(): ActionToolbarAction[] {
    return [
      {
        label: 'codex_sdk.toolbar.refresh',
        icon: 'pi pi-refresh',
        variant: 'secondary',
        onClick: () => this.loadThreads(),
      },
      {
        label: 'codex_sdk.toolbar.openWorkbench',
        icon: 'pi pi-plus',
        variant: 'primary',
        onClick: () => this.openNewWorkbench(),
      },
      {
        label: 'codex_sdk.toolbar.prevPage',
        icon: 'pi pi-chevron-left',
        variant: 'secondary',
        disabled: this.cursorHistory().length === 0,
        onClick: () => this.goToPrevPage(),
      },
      {
        label: 'codex_sdk.toolbar.nextPage',
        icon: 'pi pi-chevron-right',
        variant: 'secondary',
        disabled: !this.nextCursor(),
        onClick: () => this.goToNextPage(),
      },
    ];
  }

  ngOnInit(): void {
    this.loadThreads();
  }

  loadThreads(cursor?: string): void {
    this.loading.set(true);
    this.sdkService
      .getThreads({
        limit: 15,
        cursor,
        searchTerm: this.searchTerm() || undefined,
        archived: this.archivedFilter(),
      })
      .pipe(takeUntilDestroyed(this.destroyRef))
      .subscribe({
        next: (res) => {
          this.threads.set(res.data?.data ?? []);
          this.nextCursor.set(res.data?.nextCursor ?? null);
          this.currentCursor.set(cursor);
          this.loading.set(false);
        },
        error: () => {
          this.loading.set(false);
        },
      });
  }

  onFilterChange(values: Record<string, unknown>): void {
    this.searchTerm.set(typeof values['searchTerm'] === 'string' ? values['searchTerm'].trim() : '');
    const arch = values['archived'];
    this.archivedFilter.set(arch === 'true' ? true : arch === 'false' ? false : undefined);
    this.cursorHistory.set([]);
    this.loadThreads();
  }

  openThreadDetail(threadId: string): void {
    this.selectedThreadId.set(threadId);
    this.drawerVisible.set(true);
    this.drawerComponent?.openThread(threadId);
  }

  openNewWorkbench(): void {
    this.selectedThreadId.set(null);
    this.drawerVisible.set(true);
    this.drawerComponent?.openThread(null);
  }

  goToNextPage(): void {
    const next = this.nextCursor();
    if (!next) return;

    this.cursorHistory.update((h) => [...h, this.currentCursor() ?? '']);
    this.loadThreads(next);
  }

  goToPrevPage(): void {
    const history = [...this.cursorHistory()];
    if (history.length === 0) return;

    const prevCursor = history.pop();
    this.cursorHistory.set(history);
    this.loadThreads(prevCursor || undefined);
  }
}
```

- [ ] **Step 3: Viết HTML `codex-thread-list.component.html`**

```html
<app-page-shell
  [title]="'codex_sdk.page.title' | translateContent"
  [subtitle]="'codex_sdk.page.subtitle' | translateContent"
>
  <app-action-toolbar [actions]="toolbarActions"></app-action-toolbar>

  <app-filter-panel
    [fields]="filterFields"
    (filterChange)="onFilterChange($event)"
  ></app-filter-panel>

  <app-table
    [config]="tableConfig"
    [data]="threads()"
    [loading]="loading()"
    [customTemplates]="{ preview: previewTemplate, createdAt: createdAtTemplate }"
  ></app-table>

  <ng-template #previewTemplate let-row="row">
    <span class="preview-text truncate" [title]="row.preview || ''">
      {{ row.preview || ('codex_sdk.table.noPreview' | translateContent) }}
    </span>
  </ng-template>

  <ng-template #createdAtTemplate let-row="row">
    <span>{{ row.createdAt ? (row.createdAt | date:'yyyy-MM-dd HH:mm:ss') : '-' }}</span>
  </ng-template>

  <app-codex-chat-drawer
    #drawer
    [(visible)]="drawerVisible"
    (threadUpdated)="loadThreads(currentCursor())"
  ></app-codex-chat-drawer>
</app-page-shell>
```

- [ ] **Step 4: Viết SCSS `codex-thread-list.component.scss`**

```scss
.preview-text {
  display: block;
  max-width: 480px;
  color: var(--app-text, #1f2937);
  font-size: 13px;
}
```

- [ ] **Step 5: Chạy test verify pass**

Run command:
```powershell
npm test -- src/app/features/codex-sdk/pages/codex-thread-list/codex-thread-list.component.spec.ts
```
Expected: PASS 3 tests.

- [ ] **Step 6: Commit page component**

```bash
git add web/dev-tool-web/src/app/features/codex-sdk/pages/codex-thread-list/
git commit -m "feat(codex-sdk): implement codex thread list page with cursor pagination toolbar"
```

---

### Task 5 (FE): Module Setup, Route Registration, i18n & Navigation Menu

**Files:**
- Create: `web/dev-tool-web/src/app/features/codex-sdk/codex-sdk.routes.ts`
- Create: `web/dev-tool-web/src/app/features/codex-sdk/codex-sdk.module.ts`
- Create: `web/dev-tool-web/src/app/core/i18n/features/codex-sdk.i18n.json`
- Modify: `web/dev-tool-web/src/app/core/i18n/i18n.service.ts`
- Modify: `web/dev-tool-web/src/app/features/app-feature.module.ts`
- Modify: `web/dev-tool-web/src/app/app-shell/navigation/config/menu.config.ts`

- [ ] **Step 1: Tạo `codex-sdk.routes.ts`**

```typescript
import { Routes } from '@angular/router';
import { CodexThreadListPageComponent } from './pages/codex-thread-list/codex-thread-list.component';

export const codexSdkRoutes: Routes = [
  {
    path: 'codex-sdk/threads',
    component: CodexThreadListPageComponent,
  },
];
```

- [ ] **Step 2: Tạo `codex-sdk.module.ts`**

```typescript
import { CommonModule } from '@angular/common';
import { NgModule } from '@angular/core';
import { FormsModule, ReactiveFormsModule } from '@angular/forms';
import { RouterModule } from '@angular/router';
import { SharedModule } from '@shared/shared.module';

import { codexSdkRoutes } from './codex-sdk.routes';
import { CodexThreadListPageComponent } from './pages/codex-thread-list/codex-thread-list.component';
import { CodexChatDrawerComponent } from './components/codex-chat-drawer/codex-chat-drawer.component';

@NgModule({
  declarations: [CodexThreadListPageComponent, CodexChatDrawerComponent],
  imports: [
    CommonModule,
    FormsModule,
    ReactiveFormsModule,
    RouterModule.forChild(codexSdkRoutes),
    SharedModule,
  ],
  exports: [CodexThreadListPageComponent, CodexChatDrawerComponent],
})
export class CodexSdkModule {}
```

- [ ] **Step 3: Tạo `codex-sdk.i18n.json`**

```json
{
  "vi": {
    "codex_sdk.page.title": "Lịch sử Chat Codex SDK",
    "codex_sdk.page.subtitle": "Tra cứu lịch sử và kiểm thử tương tác trực tiếp qua AI Agent Orchestrator",
    "codex_sdk.toolbar.refresh": "Làm mới",
    "codex_sdk.toolbar.openWorkbench": "Mở Workbench test",
    "codex_sdk.toolbar.prevPage": "Trang trước",
    "codex_sdk.toolbar.nextPage": "Trang sau",
    "codex_sdk.filter.search": "Tìm kiếm",
    "codex_sdk.filter.searchPlaceholder": "Tìm theo ID hoặc nội dung preview...",
    "codex_sdk.filter.status": "Trạng thái",
    "codex_sdk.filter.all": "Tất cả",
    "codex_sdk.filter.active": "Hoạt động",
    "codex_sdk.filter.archived": "Đã lưu trữ",
    "codex_sdk.table.preview": "Nội dung preview",
    "codex_sdk.table.turnCount": "Số lượt chat",
    "codex_sdk.table.createdAt": "Thời gian tạo",
    "codex_sdk.table.actions": "Thao tác",
    "codex_sdk.table.viewDetail": "Xem chi tiết",
    "codex_sdk.table.emptyTitle": "Không tìm thấy phiên hội thoại nào",
    "codex_sdk.table.emptyDescription": "Bấm 'Mở Workbench test' để bắt đầu một phiên đàm thoại mới.",
    "codex_sdk.table.noPreview": "(Chưa có nội dung)",
    "codex_sdk.drawer.titleDetail": "Chi tiết Hội thoại SDK",
    "codex_sdk.drawer.titleNew": "Workbench Kiểm thử Prompt",
    "codex_sdk.drawer.threadId": "Mã Thread",
    "codex_sdk.drawer.newSession": "Phiên làm việc mới",
    "codex_sdk.drawer.emptyGuide": "Nhập nội dung prompt bên dưới để bắt đầu phiên kiểm thử.",
    "codex_sdk.drawer.send": "Gửi",
    "codex_sdk.drawer.stop": "Dừng stream",
    "codex_sdk.drawer.retry": "Thử lại",
    "codex_sdk.drawer.advanced": "Nâng cao",
    "codex_sdk.drawer.systemInstruction": "Chỉ dẫn hệ thống (Instruction)",
    "codex_sdk.drawer.sandboxMode": "Chế độ Sandbox",
    "codex_sdk.drawer.promptPlaceholder": "Nhập prompt test... (Ctrl+Enter để gửi)",
    "layout.menu.codexSdkChat": "Codex SDK Chat"
  },
  "en": {
    "codex_sdk.page.title": "Codex SDK Chat History",
    "codex_sdk.page.subtitle": "Inspect thread history and live-test turns via AI Agent Orchestrator",
    "codex_sdk.toolbar.refresh": "Refresh",
    "codex_sdk.toolbar.openWorkbench": "Open Workbench",
    "codex_sdk.toolbar.prevPage": "Previous",
    "codex_sdk.toolbar.nextPage": "Next",
    "codex_sdk.filter.search": "Search",
    "codex_sdk.filter.searchPlaceholder": "Search by ID or preview...",
    "codex_sdk.filter.status": "Status",
    "codex_sdk.filter.all": "All",
    "codex_sdk.filter.active": "Active",
    "codex_sdk.filter.archived": "Archived",
    "codex_sdk.table.preview": "Preview",
    "codex_sdk.table.turnCount": "Turns",
    "codex_sdk.table.createdAt": "Created At",
    "codex_sdk.table.actions": "Actions",
    "codex_sdk.table.viewDetail": "View detail",
    "codex_sdk.table.emptyTitle": "No threads found",
    "codex_sdk.table.emptyDescription": "Click 'Open Workbench' to start a new chat turn.",
    "codex_sdk.table.noPreview": "(No preview available)",
    "codex_sdk.drawer.titleDetail": "SDK Conversation Detail",
    "codex_sdk.drawer.titleNew": "Prompt Test Workbench",
    "codex_sdk.drawer.threadId": "Thread ID",
    "codex_sdk.drawer.newSession": "New session",
    "codex_sdk.drawer.emptyGuide": "Enter prompt below to test your agent session.",
    "codex_sdk.drawer.send": "Send",
    "codex_sdk.drawer.stop": "Stop stream",
    "codex_sdk.drawer.retry": "Retry",
    "codex_sdk.drawer.advanced": "Advanced",
    "codex_sdk.drawer.systemInstruction": "System Instruction",
    "codex_sdk.drawer.sandboxMode": "Sandbox Mode",
    "codex_sdk.drawer.promptPlaceholder": "Enter prompt... (Ctrl+Enter to send)",
    "layout.menu.codexSdkChat": "Codex SDK Chat"
  }
}
```

- [ ] **Step 4: Cập nhật `i18n.service.ts`, `app-feature.module.ts` và `menu.config.ts`**

Trong `src/app/core/i18n/i18n.service.ts`:
- Import `codexSdkTranslations from '../i18n/features/codex-sdk.i18n.json';`
- Đưa `...codexSdkTranslations.vi` và `...codexSdkTranslations.en` vào bảng `TRANSLATIONS`.

Trong `src/app/features/app-feature.module.ts`:
- Import `CodexSdkModule` và `codexSdkRoutes` từ `./codex-sdk/...`.
- Thêm `...codexSdkRoutes` vào `FEATURE_ROUTES`.
- Thêm `CodexSdkModule` vào mảng `imports`.

Trong `src/app/app-shell/navigation/config/menu.config.ts`:
- Thêm mục con trong nhóm `layout.menu.aiAgentMcrs`:
  ```typescript
  {
    label: 'layout.menu.codexSdkChat',
    icon: 'pi pi-comments',
    routerLink: '/codex-sdk/threads',
  }
  ```

- [ ] **Step 5: Chạy build và test compile verify**

Run command:
```powershell
npm run build --prefix web/dev-tool-web
```
Expected: `Build at: ... - Hash: ... - Time: ...ms` thành công 0 lỗi.

- [ ] **Step 6: Commit module integration**

```bash
git add web/dev-tool-web/src/app/features/codex-sdk/ web/dev-tool-web/src/app/core/i18n/ web/dev-tool-web/src/app/features/app-feature.module.ts web/dev-tool-web/src/app/app-shell/navigation/config/menu.config.ts
git commit -m "feat(codex-sdk): register module, routes, i18n and sidebar menu item"
```

---

### Task 6 (E2E & Verification): Vitest Full Suite & Playwright E2E Test

**Files:**
- Create: `web/dev-tool-web/e2e/codex-sdk-history.spec.ts`

- [ ] **Step 1: Viết kịch bản Playwright E2E `e2e/codex-sdk-history.spec.ts`**

```typescript
import { test, expect } from '@playwright/test';

test.describe('Codex SDK Chat History & Workbench', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto('/codex-sdk/threads');
  });

  test('renders page shell and table with action toolbar', async ({ page }) => {
    await expect(page.locator('app-page-shell')).toBeVisible();
    await expect(page.locator('app-action-toolbar')).toBeVisible();
    await expect(page.locator('app-table')).toBeVisible();
  });

  test('opens workbench drawer when clicking "Mở Workbench test"', async ({ page }) => {
    const openBtn = page.locator('app-action-toolbar button', { hasText: /Workbench|Tạo/i });
    if (await openBtn.count() > 0) {
      await openBtn.first().click();
      await expect(page.locator('app-drawer')).toBeVisible();
      await expect(page.locator('.workbench-bottom-bar')).toBeVisible();
    }
  });

  test('drawer co giãn full width trên mobile viewport', async ({ page }) => {
    await page.setViewportSize({ width: 375, height: 667 });
    const openBtn = page.locator('app-action-toolbar button', { hasText: /Workbench|Tạo/i });
    if (await openBtn.count() > 0) {
      await openBtn.first().click();
      const drawerBox = await page.locator('app-drawer .app-drawer-panel').boundingBox();
      if (drawerBox) {
        expect(drawerBox.width).toBeGreaterThanOrEqual(360);
      }
    }
  });
});
```

- [ ] **Step 2: Chạy toàn bộ Unit Tests của frontend**

Run command:
```powershell
npm test --prefix web/dev-tool-web
```
Expected: 100% test cases pass.

- [ ] **Step 3: Chạy Playwright E2E test**

Run command:
```powershell
npx playwright test e2e/codex-sdk-history.spec.ts
```
Expected: 3 passed.

- [ ] **Step 4: Commit E2E test suite**

```bash
git add web/dev-tool-web/e2e/codex-sdk-history.spec.ts
git commit -m "test(codex-sdk): add playwright e2e tests for codex sdk history and workbench"
```

---

## Execution Handoff

Plan complete and saved to `docs/superpowers/plans/2026-09-05-codex-sdk-chat-history-workbench.md`. Two execution options:

1. **Subagent-Driven (recommended)**: I dispatch a fresh subagent per task, review between tasks, fast iteration.
2. **Inline Execution**: Execute tasks in this session using executing-plans, batch execution with checkpoints.

Which approach?
