# Thiết kế: Kiến trúc FlowData chuẩn hóa và Logic Assignee theo Người tạo Chiến dịch

## 1. Bối cảnh & Mục tiêu (Context & Motivation)

### 1.1. Hiện trạng
1. **Quản lý biến Flowable phân tán:**
   - Các quy trình BPMN hiện đang lưu trữ và thao tác qua các biến phẳng riêng lẻ trong `DelegateExecution` (ví dụ: `campaignId`, `targetCount`, `searchRound`, `qualifiedCount`, `enoughCandidates`, `roundsRemaining`...).
   - Việc dùng biến phẳng dẫn đến nguy cơ gõ sai tên chuỗi ký tự, thiếu kiểm soát kiểu dữ liệu (type safety), khó bảo trì và không có chuẩn cấu trúc chung giữa các workflow khác nhau trong hệ thống.
2. **Logic Assignee chưa linh hoạt & chưa gắn với người tạo:**
   - Các UserTask trên sơ đồ BPMN (`userTaskDiscoveryDecision`, `userTaskApproveCandidates`) đang gán mặc định cho `"admin"` hoặc lấy từ DTO nếu có.
   - Khi một user tạo chiến dịch, người đó phải là người trực tiếp nhận và xử lý các UserTask (trừ khi có chỉ định người duyệt khác cụ thể).

### 1.2. Mục tiêu cải tiến
1. **Xây dựng cấu trúc `FlowData` dùng chung cho toàn bộ hệ sinh thái Workflow:**
   - Cung cấp class `FlowData<T extends BaseVariableData>` làm đối tượng dữ liệu trung tâm duy nhất cho mọi quy trình Flowable.
   - Bao gồm 2 thành phần chính:
     - `CommonFlowData`: Dữ liệu dùng chung bắt buộc mọi quy trình đều có (ID tiến trình, mã định nghĩa, business key, người tạo, người duyệt, trạng thái, thời gian chạy, thông tin lỗi).
     - `T variableData`: Dữ liệu đặc thù theo từng loại quy trình (ví dụ `KocDiscoveryVariableData` cho quy trình tìm kiếm KOC).
   - **Tuyệt đối hạn chế `Map<String, Object>`:** Tất cả cấu trúc danh sách, lịch sử tìm kiếm, dữ liệu ứng viên đều được định nghĩa bằng các Class/POJO cụ thể (`KocCandidateItem`, `KocSearchHistoryItem`), đảm bảo 100% type-safety và tránh lỗi runtime casting.
2. **Chuẩn hóa logic Assignee:**
   - Người tạo (`creator`) được xác định nghiêm ngặt từ `RequestFilter.getUsername()` tại thời điểm tạo hoặc clone chiến dịch.
   - **Tuyệt đối không fallback:** Nếu không xác định được `creator` (không có token hoặc username rỗng), hệ thống lập tức từ chối với lỗi `UNAUTHORIZED`.
   - `approverAssignee` mặc định gán cho `creator`. Nếu người dùng có truyền `approverAssignee` riêng trong DTO thì ưu tiên theo DTO.
   - Các UserTask trong BPMN 2.0 trỏ trực tiếp đến `${flowData.commonData.approverAssignee}`.

---

## 2. Thiết kế chi tiết Kiến trúc Dữ liệu (`FlowData`)

### 2.1. Cấu trúc Package
Đặt toàn bộ các mô hình dữ liệu workflow trong package:
`com.lamld.aiAgent.modules.workflowprocess.domain.model`

### 2.2. Chi tiết các Class

#### A. `CommonFlowData` (Dữ liệu chung)
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
  private String businessKey; // Ví dụ: campaignId
  private String creator; // RequestFilter.getUsername() - strict, no fallback
  private String approverAssignee; // Người duyệt UserTask
  private String status; // RUNNING, COMPLETED, FAILED
  private Instant startedAt;
  private String lastErrorStage;
  private String lastErrorCode;
  private String lastErrorMessage;
  private Integer lastErrorAtRound;
}
```

#### B. `BaseVariableData` (Lớp trừu tượng cho biến nghiệp vụ)
```java
package com.lamld.aiAgent.modules.workflowprocess.domain.model;

import java.io.Serializable;
import lombok.Data;

/**
 * Base class cho payload biến thiên của từng workflow.
 * Hạn chế tối đa Map<String, Object>, các workflow con khai báo tường minh các trường dữ liệu bằng class cụ thể.
 */
