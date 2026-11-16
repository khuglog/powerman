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
  - Bổ sung `BatteryInfoTests` kiểm tra logic parse dữ liệu IOKit (bao gồm cấu trúc `BatteryData` và `AppleSmartBatteryPack` trên Apple Silicon) và cài đặt Menu Bar.

### Fixed
- **Menu Bar Color Modes (`Auto`, `Monochrome`, `White`, `Black`):** Chế độ `Monochrome` thực sự ép hiển thị đơn sắc chuẩn template (tắt màu trạng thái xanh/cam/đỏ), đồng thời bổ sung tùy chọn ép màu `White` và `Black` kèm Preview tương ứng.
- **Menu Bar Contrast:** Nhận diện `effectiveAppearance` (Dark/Light Menu Bar) cho `NSStatusItem` và dùng cutout (`destinationOut`) / nền tương phản cao trong `MenuBarIconView` để số % luôn hiển thị rõ ràng.
- **Apple Silicon Battery Telemetry:** Đọc thêm từ `BatteryData` lồng bên trong `AppleSmartBattery` và node con `AppleSmartBatteryPack` để lấy chính xác `Health %`, `Capacity (mAh)`, `Temperature (°C)` (centi-Celsius) và `Power Draw (W)`.
