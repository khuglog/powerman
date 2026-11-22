# Changelog

Tất cả các thay đổi đáng chú ý của dự án **Powerman** sẽ được ghi lại tại đây theo định dạng [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

## [1.0.2] - 2026-11-22

### Added
- **Đa ngôn ngữ bằng String Catalog (`Localizable.xcstrings`, `Localization.swift`, `AppLanguageOption`):**
  - Bổ sung `Localizable.xcstrings` hỗ trợ 9 ngôn ngữ phổ biến (`en`, `vi`, `ja`, `ko`, `zh-Hans`, `zh-Hant`, `fr`, `de`, `es`) cùng tùy chọn `Match System`, cập nhật `knownRegions` trong `Powerman.xcodeproj` và bản địa hóa toàn bộ chuỗi UI, Menu Bar Popover, Settings và Alerts với cơ chế đổi ngôn ngữ tức thì trong ứng dụng (`L10n`).
  - Bổ sung unit test `GeneralSettingsTests.testLocalizationResolvesPopularLanguages`.
- **Tạm thời vượt giới hạn sạc trong lượt sạc (`MenuBarPopoverView`, `ChargingSettingsView`, `AppState`, `ChargeLimitState`):**
  - Thêm nút bấm nhanh một chạm ngay trong Menu Bar Popover (`Override Charge Limit Once`) khi `Charge Limit` đang bật — bấm vào sẽ kích hoạt ngay lập tức không hỏi xác nhận và hiển thị 1 dòng thông báo trạng thái đang tạm thời vượt giới hạn sạc trong lần sạc này (kèm nút `Restore` nhanh).
  - Thêm mục cấu hình `Temporary Limit Override` trong tab `Charging` với 2 tùy chọn kết thúc tự động: **Ngay khi rút bộ sạc** (`onUnplug`, mặc định) hoặc **Khi đạt 100% pin lần đầu** (`onFirstFullCharge`).
  - Bổ sung 2 unit tests trong `ChargeLimitTests` kiểm tra cả hai điều kiện kết thúc và khôi phục thủ công.

### Changed
- **Thanh tiến trình pin Popover (`SegmentedBatteryProgressBar`):** Đổi vạch chia từ 4 phần (mốc 25%) sang **5 phần bằng nhau** (4 vạch chia tại các mốc 20%, 40%, 60%, 80%).

### Fixed
- **Floating Alert Popup Transparent Background (`FloatingAlertBubbleView`, `OverlayWindowManager`):** Loại bỏ `.shadow` tràn viền bị cắt vuông bởi khung `NSPanel` (`masksToBounds`) phía dưới viên thuốc thông báo (`Capsule`), áp dụng `.clipShape(Capsule(style: .continuous))` và ép layer của `NSHostingController` / `contentView` trong suốt hoàn toàn (`alpha = 0` ở toàn bộ vùng ngoài `Capsule`).

## [1.0.1] - 2026-11-17

### Fixed
- **Instant Green Charging Status on Plug-in (`MenuBarIconView`, `AppState`, `MenuBarController`):**
  - Bỏ trạng thái phụ chờ đàm phán USB-C; chuyển sang hiển thị **trạng thái đang sạc (Xanh lá + `⚡`) ngay tức thì (`t = 0s`)** khi cắm nguồn (`battery.isPluggedIn || battery.isCharging`) đồng thời với thông báo nổi `"Power Connected"` qua callback đồng bộ `onMenuBarUpdate`.
  - Loại bỏ `GeometryReader` trong `minimalPillIndicator` (`MenuBarIconView`) để `ImageRenderer` luôn vẽ đầy đủ thanh màu xanh lá ngay ở lần render đầu tiên.
- **Menu Bar Replicant Redraw CPU Spike (`AppearanceObserverView`):** Loại bỏ vòng lặp vẽ lại vô hạn `NSStatusItem _redrawReplicantSnapshot` gây nghẽn Main Thread (`87%` CPU), bổ sung `MenuBarController.RenderSignature` để chỉ render lại `ImageRenderer` khi dữ liệu hiển thị hoặc appearance thực sự thay đổi.
- **Charge Limit Re-enable (`Off → On`):** Sửa lỗi `AppState.setChargeLimitEnabled(true)` và `NativeChargeLimitService.setEnabled` truyền lại giá trị `100` sau khi `disableMCL:` reset ngưỡng hệ thống về `100` (khiến macOS tắt ngược Charge Limit ngay lập tức); lưu `lastActiveChargeLimit` (80–95%) để bật lại chính xác mức giới hạn trước đó, kèm guard trong `ChargingSettingsView` (nâng lên build `4`).

## [1.0.0] - 2026-11-16

### Fixed
- **Instant Menu Bar Status & Appearance Response:**
  - `IOKitBatteryService`: Đăng ký trực tiếp thông báo nhân macOS `IOServiceAddInterestNotification` (`kIOGeneralInterest`) trên `AppleSmartBattery` / `AppleSmartBatteryPack`, bổ sung `IOPSCreateLimitedPowerNotification`, chạy mọi nguồn RunLoop & timer trên `.commonModes`, theo dõi `NSWorkspace.didWakeNotification`, gộp sự kiện telemetry nhiễu (`hasVisualOrStatusChange` vs `hasTelemetryChange`), và kiểm tra xác nhận chuyển tiếp USB-PD sau 1s/2.5s khi cắm/rút nguồn để cập nhật tức thì thay vì chờ timer dự phòng.
  - `BatterySnapshotParser` (`BatteryInfo`): Ưu tiên đọc trực tiếp cờ `IsCharging` và `FullyCharged` từ kernel IORegistry (`AppleSmartBattery`) trước cache `IOPS` (`powerd`), cùng 2 unit tests mới trong `BatteryInfoTests` (tổng 25/25 unit tests pass).
  - `MenuBarController`: Thêm `AppearanceObserverView` (`viewDidChangeEffectiveAppearance`), `activeSpaceDidChangeNotification` và scale theo màn hình đang hiển thị `statusItem` để màu nền Light/Dark Menu Bar cập nhật tức thì.
- **Final Functional & Visual UI Audit:**
  - `SettingsRootView`: Thay `List(.sidebar)` bằng custom sidebar dùng màu sRGB cố định cho badge và màu nhãn tương phản theo `colorScheme`, sửa triệt để lỗi trắng hóa badge và lỗi chữ tối trên nền Dark Mode.
  - `MenuBarIconView`: Cải tiến render pill `Minimal` với hai lớp chữ tương phản cắt mặt nạ theo `%` (vẫn giữ alpha `destinationOut` cho `isTemplateMode`), giúp chữ số hiển thị sắc nét trong cả Menu Bar tối, sáng và Live Preview.
  - `DevicesSettingsView`: Ẩn mũi tên thừa của `Menu` chuông cảnh báo (`.menuIndicator(.hidden)`) và bọc nền tròn `28x28` đồng nhất với các nút Pin và Ẩn/Hiện.
  - `BatteryOverviewView`: Chỉ định tường minh `AxisMarks` & `AxisValueLabel(anchor:)` (`timeXAxisMarks`) cho các biểu đồ Swift Charts (`Battery Level`, `Daily Usage`, `Temperature`), loại bỏ hoàn toàn cảnh báo runtime về `UnitPoint`.
- **Final Pre-release Review & Polish:**
  - Khắc phục rò rỉ `NSEvent` global monitor trong `MenuBarController` khi `NSPopover` tự đóng qua `NSPopoverDelegate`, dùng `preferredContentSize` để mở rộng accordion mượt mà, và tự động đóng popover khi bấm `Settings...` / `Battery Settings...` / `Send Us Feedback`.
  - Bổ sung debounced track-click & keyboard handler cho thanh trượt `Charge Limit` trong `ChargingSettingsView`.
  - Cập nhật trạng thái quyền Accessibility tức thì khi quay lại từ System Settings (`didBecomeActiveNotification`) trong `GeneralSettingsView` và reset `isRefreshing` trong `BluetoothBatteryService.stopMonitoring()`.
- **CI Test Runner (`ci.yml` & `AppDelegate.swift`):** Bỏ qua khởi tạo Bluetooth/IOKit/MenuBar khi chạy dưới dạng `TEST_HOST` của `XCTest` (tránh treo hộp thoại quyền Bluetooth trên macOS runner) và bật ad-hoc signing (`CODE_SIGN_IDENTITY="-"`) trong GitHub Actions CI để nhúng hợp lệ entitlements.

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
