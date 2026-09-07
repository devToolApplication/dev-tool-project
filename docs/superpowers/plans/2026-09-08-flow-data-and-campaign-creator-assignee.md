# Kế hoạch triển khai: Kiến trúc FlowData chuẩn hóa và Logic Assignee theo Người tạo Chiến dịch

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Chuẩn hóa toàn bộ dữ liệu thực thi Flowable qua cấu trúc `FlowData<T>` (gồm `CommonFlowData` và `KocDiscoveryVariableData` sử dụng các POJO `KocCandidateItem`, `KocSearchHistoryItem` thay vì `Map<String, Object>`), và gán `approverAssignee` nghiêm ngặt theo người tạo chiến dịch (`RequestFilter.getUsername()`).

**Architecture:** 
- Xây dựng tầng Domain Model độc lập cho Workflow Process (`FlowData`, `CommonFlowData`, `BaseVariableData`, `KocDiscoveryVariableData`, `KocCandidateItem`, `KocSearchHistoryItem`).
- Cung cấp tiện ích `FlowableDataUtil` đọc/ghi type-safe `FlowData` từ `DelegateExecution`.
- Chuyển đổi toàn bộ các Flowable JavaDelegates sang thao tác trên `FlowData<KocDiscoveryVariableData>`.
- Cập nhật sơ đồ BPMN 2.0 UEL Expressions sang cú pháp `${flowData.commonData.*}` và `${flowData.variableData.*}`.
- Cập nhật `KocCampaignService` lấy `creator` từ `RequestFilter.getUsername()` không fallback (ném `UNAUTHORIZED` nếu thiếu), gán `approverAssignee` và khởi tạo `FlowData` ban đầu.

**Tech Stack:** Java 21, Spring Boot 3.5, Flowable BPMN 2.0 Engine 7.2.0, MongoDB, JUnit 5, Mockito.

---

### Task 1: Xây dựng các POJO và Domain Models cho `FlowData`

**Files:**
- Create: `services/ai-agent-mcrs/src/main/java/com/lamld/aiAgent/modules/workflowprocess/domain/model/CommonFlowData.java`
- Create: `services/ai-agent-mcrs/src/main/java/com/lamld/aiAgent/modules/workflowprocess/domain/model/BaseVariableData.java`
- Create: `services/ai-agent-mcrs/src/main/java/com/lamld/aiAgent/modules/workflowprocess/domain/model/KocSearchHistoryItem.java`
- Create: `services/ai-agent-mcrs/src/main/java/com/lamld/aiAgent/modules/workflowprocess/domain/model/KocCandidateItem.java`
- Create: `services/ai-agent-mcrs/src/main/java/com/lamld/aiAgent/modules/workflowprocess/domain/model/FlowData.java`
- Create: `services/ai-agent-mcrs/src/main/java/com/lamld/aiAgent/modules/workflowprocess/domain/model/KocDiscoveryVariableData.java`
- Test: `services/ai-agent-mcrs/src/test/java/com/lamld/aiAgent/modules/workflowprocess/domain/model/FlowDataTest.java`

- [ ] **Step 1: Viết Unit Test cho `FlowData` và các Model**