@Data
public abstract class BaseVariableData implements Serializable {
  private static final long serialVersionUID = 1L;
}
```

#### C. `KocSearchHistoryItem` (Lịch sử các lần tìm kiếm)
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

#### D. `KocCandidateItem` (Mô hình dữ liệu ứng viên KOC trong luồng)
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

#### E. `FlowData<T extends BaseVariableData>` (Vỏ bọc dữ liệu tổng)
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

#### F. `KocDiscoveryVariableData` (Biến đặc thù quy trình KOC Discovery)
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

  // Cấu hình tìm kiếm & đánh giá
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

  // Trạng thái vòng lặp thực thi
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
  private String discoveryDecision; // FIND_MORE, STOP
  private String threadId;

  // Ngữ cảnh chống trùng lặp (dùng class cụ thể KocSearchHistoryItem thay vì Map)
  @Builder.Default
  private List<KocSearchHistoryItem> searchHistory = new ArrayList<>();
  @Builder.Default
  private Set<String> seenProfileIds = new HashSet<>();
  @Builder.Default
  private Set<String> seenProfileUrls = new HashSet<>();

  // Tập dữ liệu ứng viên các giai đoạn (dùng class cụ thể KocCandidateItem thay vì Map)
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

---

## 3. Tiện ích Thao tác `FlowableDataUtil`

Tạo class tiện ích tại package:
`com.lamld.aiAgent.modules.workflowprocess.infrastructure.flowable.util.FlowableDataUtil`

Chức năng:
1. `public static final String VAR_FLOW_DATA = "flowData";`
2. `getFlowData(DelegateExecution execution, Class<T> variableClass)`: Đọc đối tượng `FlowData<T>` từ biến execution `flowData`. Nếu chưa có, tự động tạo mới với `commonData` và thể hiện của `variableClass`.
3. `saveFlowData(DelegateExecution execution, FlowData<?> flowData)`: Lưu lại `flowData` vào execution (`execution.setVariable(VAR_FLOW_DATA, flowData)`).
4. `getCommonData(DelegateExecution execution)`: Truy xuất nhanh `CommonFlowData`.
5. `getVariableData(DelegateExecution execution, Class<T> variableClass)`: Truy xuất nhanh `T variableData`.

---

## 4. Cải tiến Logic Khởi tạo & Gán Assignee trong `KocCampaignService`

### 4.1. Quy tắc xác thực người tạo (`creator`)
```java
String creator = RequestFilter.getUsername();
if (CommonUtil.isBlank(creator)) {
  throw new BusinessException(BusinessErrorCode.UNAUTHORIZED, "Người dùng chưa đăng nhập hoặc không xác định được danh tính tạo chiến dịch");
}
```
- Khi tạo chiến dịch mới: Gán `entity.setCreatedBy(creator)`.
- Khi clone chiến dịch: Gán `entity.setCreatedBy(creator)` (người bấm clone là chủ sở hữu chiến dịch mới).

### 4.2. Quy tắc gán Người duyệt (`approverAssignee`)
```java
String approverAssignee = CommonUtil.isNotBlank(dto.getApproverAssignee())
    ? dto.getApproverAssignee().trim()
    : creator;
```

### 4.3. Khởi tạo `FlowData` khi bắt đầu quy trình
Đóng gói sẵn `FlowData<KocDiscoveryVariableData>` vào input map:
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
// Giữ campaignId ở root để tương thích với expression campaignId trên ServiceTask nếu có
input.put("campaignId", campaignId);
```

---

## 5. Cập nhật các JavaDelegate

Toàn bộ các delegate chuyển từ thao tác biến rời rạc sang đọc/ghi qua `FlowData<KocDiscoveryVariableData>`:

1. **`InitializeDiscoveryStateDelegate`:**
   - Lấy `flowData = FlowableDataUtil.getFlowData(execution, KocDiscoveryVariableData.class)`.
   - Cập nhật `commonData.setWorkflowRunId(execution.getProcessInstanceId())`.
   - Cập nhật tức thì `workflowRunId` và `workflowStatus` vào MongoDB `KocCampaignEntity`.
   - Khởi tạo các giá trị mặc định cho `variableData` nếu chưa có và lưu lại bằng `FlowableDataUtil.saveFlowData`.
2. **`PrepareSearchContextDelegate`:**
   - Đọc `searchHistory`, `seenProfileIds`, `niche`, `searchBatchSize` từ `variableData`.
   - Render prompt tìm kiếm và lưu vào biến phục vụ cho `CallActivity` AI Task.
3. **`RecordSearchOutputDelegate`:**
   - Trích xuất keywords, cursors và raw candidates từ output AI, lưu bổ sung vào `variableData.getSearchHistory()` và `variableData.getRawCandidates()`.
