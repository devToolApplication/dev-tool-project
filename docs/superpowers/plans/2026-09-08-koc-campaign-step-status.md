# Kế hoạch Triển khai: Hiển thị Chi tiết Bước Xử lý Hiện tại của Chiến dịch KOC trên Màn hình Danh sách

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [x]`) syntax for tracking.

**Goal:** Hiển thị công đoạn xử lý thực tế của AI (quét KOC, lọc trùng, thẩm định tiêu chí, chờ quyết định, chờ phê duyệt) ngay tại cột trạng thái của danh sách chiến dịch KOC (`/koc/campaigns`).

**Architecture:** Bổ sung các trường `currentStep`, `currentStepTitle`, `currentRound`, `maxRounds`, `stepDetail` vào MongoDB `KocCampaignEntity`. Các JavaDelegate của Flowable cập nhật trạng thái bước nguyên tử qua `KocCampaignStorage.updateWorkflowStep`. Frontend hiển thị Two-Line Smart Badge (Badge chính + Bước nghiệp vụ chi tiết kèm Vòng X/Y) và Popover tóm tắt tiến trình.

**Tech Stack:** Java 21, Spring Boot 3.5, MongoDB, Flowable BPMN 2.0, Angular 21, PrimeNG / Shared UI Components (`app-table`, `app-badge`, `app-button`, `app-copyable-text`), Playwright.

---

### Task 1: Mở rộng Entity và Response DTO Backend

**Files:**
- Modify: `services/ai-agent-mcrs/src/main/java/com/lamld/aiAgent/modules/koccampaign/infrastructure/entity/KocCampaignEntity.java:55-63`
- Modify: `services/ai-agent-mcrs/src/main/java/com/lamld/aiAgent/modules/koccampaign/api/response/KocCampaignResponse.java:23-30`
- Test: `services/ai-agent-mcrs/src/test/java/com/lamld/aiAgent/modules/koccampaign/application/KocCampaignServiceTest.java`

- [x] **Step 1: Viết test kiểm tra ánh xạ các trường bước mới trong `KocCampaignServiceTest`**

Thêm test case kiểm tra `getCampaignById` hoặc mapping trả về đầy đủ các trường `currentStep`, `currentStepTitle`, `currentRound`, `maxRounds`, `stepDetail`:
```java
@Test
void getCampaignById_returnsAllStepDetails() {
  KocCampaignEntity entity = new KocCampaignEntity();
  entity.setId("camp-step-1");
  entity.setName("Camp Step Test");
  entity.setWorkflowStatus("RUNNING");
  entity.setCurrentStep("AI_SEARCH");
  entity.setCurrentStepTitle("Quét tìm KOC");
  entity.setCurrentRound(1);
  entity.setMaxRounds(3);
  entity.setStepDetail("Đang quét bài viết Facebook");

  when(storage.findById("camp-step-1")).thenReturn(Optional.of(entity));

  KocCampaignResponse response = service.getCampaignById("camp-step-1");

  assertNotNull(response);
  assertEquals("AI_SEARCH", response.getCurrentStep());
  assertEquals("Quét tìm KOC", response.getCurrentStepTitle());
  assertEquals(1, response.getCurrentRound());
  assertEquals(3, response.getMaxRounds());
  assertEquals("Đang quét bài viết Facebook", response.getStepDetail());
}
```

- [x] **Step 2: Chạy test để xác nhận test thất bại (do chưa có trường trong Entity/Response)**

Run: `mvn test -Dtest=KocCampaignServiceTest#getCampaignById_returnsAllStepDetails -f services/ai-agent-mcrs/pom.xml`
Expected: FAIL với lỗi compile "cannot find symbol: method setCurrentStep"

- [x] **Step 3: Bổ sung các trường vào `KocCampaignEntity.java` và `KocCampaignResponse.java`**