Tạo file `services/ai-agent-mcrs/src/test/java/com/lamld/aiAgent/modules/workflowprocess/domain/model/FlowDataTest.java`:
```java
package com.lamld.aiAgent.modules.workflowprocess.domain.model;

import static org.junit.jupiter.api.Assertions.*;

import java.io.ByteArrayInputStream;
import java.io.ByteArrayOutputStream;
import java.io.ObjectInputStream;
import java.io.ObjectOutputStream;
import java.time.Instant;
import java.util.List;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

class FlowDataTest {

  @Test
  @DisplayName("FlowData và các thành phần phải serialize/deserialize an toàn")
  void flowData_shouldSerializeAndDeserializeSuccessfully() throws Exception {
    CommonFlowData commonData = CommonFlowData.builder()
        .workflowRunId("run-123")
        .workflowDefinitionId("koc-discovery-v2")
        .businessKey("camp-456")
        .creator("lamld")
        .approverAssignee("lamld")
        .status("RUNNING")
        .startedAt(Instant.now())
        .build();

    KocSearchHistoryItem historyItem = KocSearchHistoryItem.builder()
        .round(1)
        .keyword("review cong nghe")
        .cursorUsed(null)
        .nextCursor("cur-1")
        .build();

    KocCandidateItem candidateItem = KocCandidateItem.builder()
        .externalProfileId("fb_1001")
        .fullName("Nguyen Van A")
        .profileUrl("https://facebook.com/koc1")
        .platform("FACEBOOK")
        .followerCount(50000L)
        .engagementRate(4.5)
        .score(85.0)
        .isQualified(true)
        .strengths(List.of("Tech reviewer uy tin"))
        .risks(List.of("It tuong tac story"))
        .reviewNote("Dat chuan")
        .build();

    KocDiscoveryVariableData variableData = KocDiscoveryVariableData.builder()
        .campaignId("camp-456")
        .targetCount(5)
        .minScore(70.0)
        .searchBatchSize(10)
        .maxSearchRounds(3)
        .searchRound(1)
        .qualifiedCount(1)
        .enoughCandidates(false)
        .roundsRemaining(true)
        .searchHistory(List.of(historyItem))
        .qualifiedCandidates(List.of(candidateItem))
        .build();

    FlowData<KocDiscoveryVariableData> flowData = FlowData.<KocDiscoveryVariableData>builder()
        .commonData(commonData)
        .variableData(variableData)
        .build();

    ByteArrayOutputStream baos = new ByteArrayOutputStream();
    try (ObjectOutputStream oos = new ObjectOutputStream(baos)) {
      oos.writeObject(flowData);
    }

    byte[] bytes = baos.toByteArray();
    FlowData<?> restored;
    try (ObjectInputStream ois = new ObjectInputStream(new ByteArrayInputStream(bytes))) {
      restored = (FlowData<?>) ois.readObject();
    }

    assertNotNull(restored);
    assertEquals("lamld", restored.getCommonData().getCreator());
    assertEquals("camp-456", restored.getCommonData().getBusinessKey());
    assertTrue(restored.getVariableData() instanceof KocDiscoveryVariableData);

    KocDiscoveryVariableData restoredVar = (KocDiscoveryVariableData) restored.getVariableData();
    assertEquals(1, restoredVar.getQualifiedCount());
    assertEquals("fb_1001", restoredVar.getQualifiedCandidates().get(0).getExternalProfileId());
    assertEquals("review cong nghe", restoredVar.getSearchHistory().get(0).getKeyword());
  }
}
```

- [ ] **Step 2: Chạy test để xác nhận test fail do chưa có class**

Run:
```bash
cd services/ai-agent-mcrs && mvn test -Dtest=FlowDataTest
```
Expected: FAIL do compilation error (chưa tồn tại các class trong `domain.model`).

- [ ] **Step 3: Tạo các class mô hình dữ liệu trong `domain.model`**

1. Tạo file `services/ai-agent-mcrs/src/main/java/com/lamld/aiAgent/modules/workflowprocess/domain/model/CommonFlowData.java`:
```java
package com.lamld.aiAgent.modules.workflowprocess.domain.model;

import java.io.Serializable;
import java.time.Instant;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class CommonFlowData implements Serializable {
  private static final long serialVersionUID = 1L;

  private String workflowRunId;
  private String workflowDefinitionId;
  private String businessKey;
  private String creator;
  private String approverAssignee;
  private String status;
  private Instant startedAt;
  private String lastErrorStage;
  private String lastErrorCode;
  private String lastErrorMessage;
  private Integer lastErrorAtRound;
}
```

2. Tạo file `services/ai-agent-mcrs/src/main/java/com/lamld/aiAgent/modules/workflowprocess/domain/model/BaseVariableData.java`:
```java
package com.lamld.aiAgent.modules.workflowprocess.domain.model;

import java.io.Serializable;
import lombok.Data;

/**
 * Base class cho payload biến thiên của từng workflow.
 * Bắt buộc các workflow con khai báo tường minh các trường dữ liệu bằng class cụ thể,
 * hạn chế tối đa sử dụng Map<String, Object>.
 */
@Data
public abstract class BaseVariableData implements Serializable {
  private static final long serialVersionUID = 1L;
}
```

3. Tạo file `services/ai-agent-mcrs/src/main/java/com/lamld/aiAgent/modules/workflowprocess/domain/model/KocSearchHistoryItem.java`:
```java
package com.lamld.aiAgent.modules.workflowprocess.domain.model;

import java.io.Serializable;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class KocSearchHistoryItem implements Serializable {
  private static final long serialVersionUID = 1L;

  private Integer round;
  private String keyword;
  private String cursorUsed;
  private String nextCursor;
}
```

4. Tạo file `services/ai-agent-mcrs/src/main/java/com/lamld/aiAgent/modules/workflowprocess/domain/model/KocCandidateItem.java`:
```java
package com.lamld.aiAgent.modules.workflowprocess.domain.model;

import java.io.Serializable;
import java.util.ArrayList;
import java.util.List;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class KocCandidateItem implements Serializable {
  private static final long serialVersionUID = 1L;

  private String externalProfileId;
  private String fullName;
  private String profileUrl;
  private String platform;
  private Long followerCount;
  private Double engagementRate;
  private String niche;
  private Double score;
  private Boolean isQualified;

  @Builder.Default
  private List<String> strengths = new ArrayList<>();

  @Builder.Default
  private List<String> risks = new ArrayList<>();

  private String reviewNote;
}
```

