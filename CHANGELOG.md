# Changelog

Tất cả các thay đổi đáng chú ý của dự án **Powerman** sẽ được ghi lại tại đây theo định dạng [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

## [1.0.0] - 2026-11-16

### Added
- **Phase 6 (General Settings & System Integration):**
  - Xây dựng `MacSystemIntegrationService`: Launch at Login (`SMAppService.mainApp`), App Appearance (`Auto`/`Light`/`Dark`), Low Power Mode + khôi phục độ sáng màn hình (`DisplayServices`), và tự động đóng thông báo pin yếu macOS qua Accessibility (`AXUIElement`).
  - Hoàn thiện `GeneralSettingsView` (Language, Appearance, Launch at Login, System Notifications, Restore Brightness, tùy chỉnh `Alert Bubble Size` & `Screen Edge Glow` kèm khung Preview trực tiếp, thẻ `About Powerman` với thông tin tác giả **Hưng Nguyễn 719**) và công tắc `Low Power Mode` + `Send Us Feedback` trong Popover.
  - Tạo bộ `AppIcon` (`Assets.xcassets`) cho macOS app, bổ sung copyright trong `Info.plist`, và xử lý triệt để toàn bộ cảnh báo Swift 6 Strict Concurrency ở bản dựng `Release`.
  - Bổ sung `GeneralSettingsTests` (3/3 test cases pass) và phát hành phiên bản `1.0.0` (23/23 unit tests pass).
- **Phase 0 (Repo & Documentation):**
  - Thiết lập Git repository, `.gitignore`, GitHub Actions CI (`.github/workflows/ci.yml`).
  - Khởi tạo hệ thống tài liệu bàn giao chuẩn: `README.md`, `CONTRIBUTING.md`, `CHANGELOG.md`, `AGENTS.md`, `docs/ARCHITECTURE.md`, `docs/PROGRESS.md`.
- **Phase 5 (Native Charge Limit 80–100%):**
  - Tạo `ChargeLimitStatus`, `ChargeLimitHelpers` và `NativeChargeLimitService` tích hợp trực tiếp `PowerUISmartChargeClient` (`PowerUI.framework`) để đọc/ghi ngưỡng giới hạn sạc gốc của macOS (80–100%, bước 5%) không cần quyền root.
  - Hoàn thiện tab `Charging` (`ChargingSettingsView`) với công tắc bật/tắt `Charge Limit`, thanh trượt 80–100%, popover giải thích, trạng thái đồng bộ trực tiếp với `System Settings → Battery` và hiển thị `Paused at X% Limit` trong Popover.
  - Bổ sung `ChargeLimitTests` (2/2 test cases pass).
- **Phase 4 (Battery History Charts & Energy Consumers):**
  - Thêm `BatteryHistorySample`, `DailyBatteryUsage`, `BatteryHistoryAnalytics` và `JSONBatteryHistoryStore` tự động lưu lịch sử pin 14 ngày và loại bỏ khoảng ngủ dài (> 15 phút) khi tính mức xả theo ngày.
  - Xây dựng `ProcessEnergyConsumerService` dùng `Darwin.proc_pidinfo` (không cần quyền root) gộp tiến trình con về app mẹ để hiển thị top ứng dụng tiêu thụ năng lượng trong Popover (`Apps Using Significant Energy`).
  - Hoàn thiện tab `Battery` (`BatteryOverviewView`) với biểu đồ **Swift Charts** cho `Battery Level` (`6h`, `12h`, `24h`, `7d`, `14d`), `Daily Usage` và xu hướng `Temperature`.
  - Bổ sung `BatteryHistoryTests` (4/4 test cases pass).
- **Phase 3 (Bluetooth Devices & Menu Bar Pinning):**
  - Thêm model `BluetoothDeviceBattery`, `DeviceCategory` và `DeviceUserPreference` lưu trữ tùy chọn ghim Menu Bar, ẩn khỏi dropdown và ngưỡng cảnh báo riêng theo thiết bị.
  - Xây dựng `BluetoothBatteryService` & `BluetoothBatteryParser` tổng hợp dữ liệu từ `SPBluetoothDataType`, `IORegistry` (`BatteryPercent`), `IOPS` accessories, `IOBluetooth` connect/disconnect notifications và `CoreBluetooth` (`0x180F`).
  - Cập nhật `MenuBarIconView` & `MenuBarController` hiển thị pin các thiết bị đã ghim lên thanh Menu Bar; cập nhật `MenuBarPopoverView` mục `Connected Devices` (xếp pin thấp nhất lên đầu, hiển thị L/R/Case cho AirPods).
  - Hoàn thiện `DevicesSettingsView` (cài cảnh báo pin yếu cho từng thiết bị, ghim Menu Bar, ẩn khỏi Popover) và phần `Device Batteries` trong `MenuBarSettingsView` (thêm thiết bị & sắp xếp thứ tự).
  - Bổ sung `BluetoothBatteryTests` (3/3 test cases pass).
- **Phase 2 (Multi-level Alerts & Visual Overlays):**
  - Thêm model `AlertRule`, `PowerSourceAlertConfig`, `ActiveAlertPresentation` hỗ trợ lưu trữ nhiều mức Low Battery và Charged Alerts.
  - Xây dựng `AlertEngine` với chống lặp (3% hysteresis), cảnh báo cắm/rút sạc (`Plugged In` / `Unplugged`), và tự động ẩn persistent alert khi đổi trạng thái nguồn.
  - Xây dựng `OverlayWindowManager`, `FloatingAlertBubbleView` (vị trí `Top of Screen` / `Center of Screen`), `ScreenBorderGlowView` (viền sáng đa màn hình, nhịp pulse khi `Persistent`), `SystemSoundPlayer` và `SynthesizedSoundGenerator` (8 âm thanh tổng hợp chuyên biệt cho từng trạng thái pin + 14 âm thanh hệ thống macOS).
  - Hoàn thiện `AlertsSettingsView` với thêm/sửa/xóa nhiều quy tắc, thanh trượt %, bảng màu + `ColorPicker`, tùy chọn `Floating Popup`, `Border Glow`, `Persistent`, bộ chọn âm thanh phân nhóm kèm nút nghe thử `🔊`, `Reset Defaults`, khung `Alert Preview` và nút `▶ Test`.
  - Bổ sung `AlertEngineTests` (6/6 test cases pass).
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
