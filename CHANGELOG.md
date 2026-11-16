# Changelog

Tất cả các thay đổi đáng chú ý của dự án **Powerman** sẽ được ghi lại tại đây theo định dạng [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

### Added
- **Phase 0 (Repo & Documentation):**
  - Thiết lập Git repository, `.gitignore`, GitHub Actions CI (`.github/workflows/ci.yml`).
  - Khởi tạo hệ thống tài liệu bàn giao chuẩn: `README.md`, `CONTRIBUTING.md`, `CHANGELOG.md`, `AGENTS.md`, `docs/ARCHITECTURE.md`, `docs/PROGRESS.md`.
- **Phase 1 (Core Battery & Menu Bar):**
  - Khởi tạo Xcode project `Powerman.xcodeproj` (Target `Powerman` non-sandboxed `LSUIElement` + Target `PowermanTests`).
  - Xây dựng `IOKitBatteryService` đọc thông số thực từ `IOPS` & `AppleSmartBattery` (%, trạng thái sạc, thời gian còn lại, dung lượng mAh, % sức khỏe, chu kỳ, nhiệt độ, điện áp/công suất, thông tin adapter).
  - Xây dựng `MenuBarController` (`NSStatusItem` + `NSPopover`) hỗ trợ 3 kiểu icon (`Battery Indicator`, `Minimal`, `Powerman Logo`), tùy chỉnh nội dung hiển thị, kích thước và màu trạng thái.
  - Xây dựng `MenuBarPopoverView` và cửa sổ `SettingsRootView` với tab `Menu Bar` hoàn chỉnh (có Live Preview) và khung xem nhanh `Battery`.
  - Bổ sung `BatteryInfoTests` kiểm tra logic parse dữ liệu IOKit, tính sức khỏe pin và cài đặt Menu Bar.