5. Tạo file `services/ai-agent-mcrs/src/main/java/com/lamld/aiAgent/modules/workflowprocess/domain/model/FlowData.java`:
```java
package com.lamld.aiAgent.modules.workflowprocess.domain.model;

import java.io.Serializable;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class FlowData<T extends BaseVariableData> implements Serializable {
  private static final long serialVersionUID = 1L;

  @Builder.Default
  private CommonFlowData commonData = new CommonFlowData();

  private T variableData;
}
```

6. Tạo file `services/ai-agent-mcrs/src/main/java/com/lamld/aiAgent/modules/workflowprocess/domain/model/KocDiscoveryVariableData.java`:
```java
package com.lamld.aiAgent.modules.workflowprocess.domain.model;

import java.util.ArrayList;
import java.util.HashSet;
import java.util.List;
import java.util.Set;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.EqualsAndHashCode;
import lombok.NoArgsConstructor;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
@EqualsAndHashCode(callSuper = true)
public class KocDiscoveryVariableData extends BaseVariableData {
  private static final long serialVersionUID = 1L;

  private String campaignId;
  private String niche;
  private Integer targetCount;
  private Double minScore;
  private Integer searchBatchSize;
  private Integer maxSearchRounds;
  private Integer roundLimit;
  private String accountType;
  private String tag;
  private String searchPrompt;
  private String reviewPrompt;
  private String searchOutputSchema;
  private String reviewOutputSchema;

  @Builder.Default
  private Integer searchRound = 0;
  @Builder.Default
  private Integer qualifiedCount = 0;
  @Builder.Default
  private Boolean hasNewCandidates = false;
  @Builder.Default
  private Boolean enoughCandidates = false;
  @Builder.Default
  private Boolean roundsRemaining = true;
  @Builder.Default
  private Boolean loginRequired = false;
  private String discoveryDecision;
  private String threadId;

  @Builder.Default
  private List<KocSearchHistoryItem> searchHistory = new ArrayList<>();
  @Builder.Default
  private Set<String> seenProfileIds = new HashSet<>();
  @Builder.Default
  private Set<String> seenProfileUrls = new HashSet<>();

  @Builder.Default
  private List<KocCandidateItem> rawCandidates = new ArrayList<>();
  @Builder.Default
  private List<KocCandidateItem> uniqueCandidates = new ArrayList<>();
  @Builder.Default
  private List<KocCandidateItem> reviewedCandidates = new ArrayList<>();
  @Builder.Default
  private List<KocCandidateItem> qualifiedCandidates = new ArrayList<>();
  @Builder.Default
  private List<String> savedCandidateIds = new ArrayList<>();
}
```

- [ ] **Step 4: Chạy lại test để xác nhận test pass 100%**

Run:
```bash
cd services/ai-agent-mcrs && mvn test -Dtest=FlowDataTest
```
Expected: `BUILD SUCCESS`, `Tests run: 1, Failures: 0, Errors: 0, Skipped: 0`.

- [ ] **Step 5: Commit**

```bash
git add services/ai-agent-mcrs/src/main/java/com/lamld/aiAgent/modules/workflowprocess/domain/model/
git add services/ai-agent-mcrs/src/test/java/com/lamld/aiAgent/modules/workflowprocess/domain/model/FlowDataTest.java
git commit -m "feat(workflow): add strongly-typed FlowData and KOC domain models"
```

---

### Task 2: Tạo Tiện ích `FlowableDataUtil`

**Files:**
- Create: `services/ai-agent-mcrs/src/main/java/com/lamld/aiAgent/modules/workflowprocess/infrastructure/flowable/util/FlowableDataUtil.java`
- Test: `services/ai-agent-mcrs/src/test/java/com/lamld/aiAgent/modules/workflowprocess/infrastructure/flowable/util/FlowableDataUtilTest.java`

- [ ] **Step 1: Viết Unit Test cho `FlowableDataUtil`**