Trong `KocCampaignEntity.java`:
```java
  @Field("current_step")
  private String currentStep;

  @Field("current_step_title")
  private String currentStepTitle;

  @Field("current_round")
  private Integer currentRound;

  @Field("max_rounds")
  private Integer maxRounds;

  @Field("step_detail")
  private String stepDetail;
```

Trong `KocCampaignResponse.java`:
```java
  private String currentStep;
  private String currentStepTitle;
  private Integer currentRound;
  private Integer maxRounds;
  private String stepDetail;
```

- [x] **Step 4: Chạy lại test để đảm bảo 100% pass**

Run: `mvn test -Dtest=KocCampaignServiceTest -f services/ai-agent-mcrs/pom.xml`
Expected: BUILD SUCCESS (All tests pass)

- [x] **Step 5: Commit thay đổi Entity & DTO**

```bash
cd services/ai-agent-mcrs
git add src/main/java/com/lamld/aiAgent/modules/koccampaign/infrastructure/entity/KocCampaignEntity.java \
        src/main/java/com/lamld/aiAgent/modules/koccampaign/api/response/KocCampaignResponse.java \
        src/test/java/com/lamld/aiAgent/modules/koccampaign/application/KocCampaignServiceTest.java
git commit -m "feat(koc): add currentStep fields to KocCampaignEntity and Response"
cd ../..
```

---

### Task 2: Triển khai Phương thức Cập nhật Bước Nguyên tử tại `KocCampaignStorage`

**Files:**
- Modify: `services/ai-agent-mcrs/src/main/java/com/lamld/aiAgent/modules/koccampaign/infrastructure/storage/KocCampaignStorage.java:50-55`
- Create: `services/ai-agent-mcrs/src/test/java/com/lamld/aiAgent/modules/koccampaign/infrastructure/storage/KocCampaignStorageTest.java`

- [x] **Step 1: Viết failing unit test cho `updateWorkflowStep` trong `KocCampaignStorageTest`**

Tạo file `services/ai-agent-mcrs/src/test/java/com/lamld/aiAgent/modules/koccampaign/infrastructure/storage/KocCampaignStorageTest.java`:
```java
package com.lamld.aiAgent.modules.koccampaign.infrastructure.storage;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;

import com.lamld.aiAgent.modules.koccampaign.infrastructure.entity.KocCampaignEntity;
import com.lamld.aiAgent.modules.koccampaign.infrastructure.repository.KocCampaignRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;
import org.springframework.data.mongodb.core.MongoTemplate;
import org.springframework.data.mongodb.core.query.Query;
import org.springframework.data.mongodb.core.query.Update;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

class KocCampaignStorageTest {

  private KocCampaignRepository repository;
  private MongoTemplate mongoTemplate;
  private KocCampaignStorage storage;

  @BeforeEach
  void setUp() {
    repository = mock(KocCampaignRepository.class);
    mongoTemplate = mock(MongoTemplate.class);
    storage = new KocCampaignStorage(repository, mongoTemplate);
  }

  @Test
  void updateWorkflowStep_executesAtomicMongoUpdate() {
    storage.updateWorkflowStep("camp-123", "RUNNING", "AI_SEARCH", "Quét tìm KOC", 2, 5, "Đang quét vòng 2");

    ArgumentCaptor<Query> queryCaptor = ArgumentCaptor.forClass(Query.class);
    ArgumentCaptor<Update> updateCaptor = ArgumentCaptor.forClass(Update.class);

    verify(mongoTemplate).updateFirst(queryCaptor.capture(), updateCaptor.capture(), eq(KocCampaignEntity.class));

    assertEquals("camp-123", queryCaptor.getValue().getQueryObject().get("_id"));
    var updateObj = updateCaptor.getValue().getUpdateObject().get("$set");
    assertTrue(updateObj.toString().contains("AI_SEARCH"));
    assertTrue(updateObj.toString().contains("Quét tìm KOC"));
  }
}
```

- [x] **Step 2: Chạy test để xác nhận test thất bại**

Run: `mvn test -Dtest=KocCampaignStorageTest -f services/ai-agent-mcrs/pom.xml`
Expected: FAIL với lỗi "cannot find symbol: method updateWorkflowStep"

