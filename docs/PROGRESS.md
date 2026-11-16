# Theo dõi Tiến độ & Bàn giao Dự án (PROGRESS)

> **Dành cho nhân sự hoặc AI model mới tiếp nhận:** Đọc file này đầu tiên để biết dự án đang ở đâu, các tính năng nào đã chạy ổn định và bước tiếp theo cần làm ngay.

- **Cập nhật lần cuối:** 2026-11-16
- **Giai đoạn hiện tại (Current Phase):** Hoàn thành **Phase 0 & Phase 1** (đã fix Menu Bar contrast & Apple Silicon `BatteryData`/`AppleSmartBatteryPack` telemetry) — Sẵn sàng chuyển sang **Phase 2**
- **Nhánh chính:** `main`
- **Trạng thái Build / Test:** `TEST SUCCEEDED` (5/5 test cases trong `BatteryInfoTests` pass, `SWIFT_STRICT_CONCURRENCY = complete`)

---

## 1. Tổng quan Lộ trình & Trạng thái

| Phase | Tên giai đoạn | Trạng thái | Ghi chú |
| :--- | :--- | :--- | :--- |
| **Phase 0** | Khởi tạo Repo, GitHub & Tài liệu chuẩn | ✅ Hoàn thành | Git, GitHub (`khuglog/powerman`), CI, Docs bàn giao |
| **Phase 1** | Core Battery (`IOKit`) + Menu Bar & Popover | ✅ Hoàn thành | Đọc pin thật, Menu Bar 3 style, Popover, Settings Menu Bar |
| **Phase 2** | Hệ thống Cảnh báo đa mức (`Alerts` + Glow + Popup) | ⏳ Chưa bắt đầu | Low/Charged/Power rules, Overlay multi-screen, Sound, Preview |
| **Phase 3** | Thiết bị Bluetooth (`Devices`) & Ghim Menu Bar | ⏳ Chưa bắt đầu | IOBluetooth/IORegistry/BLE, Pin lên Menu Bar, Ẩn/Cảnh báo riêng |
| **Phase 4** | Sức khỏe pin & Biểu đồ lịch sử (`Battery` + SwiftData) | ⏳ Chưa bắt đầu | Lưu lịch sử nền, Charts `6h`–`14d`, Daily Usage, Top Energy Apps |
| **Phase 5** | Giới hạn sạc 80–100% (`Charge Limit`) | ⏳ Chưa bắt đầu | Kiểm chứng Native Charge Limit trên macOS 27 vs SMC Helper |
| **Phase 6** | General Settings, Tiện ích hệ thống & Đóng gói | ⏳ Chưa bắt đầu | Đa ngôn ngữ, Launch at Login, Dismiss macOS notif, DMG/Notarize |

---

## 2. Checklist Chi tiết

### Phase 0: GitHub & Tài liệu Bàn giao
- [x] Khởi tạo `.gitignore`, `README.md`, `CONTRIBUTING.md`, `CHANGELOG.md`, `AGENTS.md`
- [x] Viết `docs/ARCHITECTURE.md` và `docs/PROGRESS.md`
- [x] Thiết lập GitHub Actions CI (`.github/workflows/ci.yml`)
- [x] Khởi tạo Git local, tạo repo GitHub (`khuglog/powerman`) và push lần đầu

### Phase 1: Core Battery & Menu Bar
- [x] Tạo `Powerman.xcodeproj` (Target `Powerman` non-sandboxed `LSUIElement = YES` + Target `PowermanTests`, Swift Strict Concurrency `complete`)
- [x] Xây dựng `BatteryInfo` & `BatterySnapshotParser` (chuẩn hóa dữ liệu `IOPS` & `AppleSmartBattery`)
- [x] Xây dựng `IOKitBatteryService` (event-driven qua `IOPSNotificationCreateRunLoopSource` + timer fallback 30s)
- [x] Xây dựng `AppState`, `AppDelegate`, `MenuBarController` (`NSStatusItem` + `NSPopover`) & `MenuBarIconView`
- [x] Hoàn thiện `MenuBarPopoverView` & `SettingsRootView` (Tab `Menu Bar` đầy đủ với Live Preview + Tab `Battery` hiển thị KPI & Live Telemetry)
- [x] Viết & chạy pass `PowermanTests` (`BatteryInfoTests`: 5/5 tests passed, bao gồm test `BatteryData` & `AppleSmartBatteryPack` trên Apple Silicon)