Tạo file `services/ai-agent-mcrs/src/test/java/com/lamld/aiAgent/modules/workflowprocess/infrastructure/flowable/util/FlowableDataUtilTest.java`:
```java
package com.lamld.aiAgent.modules.workflowprocess.infrastructure.flowable.util;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;

import com.lamld.aiAgent.modules.workflowprocess.domain.model.CommonFlowData;
import com.lamld.aiAgent.modules.workflowprocess.domain.model.FlowData;
import com.lamld.aiAgent.modules.workflowprocess.domain.model.KocDiscoveryVariableData;
import org.flowable.engine.delegate.DelegateExecution;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

class FlowableDataUtilTest {

  @Test
  @DisplayName("getFlowData khởi tạo instance mới an toàn khi execution chưa có biến")
  void getFlowData_shouldInitializeDefaultWhenNull() {
    DelegateExecution execution = mock(DelegateExecution.class);
    when(execution.getVariable(FlowableDataUtil.VAR_FLOW_DATA)).thenReturn(null);

    FlowData<KocDiscoveryVariableData> flowData =
        FlowableDataUtil.getFlowData(execution, KocDiscoveryVariableData.class);

    assertNotNull(flowData);
    assertNotNull(flowData.getCommonData());
    assertNotNull(flowData.getVariableData());
    verify(execution).setVariable(eq(FlowableDataUtil.VAR_FLOW_DATA), eq(flowData));
  }

  @Test
  @DisplayName("getFlowData trả về đúng FlowData đã có sẵn trong execution")
  void getFlowData_shouldReturnExistingFlowData() {
    DelegateExecution execution = mock(DelegateExecution.class);
    CommonFlowData common = CommonFlowData.builder().creator("lamld").build();
    KocDiscoveryVariableData var = KocDiscoveryVariableData.builder().campaignId("c-1").build();
    FlowData<KocDiscoveryVariableData> existing = FlowData.<KocDiscoveryVariableData>builder()
        .commonData(common)
        .variableData(var)
        .build();

    when(execution.getVariable(FlowableDataUtil.VAR_FLOW_DATA)).thenReturn(existing);

    FlowData<KocDiscoveryVariableData> result =
        FlowableDataUtil.getFlowData(execution, KocDiscoveryVariableData.class);

    assertSame(existing, result);
    assertEquals("lamld", result.getCommonData().getCreator());
    assertEquals("c-1", result.getVariableData().getCampaignId());
  }

  @Test
  @DisplayName("saveFlowData lưu đúng đối tượng vào execution")
  void saveFlowData_shouldSetVariable() {
    DelegateExecution execution = mock(DelegateExecution.class);
    FlowData<KocDiscoveryVariableData> flowData = new FlowData<>();

    FlowableDataUtil.saveFlowData(execution, flowData);

    verify(execution).setVariable(FlowableDataUtil.VAR_FLOW_DATA, flowData);
  }
}
```

- [ ] **Step 2: Chạy test để xác nhận test fail do chưa có class**

Run:
```bash
cd services/ai-agent-mcrs && mvn test -Dtest=FlowableDataUtilTest
```
Expected: FAIL do compilation error.

- [ ] **Step 3: Triển khai `FlowableDataUtil`**

Tạo file `services/ai-agent-mcrs/src/main/java/com/lamld/aiAgent/modules/workflowprocess/infrastructure/flowable/util/FlowableDataUtil.java`:
```java
package com.lamld.aiAgent.modules.workflowprocess.infrastructure.flowable.util;

import com.lamld.aiAgent.modules.workflowprocess.domain.model.BaseVariableData;
import com.lamld.aiAgent.modules.workflowprocess.domain.model.CommonFlowData;
import com.lamld.aiAgent.modules.workflowprocess.domain.model.FlowData;
import lombok.extern.slf4j.Slf4j;
import org.flowable.engine.delegate.DelegateExecution;

@Slf4j
public final class FlowableDataUtil {

  public static final String VAR_FLOW_DATA = "flowData";

  private FlowableDataUtil() {
    // Utility class
  }

  @SuppressWarnings("unchecked")
  public static <T extends BaseVariableData> FlowData<T> getFlowData(
      DelegateExecution execution,
      Class<T> variableClass
  ) {
    if (execution == null) {
      throw new IllegalArgumentException("execution cannot be null");
    }

    Object raw = execution.getVariable(VAR_FLOW_DATA);
    if (raw instanceof FlowData<?> existing) {
      if (existing.getVariableData() != null && variableClass.isInstance(existing.getVariableData())) {
        return (FlowData<T>) existing;
      }
      if (existing.getVariableData() == null) {
        try {
          FlowData<T> typed = (FlowData<T>) existing;
          typed.setVariableData(variableClass.getDeclaredConstructor().newInstance());
          return typed;
        } catch (Exception e) {
          log.error("Failed to instantiate variableClass: {}", variableClass.getName(), e);
        }
      }
    }

    T variableData = null;
    try {
      variableData = variableClass.getDeclaredConstructor().newInstance();
    } catch (Exception e) {
      log.error("Failed to instantiate variableClass: {}", variableClass.getName(), e);
    }

    FlowData<T> newFlowData = FlowData.<T>builder()
        .commonData(new CommonFlowData())
        .variableData(variableData)
        .build();

    execution.setVariable(VAR_FLOW_DATA, newFlowData);
    return newFlowData;
  }

  public static void saveFlowData(DelegateExecution execution, FlowData<?> flowData) {
    if (execution == null) {
      throw new IllegalArgumentException("execution cannot be null");
    }
    execution.setVariable(VAR_FLOW_DATA, flowData);
  }

  public static CommonFlowData getCommonData(DelegateExecution execution) {
    Object raw = execution.getVariable(VAR_FLOW_DATA);
    if (raw instanceof FlowData<?> flowData && flowData.getCommonData() != null) {
      return flowData.getCommonData();
    }
    return new CommonFlowData();
  }

  public static <T extends BaseVariableData> T getVariableData(
      DelegateExecution execution,
      Class<T> variableClass
  ) {
    FlowData<T> flowData = getFlowData(execution, variableClass);
    return flowData.getVariableData();
  }
}
```