- [x] **Step 3: Triển khai phương thức `updateWorkflowStep` trong `KocCampaignStorage.java`**

Bổ sung vào `KocCampaignStorage.java`:
```java
  public void updateWorkflowStep(
      String campaignId,
      String workflowStatus,
      String currentStep,
      String currentStepTitle,
      Integer currentRound,
      Integer maxRounds,
      String stepDetail
  ) {
    if (CommonUtil.isBlank(campaignId)) {
      return;
    }
    Query query = new Query(Criteria.where("_id").is(campaignId.trim()));
    org.springframework.data.mongodb.core.query.Update update =
        new org.springframework.data.mongodb.core.query.Update();

    if (!CommonUtil.isBlank(workflowStatus)) {
      update.set("workflow_status", workflowStatus);
    }
    if (!CommonUtil.isBlank(currentStep)) {
      update.set("current_step", currentStep);
    }
    if (!CommonUtil.isBlank(currentStepTitle)) {
      update.set("current_step_title", currentStepTitle);
    }
    if (currentRound != null) {
      update.set("current_round", currentRound);
    }
    if (maxRounds != null) {
      update.set("max_rounds", maxRounds);
    }
    if (!CommonUtil.isBlank(stepDetail)) {
      update.set("step_detail", stepDetail);
    }
    update.set("updated_at", java.time.Instant.now());
    mongoTemplate.updateFirst(query, update, KocCampaignEntity.class);
  }
```

- [x] **Step 4: Chạy test để xác nhận test pass**

Run: `mvn test -Dtest=KocCampaignStorageTest -f services/ai-agent-mcrs/pom.xml`
Expected: BUILD SUCCESS (100% pass)

- [x] **Step 5: Commit thay đổi `KocCampaignStorage`**

```bash
cd services/ai-agent-mcrs
git add src/main/java/com/lamld/aiAgent/modules/koccampaign/infrastructure/storage/KocCampaignStorage.java \
        src/test/java/com/lamld/aiAgent/modules/koccampaign/infrastructure/storage/KocCampaignStorageTest.java
git commit -m "feat(koc): add updateWorkflowStep atomic helper in KocCampaignStorage"
cd ../..
```

---

### Task 3: Tích hợp Ghi nhận Bước vào các JavaDelegates trong BPMN

**Files:**
- Modify: `services/ai-agent-mcrs/src/main/java/com/lamld/aiAgent/modules/workflowprocess/infrastructure/flowable/delegate/InitializeDiscoveryStateDelegate.java`
- Modify: `services/ai-agent-mcrs/src/main/java/com/lamld/aiAgent/modules/workflowprocess/infrastructure/flowable/delegate/PrepareSearchContextDelegate.java`
- Modify: `services/ai-agent-mcrs/src/main/java/com/lamld/aiAgent/modules/workflowprocess/infrastructure/flowable/delegate/RecordSearchOutputDelegate.java`
- Modify: `services/ai-agent-mcrs/src/main/java/com/lamld/aiAgent/modules/workflowprocess/infrastructure/flowable/delegate/PrepareReviewContextDelegate.java`
- Modify: `services/ai-agent-mcrs/src/main/java/com/lamld/aiAgent/modules/workflowprocess/infrastructure/flowable/delegate/AdvanceSearchRoundDelegate.java`
- Modify: `services/ai-agent-mcrs/src/main/java/com/lamld/aiAgent/modules/workflowprocess/infrastructure/flowable/delegate/UpdateCampaignStatusDelegate.java`
- Modify: `services/ai-agent-mcrs/src/main/java/com/lamld/aiAgent/modules/workflowprocess/infrastructure/flowable/delegate/SaveKocCandidatesDelegate.java`
- Test: `services/ai-agent-mcrs/src/test/java/com/lamld/aiAgent/modules/workflowprocess/infrastructure/flowable/delegate/UpdateCampaignStatusDelegateTest.java`
- Test: `services/ai-agent-mcrs/src/test/java/com/lamld/aiAgent/modules/workflowprocess/infrastructure/flowable/delegate/InitializeDiscoveryStateDelegateTest.java`

