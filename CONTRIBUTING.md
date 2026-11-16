# Hướng dẫn đóng góp & Quy chuẩn phát triển (CONTRIBUTING)

Tài liệu này quy định tiêu chuẩn làm việc để đảm bảo tính nhất quán khi nhiều nhân sự hoặc AI model cùng phát triển **Powerman**.

## 1. Quy trình Git & Branching

- `main`: Nhánh ổn định, luôn build xanh và pass toàn bộ tests.
- Nhánh tính năng theo từng Phase hoặc feature:
  - `feat/phase-1-core-menubar`
  - `feat/phase-2-alerts`
  - `fix/<ten-loi>`
  - `docs/<noi-dung>`

### Quy chuẩn Commit (Conventional Commits)
Sử dụng tiền tố rõ ràng:
- `feat:` Thêm tính năng mới (ví dụ: `feat(alerts): add multi-screen border glow overlay`)
- `fix:` Sửa lỗi
- `docs:` Cập nhật tài liệu (`README.md`, `PROGRESS.md`, `ARCHITECTURE.md`, ...)
- `refactor:` Tái cấu trúc mã nguồn không đổi hành vi
- `test:` Thêm hoặc sửa unit/UI tests
- `chore:` Cấu hình build, CI, `.gitignore`

## 2. Quy chuẩn Code Swift / SwiftUI

- **Kiến trúc:** MVVM nhẹ kết hợp `@Observable` (`AppState` làm trung tâm điều phối), tách biệt rõ tầng `Services` (IOKit/AppKit/System) khỏi `UI` (SwiftUI).
- **Testability:** Mọi service giao tiếp phần cứng/hệ điều hành (như `IOKitBatteryService`, `ChargeLimitService`, `BluetoothBatteryService`) phải đi qua `protocol` để có thể viết Unit Test bằng mock data mà không phụ thuộc phần cứng thật.
- **Concurrency:** Tuân thủ Swift Concurrency (`@MainActor` cho UI state & AppKit window operations; tách các tác vụ đọc `IOKit` / SQLite an toàn).
- **Tài nguyên & Nền:** Powerman là app chạy nền trên Menu Bar (`LSUIElement = YES`), tuyệt đối tránh polling dày đặc gây hao pin. Ưu tiên event-driven (`IOPSNotificationCreateRunLoopSource`, notification) và timer tối thiểu.

## 3. Quy tắc Bàn giao & Cập nhật Tiến độ (Bắt buộc)

Mỗi khi hoàn thành một task lớn hoặc kết thúc một Phase, người thực hiện (hoặc AI agent) **bắt buộc** phải cập nhật trước khi commit:
1. Cập nhật checklist, ngày cập nhật, commit mới nhất và mục *Next Immediate Steps* trong [docs/PROGRESS.md](docs/PROGRESS.md).
2. Ghi nhận thay đổi vào mục `[Unreleased]` hoặc version tương ứng trong [CHANGELOG.md](CHANGELOG.md).
3. Nếu có thay đổi về module, luồng dữ liệu hoặc quyết định kỹ thuật, cập nhật [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md).
4. Chạy `xcodebuild build` và `xcodebuild test` đảm bảo pass 100%.