- [ ] **Step 4: Chạy test để xác nhận test pass**

Run:
```bash
cd services/ai-agent-mcrs && mvn test -Dtest=FlowableDataUtilTest
```
Expected: `BUILD SUCCESS`, `Tests run: 3, Failures: 0, Errors: 0, Skipped: 0`.

- [ ] **Step 5: Commit**

```bash
git add services/ai-agent-mcrs/src/main/java/com/lamld/aiAgent/modules/workflowprocess/infrastructure/flowable/util/FlowableDataUtil.java
git add services/ai-agent-mcrs/src/test/java/com/lamld/aiAgent/modules/workflowprocess/infrastructure/flowable/util/FlowableDataUtilTest.java
git commit -m "feat(workflow): add FlowableDataUtil for type-safe flowData management"
```

---

### Task 3: Cập nhật `KocCampaignService` - Gán Assignee theo Creator & Đóng gói `FlowData`

**Files:**
- Modify: `services/ai-agent-mcrs/src/main/java/com/lamld/aiAgent/modules/koccampaign/application/KocCampaignService.java`
- Modify: `services/ai-agent-mcrs/src/test/java/com/lamld/aiAgent/modules/koccampaign/application/KocCampaignServiceTest.java`

- [ ] **Step 1: Viết Unit Test cho Creator & Assignee trong `KocCampaignServiceTest`**

Cập nhật `services/ai-agent-mcrs/src/test/java/com/lamld/aiAgent/modules/koccampaign/application/KocCampaignServiceTest.java`:
Thêm test cases:
1. `createAndStart_withoutUser_throwsUnauthorizedException`: Khi `RequestFilter.getUsername()` trả về null/empty -> Ném `BusinessException(UNAUTHORIZED)`.
2. `createAndStart_withLoggedInUser_setsCreatedByAndDefaultApproverAssignee`: Khi có user `lamld`, `entity.getCreatedBy()` nhận `"lamld"`, `flowData.getCommonData().getApproverAssignee()` nhận `"lamld"`.
3. `createAndStart_withCustomApproverAssignee_keepsCustomAssignee`: Khi DTO truyền `approverAssignee = "manager"`, `flowData.getCommonData().getApproverAssignee()` nhận `"manager"`, còn `creator` vẫn là `"lamld"`.

- [ ] **Step 2: Chạy test để xác nhận test fail**

Run:
```bash
cd services/ai-agent-mcrs && mvn test -Dtest=KocCampaignServiceTest
```
Expected: FAIL do chưa cập nhật validation `creator` và đóng gói `FlowData`.

- [ ] **Step 3: Cập nhật `KocCampaignService.java`**

Cập nhật method `createAndStart` trong `services/ai-agent-mcrs/src/main/java/com/lamld/aiAgent/modules/koccampaign/application/KocCampaignService.java`:
```java
    // 1. Xác thực người tạo nghiêm ngặt (không fallback)
    String creator = RequestFilter.getUsername();
    if (CommonUtil.isBlank(creator)) {
      throw new BusinessException(BusinessErrorCode.UNAUTHORIZED, "Người dùng chưa đăng nhập hoặc không xác định được danh tính tạo chiến dịch");
    }

    String approverAssignee = CommonUtil.isNotBlank(dto.getApproverAssignee())
        ? dto.getApproverAssignee().trim()
        : creator;

    entity.setCreatedBy(creator);
```
Và trong phần đóng gói biến input khởi tạo workflow:
```java
        CommonFlowData commonData = CommonFlowData.builder()
            .businessKey(campaignId)
            .creator(creator)
            .approverAssignee(approverAssignee)
            .status("RUNNING")
            .startedAt(Instant.now())
            .build();

        KocDiscoveryVariableData variableData = KocDiscoveryVariableData.builder()
            .campaignId(campaignId)
            .niche(saved.getNiche())
            .targetCount(saved.getTargetCount())
            .minScore(saved.getMinScore())
            .searchBatchSize(saved.getSearchBatchSize())
            .maxSearchRounds(saved.getMaxSearchRounds())
            .roundLimit(saved.getMaxSearchRounds())
            .accountType("FACEBOOK")
            .tag("DISCOVERY")
            .searchPrompt(saved.getSearchPrompt())
            .reviewPrompt(saved.getReviewPrompt())
            .build();

        FlowData<KocDiscoveryVariableData> flowData = FlowData.<KocDiscoveryVariableData>builder()
            .commonData(commonData)
            .variableData(variableData)
            .build();

        Map<String, Object> input = new HashMap<>();
        input.put(FlowableDataUtil.VAR_FLOW_DATA, flowData);
        input.put("campaignId", campaignId);
```