- [x] **Step 1: Viết failing test cho `UpdateCampaignStatusDelegateTest` kiểm tra cập nhật step title**

Cập nhật `UpdateCampaignStatusDelegateTest.java` để xác minh khi delegate chạy với status `USER_TASK` hoặc `COMPLETED`, hàm `storage.updateWorkflowStep` được gọi với đúng `currentStep` và `currentStepTitle`:
```java
@Test
void execute_callsUpdateWorkflowStep_withDetailedStepInfo() {
  Expression status = mock(Expression.class);
  when(status.getValue(execution)).thenReturn("COMPLETED");
  ReflectionTestUtils.setField(delegate, "status", status);

  KocCampaignEntity campaign = new KocCampaignEntity();
  campaign.setId("camp-1");
  when(execution.getVariable(VAR_CAMPAIGN_ID)).thenReturn("camp-1");
  when(storage.findById("camp-1")).thenReturn(Optional.of(campaign));

  delegate.execute(execution);

  verify(storage).updateWorkflowStep(
      eq("camp-1"),
      eq("COMPLETED"),
      eq("COMPLETED"),
      eq("Hoàn thành chiến dịch"),
      any(),
      any(),
      any()
  );
}
```

- [x] **Step 2: Chạy test để xác nhận thất bại**

Run: `mvn test -Dtest=UpdateCampaignStatusDelegateTest#execute_callsUpdateWorkflowStep_withDetailedStepInfo -f services/ai-agent-mcrs/pom.xml`
Expected: FAIL

- [x] **Step 3: Cập nhật `UpdateCampaignStatusDelegate.java`**

Trong `UpdateCampaignStatusDelegate.execute`:
Xác định `currentStep`, `currentStepTitle`, `stepDetail` theo `targetStatus`:
- `USER_TASK`:
  - Nếu `flowData.getVariableData().getRoundsRemaining() == false`: `currentStep = "WAITING_DECISION"`, `currentStepTitle = "Chờ quyết định tìm tiếp"`, `stepDetail = "Đã hết số vòng tìm kiếm tự động, chờ người dùng quyết định tìm thêm hay dừng"`.
  - Nếu có ứng viên chờ duyệt: `currentStep = "WAITING_APPROVAL"`, `currentStepTitle = "Chờ phê duyệt KOC"`, `stepDetail = "Đã thu thập đủ ứng viên đạt chuẩn, chờ người quản trị duyệt danh sách KOC"`.
- `COMPLETED`: `currentStep = "COMPLETED"`, `currentStepTitle = "Hoàn thành chiến dịch"`, `stepDetail = "Chiến dịch đã hoàn tất quy trình tìm kiếm và lưu trữ ứng viên"`.
- `TERMINATED`: `currentStep = "TERMINATED"`, `currentStepTitle = "Đã dừng quy trình"`, `stepDetail = "Quy trình tìm kiếm KOC đã bị dừng hoặc từ chối"`.
- `RUNNING`: `currentStep = "RUNNING"`, `currentStepTitle = "Tiếp tục tìm kiếm"`, `stepDetail = "Gia hạn thêm vòng tìm kiếm KOC"`.
Gọi:
```java
storage.updateWorkflowStep(
    campaignIdToUpdate,
    targetStatus,
    currentStep,
    currentStepTitle,
    varData != null ? varData.getSearchRound() : null,
    varData != null ? varData.getMaxSearchRounds() : null,
    stepDetail
);
```

- [x] **Step 4: Cập nhật các delegates còn lại**

1. `InitializeDiscoveryStateDelegate`:
   - Sau khi lưu runId, gọi:
     ```java
     campaignStorage.updateWorkflowStep(
         campId,
         "RUNNING",
         "INITIALIZING",
         "Khởi tạo tiến trình",
         1,
         camp.getMaxSearchRounds(),
         "Đang nạp cấu hình chiến dịch và chuẩn bị tài khoản Facebook"
     );
     ```
