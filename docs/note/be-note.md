# Backend (BE) Development Notes & Lessons Learned

Tài liệu ghi nhớ các lỗi sai và quy chuẩn kiến trúc bắt buộc khi phát triển tính năng trên Backend Spring Boot (`ai-agent-mcrs`, `job-service`, `develop-tool-core-lib`...).

---

## 1. Kế thừa `BaseService` & Sử dụng `MapperUtil`
- **Sai lầm:**
  - Tự viết hàm thủ công `mapToResponse(...)` hoặc dùng `BeanUtils.copyProperties` trong Service.
  - Không kế thừa `BaseService`.
- **Quy chuẩn chuẩn hóa:**
  - Tất cả các Service class PHẢI `extends BaseService` từ `vn.devTool.core.base.BaseService`.
  - Tận dụng `mapperUtil` được inject sẵn trong `BaseService`:
    - Entity to Response: `mapperUtil.map(entity, ResponseDto.class)`
    - Update entity from DTO: `mapperUtil.mapTo(dto, entity)`
    - List mapping: `mapperUtil.mapList(list, ResponseDto.class)`
    - Page mapping: `mapperUtil.mapPage(page, ResponseDto.class)`

---

## 2. Kiến trúc 3 lớp với Storage Layer (`Storage`)
- **Sai lầm:** Service gọi trực tiếp `Repository` mà bỏ qua tầng `Storage`.
- **Quy chuẩn chuẩn hóa:**
  - **Entity & Repository:** `infrastructure/entity` và `infrastructure/repository`.
  - **Storage:** `infrastructure/storage/{Module}Storage.java` đóng vai trò trung gian giữa Service và Data Access. Storage đóng gói các query phức tạp bằng `MongoTemplate` kết hợp `Repository` (find, filter query regex/criteria, pagination, count).
  - **Service:** Chỉ tương tác với `Storage` (ví dụ: `AccountStorage`), không inject trực tiếp `Repository` vào Service.

---

## 3. Quản lý Exception & Error Codes chuẩn
- **Sai lầm:**
  - Tự tạo hoặc import sai package exception (ví dụ: `vn.devTool.core.exceptions.NotFoundException` không tồn tại, sai package `BusinessErrorCode`).
- **Quy chuẩn:**
  - Dùng `BusinessException` từ `vn.devTool.core.exceptions.BusinessException`.
  - Dùng `BusinessErrorCode` từ `vn.devTool.core.base.type.BusinessErrorCode` (ví dụ: `BusinessErrorCode.DATA_NOT_FOUND`, `BusinessErrorCode.BAD_REQUEST`).

---

## 4. File Encoding trên môi trường Windows
- **Sai lầm:** Tạo file mới bằng script có dính UTF-8 BOM (`\ufeff`), gây lỗi compile Java `illegal character: '\ufeff'`.
- **Quy chuẩn:** Luôn xuất file dạng UTF-8 No BOM (`new System.Text.UTF8Encoding($false)`).