- [ ] **Step 4: Chạy test để xác nhận pass**

Run:
```bash
cd services/ai-agent-mcrs && mvn test -Dtest=KocCampaignServiceTest
```
Expected: `BUILD SUCCESS`, 100% tests pass.

- [ ] **Step 5: Commit**

```bash
git add services/ai-agent-mcrs/src/main/java/com/lamld/aiAgent/modules/koccampaign/application/KocCampaignService.java
git add services/ai-agent-mcrs/src/test/java/com/lamld/aiAgent/modules/koccampaign/application/KocCampaignServiceTest.java
git commit -m "feat(koc): enforce campaign creator assignee and initialize FlowData payload"
```

---

### Task 4: Cập nhật các JavaDelegates trong Discovery Workflow sang dùng `FlowData`

**Files:**
- Modify: `services/ai-agent-mcrs/src/main/java/com/lamld/aiAgent/modules/workflowprocess/infrastructure/flowable/delegate/InitializeDiscoveryStateDelegate.java`
- Modify: `services/ai-agent-mcrs/src/main/java/com/lamld/aiAgent/modules/workflowprocess/infrastructure/flowable/delegate/PrepareSearchContextDelegate.java`
- Modify: `services/ai-agent-mcrs/src/main/java/com/lamld/aiAgent/modules/workflowprocess/infrastructure/flowable/delegate/RecordSearchOutputDelegate.java`
- Modify: `services/ai-agent-mcrs/src/main/java/com/lamld/aiAgent/modules/workflowprocess/infrastructure/flowable/delegate/FilterDuplicateCandidatesDelegate.java`
- Modify: `services/ai-agent-mcrs/src/main/java/com/lamld/aiAgent/modules/workflowprocess/infrastructure/flowable/delegate/PrepareReviewContextDelegate.java`
- Modify: `services/ai-agent-mcrs/src/main/java/com/lamld/aiAgent/modules/workflowprocess/infrastructure/flowable/delegate/ProcessReviewResultsDelegate.java`
- Modify: `services/ai-agent-mcrs/src/main/java/com/lamld/aiAgent/modules/workflowprocess/infrastructure/flowable/delegate/AdvanceSearchRoundDelegate.java`
- Modify: `services/ai-agent-mcrs/src/main/java/com/lamld/aiAgent/modules/workflowprocess/infrastructure/flowable/delegate/ExtendSearchCycleDelegate.java`
- Modify: `services/ai-agent-mcrs/src/main/java/com/lamld/aiAgent/modules/workflowprocess/infrastructure/flowable/delegate/SaveKocCandidatesDelegate.java`
- Modify: `services/ai-agent-mcrs/src/main/java/com/lamld/aiAgent/modules/workflowprocess/infrastructure/flowable/delegate/UpdateCampaignStatusDelegate.java`
- Test: Cập nhật tương ứng các delegate test trong `services/ai-agent-mcrs/src/test/java/com/lamld/aiAgent/modules/workflowprocess/infrastructure/flowable/delegate/`

- [ ] **Step 1: Cập nhật `InitializeDiscoveryStateDelegate`**

1. Đọc `flowData = FlowableDataUtil.getFlowData(execution, KocDiscoveryVariableData.class)`.
2. Đồng bộ `commonData.setWorkflowRunId(execution.getProcessInstanceId())` và `commonData.setStatus("RUNNING")`.
3. Lưu `workflowRunId` vào MongoDB qua `campaignStorage`.
4. Đảm bảo các thuộc tính `KocDiscoveryVariableData` được khởi tạo giá trị mặc định (`searchRound = 0`, `searchHistory = new ArrayList<>()`, `seenProfileIds = new HashSet<>()`...).
5. Gọi `FlowableDataUtil.saveFlowData(execution, flowData)`.

- [ ] **Step 2: Cập nhật `PrepareSearchContextDelegate` & `RecordSearchOutputDelegate`**