2. `PrepareSearchContextDelegate`:
   - Bổ sung inject `KocCampaignStorage campaignStorage` (hoặc lấy qua flowData/campaignId).
   - Gọi `updateWorkflowStep(campaignId, "RUNNING", "AI_SEARCH", "Quét tìm KOC", varData.getSearchRound(), varData.getMaxSearchRounds(), "Đang quét bài viết Facebook theo tiêu chí")`.
3. `RecordSearchOutputDelegate`:
   - Gọi `updateWorkflowStep(campaignId, "RUNNING", "FILTERING", "Lọc trùng ứng viên", varData.getSearchRound(), varData.getMaxSearchRounds(), "Đang lọc ứng viên trùng lặp từ kết quả quét")`.
4. `PrepareReviewContextDelegate`:
   - Gọi `updateWorkflowStep(campaignId, "RUNNING", "AI_REVIEW", "Thẩm định KOC", varData.getSearchRound(), varData.getMaxSearchRounds(), "Đang chạy AI agent chấm điểm tiêu chí KOC")`.
5. `AdvanceSearchRoundDelegate`:
   - Gọi `updateWorkflowStep(campaignId, "RUNNING", "ADVANCING_ROUND", "Chuyển vòng quét", varData.getSearchRound(), varData.getMaxSearchRounds(), "Chuẩn bị vòng quét tiếp theo")`.
6. `SaveKocCandidatesDelegate`:
   - Gọi `updateWorkflowStep(campaignId, "RUNNING", "SAVING_CANDIDATES", "Lưu ứng viên vào DB", varData.getSearchRound(), varData.getMaxSearchRounds(), "Đang lưu trữ danh sách ứng viên đạt chuẩn vào MongoDB")`.

- [x] **Step 5: Chạy lại toàn bộ test suite của delegates**

Run: `mvn test -Dtest=*DelegateTest -f services/ai-agent-mcrs/pom.xml`
Expected: BUILD SUCCESS (100% pass)

- [x] **Step 6: Commit thay đổi JavaDelegates**

```bash
cd services/ai-agent-mcrs
git add src/main/java/com/lamld/aiAgent/modules/workflowprocess/infrastructure/flowable/delegate/ \
        src/test/java/com/lamld/aiAgent/modules/workflowprocess/infrastructure/flowable/delegate/
git commit -m "feat(koc): update campaign step status across Flowable BPMN discovery delegates"
cd ../..
```

---

### Task 4: Frontend Model, Config và i18n

**Files:**
- Modify: `web/dev-tool-web/src/app/features/koc-campaign/models/koc-campaign.model.ts:10-17`
- Modify: `web/dev-tool-web/src/app/features/koc-campaign/models/koc-campaign.config.ts:98-110`
- Modify: `web/dev-tool-web/src/app/core/i18n/features/koc-campaign.i18n.json`

- [x] **Step 1: Cập nhật `KocCampaignItem` trong `koc-campaign.model.ts`**

Bổ sung các trường vào `KocCampaignItem`:
```typescript
  currentStep?: string;
  currentStepTitle?: string;
  currentRound?: number;
  maxRounds?: number;
  stepDetail?: string;
```

- [x] **Step 2: Cập nhật cột `workflowStatus` trong `koc-campaign.config.ts`**

Đổi cột `workflowStatus` thành `type: 'custom'` và mở rộng `minWidth` lên `13rem`:
```typescript
      {
        field: 'workflowStatus',
        header: 'kocCampaign.column.workflowStatus',
        type: 'custom',
        minWidth: '13rem',
      },
```

- [x] **Step 3: Bổ sung từ khóa dịch thuật vào `koc-campaign.i18n.json`**