4. **`FilterDuplicateCandidatesDelegate`:**
   - Kiểm tra trùng lặp dựa trên `variableData.getSeenProfileIds()` và `variableData.getSeenProfileUrls()`.
   - Cập nhật `variableData.setUniqueCandidates(...)`, `variableData.setHasNewCandidates(...)`.
5. **`PrepareReviewContextDelegate`:**
   - Đọc danh sách ứng viên mới từ `variableData.getUniqueCandidates()`, chuẩn bị prompt đánh giá.
6. **`ProcessReviewResultsDelegate`:**
   - Lọc các ứng viên có điểm >= `minScore`, bổ sung vào `variableData.getQualifiedCandidates()`.
   - Cập nhật `variableData.setQualifiedCount(...)`, `variableData.setEnoughCandidates(...)`.
7. **`AdvanceSearchRoundDelegate`:**
   - Tăng `variableData.setSearchRound(searchRound + 1)`.
   - Tính toán `variableData.setRoundsRemaining(searchRound < maxSearchRounds)`.
8. **`ExtendSearchCycleDelegate`:**
   - Khi admin chọn `FIND_MORE`: tăng thêm `roundLimit` và `roundsRemaining = true` trong `variableData`.
9. **`SaveKocCandidatesDelegate`:**
   - Đọc `variableData.getQualifiedCandidates()`, lưu vào MongoDB qua `KocCandidateStorage`.
   - Lưu `variableData.setSavedCandidateIds(...)`.
10. **`UpdateCampaignStatusDelegate`:**
    - Cập nhật trạng thái workflow tương ứng lên `KocCampaignEntity`.

---

## 6. Cập nhật sơ đồ BPMN 2.0 (`koc_candidate_discovery_process.bpmn20.xml`)

### 6.1. UserTask Assignees
Chuyển toàn bộ gán assignee sang `flowData.commonData.approverAssignee`:
```xml
<userTask id="userTaskDiscoveryDecision" 
          name="Decision: Find More or Stop" 
          flowable:assignee="${flowData.commonData.approverAssignee}" />

<userTask id="userTaskApproveCandidates" 
          name="Human Approval - Select KOC Candidates" 
          flowable:assignee="${flowData.commonData.approverAssignee}" />
```

### 6.2. Gateway Condition Expressions
Chuyển các biểu thức rẽ nhánh sang đọc thuộc tính của `flowData.variableData`:
- Lỗi đăng nhập:
  `${flowData.variableData.loginRequired == true}`
- Có ứng viên mới:
  `${flowData.variableData.hasNewCandidates == true}`
- Đã đủ ứng viên:
  `${flowData.variableData.enoughCandidates == true}`
- Còn lượt tìm kiếm:
  `${flowData.variableData.roundsRemaining == true}`
- Quyết định tìm tiếp:
  `${flowData.variableData.discoveryDecision == 'FIND_MORE'}`
- Quyết định dừng lại:
  `${flowData.variableData.discoveryDecision == 'STOP'}`

---

## 7. Kế hoạch Kiểm thử & Xác minh (Verification Plan)

### 7.1. Unit Tests
1. **`FlowDataTest` & `FlowableDataUtilTest`:**
   - Kiểm tra serialization / deserialization của `FlowData<KocDiscoveryVariableData>`.
   - Kiểm tra `getFlowData` tự khởi tạo instance an toàn khi execution chưa có biến.
2. **`KocCampaignServiceTest`:**
   - Test tạo chiến dịch khi có `RequestFilter.getUsername()`: Gán `createdBy = username`, `approverAssignee = username`.
   - Test tạo chiến dịch khi `RequestFilter.getUsername()` trả về null/rỗng: Ném `BusinessException(UNAUTHORIZED)`.
   - Test tạo chiến dịch có override `approverAssignee`: Giữ đúng assignee được chỉ định.
   - Test clone chiến dịch: Người clone trở thành `createdBy` và `approverAssignee` của chiến dịch mới.
3. **Delegates Unit Tests:**
   - Cập nhật các mock `DelegateExecution` trong các bài test delegate để trả về `flowData` và assert dữ liệu được cập nhật đúng trong `flowData`.

### 7.2. Integration & Engine Tests
1. **`FlowableKocCandidateDiscoveryWorkflowTest`:**
   - Chạy kiểm thử toàn bộ 12 test cases của workflow engine với BPMN XML mới và `FlowData`.
   - Đảm bảo 100% test case pass, các gateway rẽ nhánh chính xác theo biểu thức `${flowData.variableData.*}`.