### Phase 2: Hệ thống Cảnh báo (`Alerts`) — *Kế tiếp*
- [ ] Tạo model `AlertRule` (Low Battery, Charged, Power Source), lưu bằng `UserDefaults`/JSON
- [ ] Xây dựng `AlertEngine` có cơ chế hysteresis (chống lặp cảnh báo khi dao động ±1%)
- [ ] Xây dựng `OverlayWindowManager` hỗ trợ đa màn hình:
  - [ ] `ScreenBorderGlowView` (viền sáng toàn màn hình theo màu, chế độ tĩnh/nhịp thở khi Persistent)
  - [ ] `FloatingAlertBubbleView` (vị trí `Top of Screen` hoặc `Center of Screen`, nút đóng `X`)
- [ ] Xây dựng `SoundPlayer` (âm thanh ngắn & lặp liên tục khi `Persistent = true`)
- [ ] Hoàn thiện `AlertsSettingsView` (CRUD nhiều rule, slider %, bảng màu, vị trí, Test Preview)

---

## 3. Danh sách File Trọng tâm Hiện tại

- `Powerman/Models/BatteryInfo.swift` — Model dữ liệu pin + `BatterySnapshotParser`
- `Powerman/Models/AppSettings.swift` — Cấu hình Menu Bar & lưu trữ `UserDefaults`
- `Powerman/Services/Battery/IOKitBatteryService.swift` — Protocol `BatteryMonitoring` & implementation IOKit
- `Powerman/App/AppState.swift` — State trung tâm (`@Observable @MainActor`)
- `Powerman/App/AppDelegate.swift` — Quản lý vòng đời Menu Bar & Settings Window
- `Powerman/UI/MenuBar/MenuBarController.swift` & `MenuBarIconView.swift` — Render icon Menu Bar Retina & quản lý Popover
- `Powerman/UI/MenuBar/MenuBarPopoverView.swift` — Giao diện dropdown khi bấm Menu Bar
- `Powerman/UI/Settings/SettingsRootView.swift`, `MenuBarSettingsView.swift`, `BatteryOverviewView.swift` — Cửa sổ Settings
- `PowermanTests/BatteryInfoTests.swift` — Unit tests cho parser và persistence

---

## 4. Bước tiếp theo cần làm ngay (Next Immediate Steps)

1. Bắt đầu **Phase 2**: tạo `Models/AlertRule.swift`, `Services/Alerts/AlertEngine.swift`, `Services/Alerts/OverlayWindowManager.swift`, `Services/Alerts/SoundPlayer.swift`.
2. Hoàn thiện `UI/Overlays/FloatingAlertBubbleView.swift` & `ScreenBorderGlowView.swift`.
3. Thay thế placeholder tab `Alerts` trong `SettingsRootView` bằng `AlertsSettingsView` đầy đủ (thêm/sửa/xóa rule, chọn màu, vị trí Top/Center, âm thanh, Border Glow, Persistent, Test Preview).

---

## 5. Ghi chú Kỹ thuật & Known Issues

- **Xcode Build trên môi trường bị sandbox (như Seatbelt):** `swift-plugin-server` (phục vụ macro `@Observable`) yêu cầu chạy `xcodebuild` ngoài sandbox nếu gặp lỗi macro plugin server.
- **Nhiệt độ & dung lượng Apple Silicon:** `BatterySnapshotParser` đã xử lý chuẩn hóa `AppleRawMaxCapacity` (tránh nhầm với `MaxCapacity = 100`) và `Temperature` centi-Kelvin; khuyến nghị mở `Powerman.app` trực tiếp để quan sát số đo thực tế trên `Mac15,6`.