Thêm các khóa i18n cho Popover & Tooltip chi tiết:
```json
  "kocCampaign.step.popoverTitle": "Chi tiết tiến trình AI",
  "kocCampaign.step.currentStep": "Bước hiện tại",
  "kocCampaign.step.progress": "Tiến độ vòng quét",
  "kocCampaign.step.detail": "Mô tả xử lý",
  "kocCampaign.step.candidates": "Ứng viên đạt chuẩn",
  "kocCampaign.step.runId": "Mã phiên chạy",
  "kocCampaign.step.initializing": "Đang khởi tạo"
```

- [x] **Step 4: Kiểm tra typecheck TypeScript**

Run: `npx tsc --noEmit -p web/dev-tool-web/tsconfig.app.json`
Expected: 0 errors

- [x] **Step 5: Commit thay đổi Model, Config & i18n**

```bash
cd web/dev-tool-web
git add src/app/features/koc-campaign/models/koc-campaign.model.ts \
        src/app/features/koc-campaign/models/koc-campaign.config.ts \
        src/app/core/i18n/features/koc-campaign.i18n.json
git commit -m "feat(fe): update KocCampaignItem model, column config and i18n for step status"
cd ../..
```

---

### Task 5: Triển khai Two-Line Smart Badge và Popover tại `koc-campaign-list`

**Files:**
- Modify: `web/dev-tool-web/src/app/features/koc-campaign/pages/koc-campaign-list/koc-campaign-list.component.html:40-90`
- Modify: `web/dev-tool-web/src/app/features/koc-campaign/pages/koc-campaign-list/koc-campaign-list.component.ts:60-70`
- Test: `web/dev-tool-web/src/app/features/koc-campaign/pages/koc-campaign-list/koc-campaign-list.component.spec.ts`

- [x] **Step 1: Viết failing unit test trong `koc-campaign-list.component.spec.ts`**

Viết test kiểm tra `customTemplates` có `workflowStatus` và render đúng thông tin bước:
```typescript
it('should render detailed two-line status with step title and round in workflowStatus template', () => {
  const testItem: KocCampaignItem = {
    ...mockCampaign,
    workflowStatus: 'RUNNING',
    currentStep: 'AI_SEARCH',
    currentStepTitle: 'Quét tìm KOC',
    currentRound: 1,
    maxRounds: 3,
    stepDetail: 'Đang quét bài đăng Facebook',
  };
  component.campaigns.set([testItem]);
  fixture.detectChanges();

  const compiled = fixture.nativeElement as HTMLElement;
  expect(compiled.textContent).toContain('Quét tìm KOC');
  expect(compiled.textContent).toContain('(Vòng 1/3)');
});
```

- [x] **Step 2: Chạy test để xác nhận test thất bại**

Run: `npm test -- --include="src/app/features/koc-campaign/pages/koc-campaign-list/koc-campaign-list.component.spec.ts" --watch=false`
Expected: FAIL

- [x] **Step 3: Bổ sung `workflowStatusCellTpl` vào `koc-campaign-list.component.html`**

