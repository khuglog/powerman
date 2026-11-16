# Powerman

**Powerman** là ứng dụng quản lý pin toàn diện cho macOS (Menu Bar + Settings Window), được xây dựng bằng Swift & SwiftUI.

## Tính năng chính

- **Cảnh báo pin thông minh (Alerts):** Tạo nhiều mức cảnh báo khi pin yếu (Low Battery), khi sạc đạt ngưỡng (Charged) và khi cắm/rút sạc. Hỗ trợ tùy chọn âm thanh, popup nổi (Top/Center), hiệu ứng phát sáng viền màn hình (Border Glow), chế độ cảnh báo ngắn hoặc liên tục (Persistent) và tùy biến màu sắc.
- **Tùy biến Menu Bar & Thiết bị Bluetooth:** Chọn nhiều kiểu hiển thị pin trên Menu Bar (`Battery Indicator`, `Minimal`, `Powerman Logo`), màu sắc theo trạng thái, và hiển thị phần trăm pin của các thiết bị Bluetooth đã pair (AirPods, chuột, bàn phím, v.v.).
- **Giới hạn sạc (Charge Limit):** Giới hạn mức sạc từ 80% đến 100% nhằm bảo vệ tuổi thọ pin lâu dài.
- **Thống kê & Sức khỏe pin (Battery Health):** Theo dõi % sức khỏe pin, nhiệt độ, số chu kỳ sạc (`CycleCount`), dung lượng thực tế vs thiết kế (`mAh`) và biểu đồ lịch sử sử dụng.

## Yêu cầu hệ thống

- **macOS:** macOS 15.0+ (phát triển & kiểm thử trên macOS 27.0.1 / Apple Silicon)
- **Xcode:** Xcode 16+ (khuyến nghị Xcode 27.2)
- **Phân phối:** Non-sandboxed macOS app (Direct distribution) để truy cập đầy đủ `IOKit`, `Bluetooth`, `Overlay Windows` và `Charge Limit`.

## Bắt đầu nhanh (Build & Test)

```bash
# Clone repository
git clone https://github.com/khuglog/powerman.git
cd powerman

# Build bằng Xcode CLI
xcodebuild -project Powerman.xcodeproj -scheme Powerman -configuration Debug build

# Chạy Unit Tests
xcodebuild test -project Powerman.xcodeproj -scheme Powerman -destination 'platform=macOS'
```

Hoặc mở trực tiếp `Powerman.xcodeproj` bằng Xcode và nhấn `Cmd + R`.

## Tài liệu dự án (Bắt buộc đọc khi nhận bàn giao)

| Tài liệu | Mục đích |
| :--- | :--- |
| [docs/PROGRESS.md](docs/PROGRESS.md) | **Trạng thái tiến độ hiện tại**, checklist từng Phase, việc đã làm & bước tiếp theo |
| [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) | Kiến trúc hệ thống, luồng dữ liệu, chi tiết kỹ thuật IOKit / SMC / Bluetooth / Overlays |
| [CONTRIBUTING.md](CONTRIBUTING.md) | Quy chuẩn nhánh Git, Conventional Commits, quy tắc code Swift và cập nhật tài liệu |
| [CHANGELOG.md](CHANGELOG.md) | Lịch sử các phiên bản và thay đổi theo từng Phase |
| [AGENTS.md](AGENTS.md) | Hướng dẫn dành riêng cho AI Coding Agents khi tiếp nhận dự án |

## Tác giả & Liên hệ (Author & Contact)

- **Tác giả:** Hưng Nguyễn 719
- **Email:** [hungnq719@gmail.com](mailto:hungnq719@gmail.com)
- **Điện thoại:** +84793334555