1. `PrepareSearchContextDelegate`:
   - Lấy `varData = FlowableDataUtil.getVariableData(execution, KocDiscoveryVariableData.class)`.
   - Đọc `searchHistory`, `seenProfileIds`, `niche` từ `varData` để xây dựng prompt tìm kiếm.
2. `RecordSearchOutputDelegate`:
   - Phân tích output JSON từ AI search.
   - Thêm từng lượt search vào `varData.getSearchHistory().add(new KocSearchHistoryItem(...))` (dùng POJO, không dùng Map).
   - Chuyển đổi candidates từ output JSON thành `List<KocCandidateItem>` và gán vào `varData.setRawCandidates(...)`.
   - Cập nhật `varData.getSeenProfileIds().add(profileId)` và `varData.getSeenProfileUrls().add(url)`.
   - Lưu lại qua `FlowableDataUtil.saveFlowData(execution, flowData)`.

- [ ] **Step 3: Cập nhật `FilterDuplicateCandidatesDelegate`**

1. Lọc danh sách `varData.getRawCandidates()` dựa trên `varData.getSeenProfileIds()` và `varData.getSeenProfileUrls()`.
2. Gán kết quả vào `varData.setUniqueCandidates(uniqueList)`.
3. Cập nhật `varData.setHasNewCandidates(!uniqueList.isEmpty())`.

- [ ] **Step 4: Cập nhật `PrepareReviewContextDelegate` & `ProcessReviewResultsDelegate`**

1. `PrepareReviewContextDelegate`:
   - Đọc danh sách `varData.getUniqueCandidates()` (danh sách `KocCandidateItem`).
   - Tạo prompt đánh giá chi tiết cho từng ứng viên.
2. `ProcessReviewResultsDelegate`:
   - Parse kết quả chấm điểm từ AI review.
   - Cập nhật điểm `score`, `isQualified`, `reviewNote` trực tiếp vào từng `KocCandidateItem`.
   - Thêm ứng viên đạt chuẩn vào `varData.getQualifiedCandidates()`.
   - Cập nhật `varData.setQualifiedCount(...)`.
   - Cập nhật `varData.setEnoughCandidates(qualifiedCount >= targetCount)`.

- [ ] **Step 5: Cập nhật `AdvanceSearchRoundDelegate` & `ExtendSearchCycleDelegate`**

1. `AdvanceSearchRoundDelegate`:
   - `varData.setSearchRound(varData.getSearchRound() + 1)`.
   - `varData.setRoundsRemaining(varData.getSearchRound() < varData.getRoundLimit())`.
2. `ExtendSearchCycleDelegate`:
   - Khi `discoveryDecision == 'FIND_MORE'`: tăng `roundLimit` thêm `searchBatchSize` hoặc 2 rounds, set `roundsRemaining = true`.

- [ ] **Step 6: Cập nhật `SaveKocCandidatesDelegate` & `UpdateCampaignStatusDelegate`**

1. `SaveKocCandidatesDelegate`:
   - Đọc `varData.getQualifiedCandidates()` (danh sách `KocCandidateItem`), map sang `KocCandidateEntity` và lưu vào MongoDB.
   - Lưu `varData.setSavedCandidateIds(...)`.
2. `UpdateCampaignStatusDelegate`:
   - Cập nhật trạng thái chiến dịch trên MongoDB từ `flowData.getCommonData().getStatus()`.

- [ ] **Step 7: Chạy toàn bộ Unit Tests cho các Delegate**

Run:
```bash
cd services/ai-agent-mcrs && mvn test -Dtest=*DelegateTest
```
Expected: `BUILD SUCCESS`, 100% tests pass.

- [ ] **Step 8: Commit**

```bash
git add services/ai-agent-mcrs/src/main/java/com/lamld/aiAgent/modules/workflowprocess/infrastructure/flowable/delegate/
git add services/ai-agent-mcrs/src/test/java/com/lamld/aiAgent/modules/workflowprocess/infrastructure/flowable/delegate/
git commit -m "refactor(workflow): update all discovery delegates to use FlowData and typed POJOs"
```

---

### Task 5: Cập nhật Sơ đồ BPMN 2.0 (`koc_candidate_discovery_process.bpmn20.xml`)

**Files:**
- Modify: `services/ai-agent-mcrs/src/main/resources/processes/koc_candidate_discovery_process.bpmn20.xml`

- [ ] **Step 1: Cập nhật Assignee cho các UserTask**

1. `userTaskDiscoveryDecision`:
```xml
<userTask id="userTaskDiscoveryDecision" name="Decision: Find More or Stop" flowable:assignee="${flowData.commonData.approverAssignee}" />
```