1. Đăng ký template vào `[customTemplates]`:
```html
    [customTemplates]="{
      name: nameCellTpl,
      targetCount: targetsCellTpl,
      approvedKocCount: approvedCellTpl,
      workflowStatus: workflowStatusCellTpl
    }"
```
2. Định nghĩa template `workflowStatusCellTpl`:
```html
  <ng-template #workflowStatusCellTpl let-row="row">
    <div class="flex flex-col gap-1 min-w-0">
      <!-- Dòng 1: Badge trạng thái chính -->
      <div class="flex items-center gap-1.5">
        <app-badge
          [label]="row.workflowStatus || 'UNKNOWN'"
          [variant]="
            row.workflowStatus === 'RUNNING' ? 'info' :
            row.workflowStatus === 'USER_TASK' ? 'warning' :
            row.workflowStatus === 'COMPLETED' ? 'success' :
            row.workflowStatus === 'FAILED' ? 'danger' : 'muted'
          "
          size="sm"
        ></app-badge>

        <!-- Popover trigger chi tiết bước -->
        <button
          type="button"
          class="text-xs text-[var(--app-text-muted)] hover:text-[var(--app-primary)] p-0.5 rounded transition-colors"
          [attr.aria-label]="'kocCampaign.step.popoverTitle' | translateContent"
          (click)="$event.stopPropagation(); activeStepDetail.set(activeStepDetail() === row.id ? null : row.id)"
          [title]="row.stepDetail || row.currentStepTitle || ''"
        >
          <i class="pi pi-info-circle"></i>
        </button>
      </div>

      <!-- Dòng 2: Bước nghiệp vụ chi tiết -->
      <div class="flex items-center gap-1 text-xs text-[var(--app-text-muted)] truncate">
        @if (row.workflowStatus === 'RUNNING') {
          <i class="pi pi-spin pi-spinner text-[var(--app-primary)] text-[10px] shrink-0"></i>
        } @else if (row.workflowStatus === 'USER_TASK') {
          <i class="pi pi-user-edit text-[var(--app-warning)] text-[10px] shrink-0"></i>
        } @else if (row.workflowStatus === 'COMPLETED') {
          <i class="pi pi-check text-[var(--app-success)] text-[10px] shrink-0"></i>
        } @else if (row.workflowStatus === 'FAILED') {
          <i class="pi pi-times-circle text-[var(--app-danger)] text-[10px] shrink-0"></i>
        }

        <span class="font-medium text-[var(--app-text)] truncate">
          {{ row.currentStepTitle || ('kocCampaign.step.initializing' | translateContent) }}
        </span>

        @if (row.currentRound) {
          <span class="text-[var(--app-text-muted)] font-mono shrink-0">
            ({{ row.currentRound }}/{{ row.maxRounds || 3 }})
          </span>
        }
      </div>

      <!-- Popover thả xuống khi click icon info -->
      @if (activeStepDetail() === row.id) {
        <div
          class="p-2.5 mt-1 rounded-md border border-[var(--app-border-soft)] bg-[var(--app-card-surface-strong)] shadow-lg text-xs space-y-1.5 z-20"
          (click)="$event.stopPropagation()"
        >
          <div class="flex items-center justify-between pb-1 border-b border-[var(--app-border-soft)]">
            <span class="font-semibold text-[var(--app-text)]">{{ 'kocCampaign.step.popoverTitle' | translateContent }}</span>
            <button
              type="button"
              class="text-[var(--app-text-muted)] hover:text-[var(--app-text)] p-0.5"
              (click)="activeStepDetail.set(null)"
            >
              <i class="pi pi-times text-[10px]"></i>
            </button>
          </div>
          <div>
            <span class="text-[var(--app-text-muted)]">{{ 'kocCampaign.step.detail' | translateContent }}: </span>
            <span class="text-[var(--app-text)]">{{ row.stepDetail || row.currentStepTitle || '-' }}</span>
          </div>
          <div class="flex items-center justify-between font-mono text-[11px] text-[var(--app-text-muted)] pt-1 border-t border-[var(--app-border-soft)]">
            <span>{{ row.approvedKocCount || 0 }}/{{ row.targetCount || 0 }} KOC</span>
            @if (row.workflowRunId) {
              <div class="flex items-center gap-1">
                <span class="truncate max-w-[80px]">{{ row.workflowRunId }}</span>
                <app-copyable-text [value]="row.workflowRunId"></app-copyable-text>
              </div>
            }
          </div>
        </div>
      }
    </div>
  </ng-template>
```

- [x] **Step 4: Thêm signal `activeStepDetail` vào `KocCampaignListComponent`**

Trong `koc-campaign-list.component.ts`:
```typescript
readonly activeStepDetail = signal<string | null>(null);
```

- [x] **Step 5: Chạy unit test để đảm bảo pass 100%**

Run: `npm test -- --include="src/app/features/koc-campaign/**/*.spec.ts" --watch=false`
Expected: 100% pass

- [x] **Step 6: Commit thay đổi Component & Template**