2. `userTaskApproveCandidates`:
```xml
<userTask id="userTaskApproveCandidates" name="Human Approval - Select KOC Candidates" flowable:assignee="${flowData.commonData.approverAssignee}" />
```

- [ ] **Step 2: Cập nhật Expression cho các Gateway**

1. `gwCheckLoginRequired`:
   - Nhánh Login: `${flowData.variableData.loginRequired == true}`
   - Nhánh Tiếp tục: `default="f_no_login_needed"`
2. `gwCheckNewCandidates`:
   - Nhánh Có ứng viên: `${flowData.variableData.hasNewCandidates == true}`
   - Nhánh Không có: `default="f_no_new_candidates"`
3. `gwCheckEnoughCandidates`:
   - Nhánh Đủ: `${flowData.variableData.enoughCandidates == true}`
   - Nhánh Chưa đủ: `default="f_not_enough_candidates"`
4. `gwCheckRoundsRemaining`:
   - Nhánh Còn lượt: `${flowData.variableData.roundsRemaining == true}`
   - Nhánh Hết lượt: `default="f_out_of_rounds"`
5. `gwCheckDiscoveryDecision`:
   - Nhánh Tìm tiếp: `${flowData.variableData.discoveryDecision == 'FIND_MORE'}`
   - Nhánh Dừng: `default="f_decision_stop"`

- [ ] **Step 3: Commit**

```bash
git add services/ai-agent-mcrs/src/main/resources/processes/koc_candidate_discovery_process.bpmn20.xml
git commit -m "refactor(bpmn): update UEL expressions to reference FlowData and campaign creator assignee"
```

---

### Task 6: Kiểm thử toàn diện Workflow Engine (Integration Tests)

**Files:**
- Modify: `services/ai-agent-mcrs/src/test/java/com/lamld/aiAgent/modules/workflowprocess/application/admin/FlowableKocCandidateDiscoveryWorkflowTest.java`

- [ ] **Step 1: Cập nhật mock setup và assertions trong `FlowableKocCandidateDiscoveryWorkflowTest`**

1. Cập nhật khởi tạo biến ban đầu khi start process instance trong test: Đưa `FlowData<KocDiscoveryVariableData>` vào variables map.
2. Cập nhật mock outputs của các service task để kiểm tra các gateway rẽ nhánh chính xác dựa trên `${flowData.variableData.*}`.
3. Assert các UserTask `userTaskDiscoveryDecision` và `userTaskApproveCandidates` nhận đúng `assignee` từ `flowData.getCommonData().getApproverAssignee()`.

- [ ] **Step 2: Chạy toàn bộ 12 test cases của Workflow Test**

Run:
```bash
cd services/ai-agent-mcrs && mvn test -Dtest=FlowableKocCandidateDiscoveryWorkflowTest
```
Expected:
```
[INFO] Tests run: 12, Failures: 0, Errors: 0, Skipped: 0
[INFO] BUILD SUCCESS
```

- [ ] **Step 3: Chạy toàn bộ test suite của `ai-agent-mcrs`**

Run:
```bash
cd services/ai-agent-mcrs && mvn test
```
Expected: 100% tests pass, không có lỗi hồi quy.

- [ ] **Step 4: Commit**

```bash
git add services/ai-agent-mcrs/src/test/java/com/lamld/aiAgent/modules/workflowprocess/application/admin/FlowableKocCandidateDiscoveryWorkflowTest.java
git commit -m "test(workflow): update engine integration test suite for FlowData architecture"
```

---

## Tự đánh giá Kế hoạch (Self-Review)

1. **Spec Coverage:**
   - [x] Tạo `CommonFlowData` và `FlowData<T extends BaseVariableData>`.
   - [x] Loại bỏ `Map<String, Object>`, thay thế bằng các POJO cụ thể `KocCandidateItem` và `KocSearchHistoryItem`.
   - [x] Tiện ích `FlowableDataUtil` đọc/ghi type-safe.
   - [x] `KocCampaignService`: Lấy `creator = RequestFilter.getUsername()` không fallback (ném `UNAUTHORIZED`), gán `entity.setCreatedBy(creator)` và `approverAssignee`.
   - [x] Cập nhật toàn bộ các JavaDelegates trong quy trình KOC Discovery.
   - [x] Cập nhật UEL Expressions trên sơ đồ BPMN 2.0.
   - [x] Unit test và Engine integration test 100% bao phủ.
2. **Placeholder Scan:** Không chứa các từ khóa cấm ("TBD", "TODO", "implement later"). Toàn bộ code snippets, assertions và lệnh chạy đều cụ thể.
3. **Type Consistency:** Tên class, tên trường dữ liệu (`commonData`, `variableData`, `approverAssignee`, `KocCandidateItem`, `KocSearchHistoryItem`) hoàn toàn đồng nhất giữa các task.