```bash
cd web/dev-tool-web
git add src/app/features/koc-campaign/pages/koc-campaign-list/koc-campaign-list.component.html \
        src/app/features/koc-campaign/pages/koc-campaign-list/koc-campaign-list.component.ts \
        src/app/features/koc-campaign/pages/koc-campaign-list/koc-campaign-list.component.spec.ts
git commit -m "feat(fe): render two-line status badge with step title and progress popover"
cd ../..
```

---

### Task 6: Viết Playwright E2E Test Kiểm tra Giao diện Thực tế

**Files:**
- Create: `web/dev-tool-web/e2e/koc-campaign-step-status.e2e.spec.ts`

- [x] **Step 1: Viết test Playwright E2E `koc-campaign-step-status.e2e.spec.ts`**

```typescript
import { test, expect } from '@playwright/test';

test.describe('KOC Campaign Detailed Step Status', () => {
  test('should display two-line status badge with step title and toggle progress popover', async ({ page }) => {
    // 1. Mock campaigns list API with step fields
    await page.route(/\/ai-agent-mcrs\/v1\/admin\/koc-campaigns(\?.*)?$/, async (route) => {
      await route.fulfill({
        status: 200,
        contentType: 'application/json',
        body: JSON.stringify({
          status: 200,
          data: [
            {
              id: 'camp-running-01',
              name: 'Chiến dịch FMCG Tết 2026',
              niche: 'FOOD',
              targetCount: 10,
              minScore: 70.0,
              workflowRunId: 'run-fmcg-999',
              workflowStatus: 'RUNNING',
              currentStep: 'AI_SEARCH',
              currentStepTitle: 'Quét tìm KOC',
              currentRound: 2,
              maxRounds: 3,
              stepDetail: 'Đang quét bài đăng Facebook theo từ khóa FMCG',
              approvedKocCount: 4,
              createdAt: '2026-09-08T08:00:00Z',
            },
          ],
          metadata: { totalElements: 1, pageNumber: 0, pageSize: 10 },
        }),
      });
    });

    // 2. Navigate to campaigns page
    await page.goto('/koc/campaigns?dangerously-skip-permissions=true');

    // 3. Verify main RUNNING badge and sub-line step title
    await expect(page.getByText('Chiến dịch FMCG Tết 2026')).toBeVisible({ timeout: 15000 });
    await expect(page.getByText('RUNNING')).toBeVisible();
    await expect(page.getByText('Quét tìm KOC')).toBeVisible();
    await expect(page.getByText('(2/3)')).toBeVisible();

    // 4. Click info icon to open popover
    const infoBtn = page.getByRole('button', { name: /Chi tiết tiến trình AI/i });
    await expect(infoBtn).toBeVisible();
    await infoBtn.click();

    // 5. Verify popover content visible
    await expect(page.getByText('Đang quét bài đăng Facebook theo từ khóa FMCG')).toBeVisible();
    await expect(page.getByText('4/10 KOC')).toBeVisible();
  });
});
```

- [x] **Step 2: Chạy Playwright test local kiểm tra**

Run: `npx playwright test e2e/koc-campaign-step-status.e2e.spec.ts`
Expected: 1 passed

- [x] **Step 3: Dọn dẹp dev server và commit test E2E**

```bash
cd web/dev-tool-web
git add e2e/koc-campaign-step-status.e2e.spec.ts
git commit -m "test(e2e): add Playwright test for campaign two-line step status and popover"
cd ../..
```

---

## 4. Hướng dẫn Thực thi (Execution Options)

Kế hoạch đã sẵn sàng tại `docs/superpowers/plans/2026-09-08-koc-campaign-step-status.md`. Có hai hình thức thực thi:

1. **Subagent-Driven (Khuyến nghị):** Điều phối từng subagent (`dev-be-agent`, `dev-fe-agent`, `test-qa-agent`) triển khai từng task tuần tự kèm review nghiêm ngặt.
2. **Inline Execution:** Thực thi trực tiếp trong phiên làm việc hiện tại, kiểm thử và commit từng bước.
