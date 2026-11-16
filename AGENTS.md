# AGENTS.md — Hướng dẫn cho AI Coding Agents & Nhân sự mới

Tệp này cung cấp ngữ cảnh nhanh và quy tắc bắt buộc khi tiếp nhận công việc trên dự án **Powerman**.

## 1. Bước đầu tiên khi bắt đầu phiên làm việc

1. Đọc [docs/PROGRESS.md](docs/PROGRESS.md) để nắm **Phase hiện tại**, những gì đã hoàn thành, và **Next Immediate Steps**.
2. Đọc [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) để hiểu cấu trúc module, các `protocol` service và quyết định kỹ thuật (ADRs).
3. Kiểm tra trạng thái Git (`git status`, `git log -n 5`).

## 2. Lệnh kiểm tra chuẩn (Build & Test)

```bash
# Build Debug
xcodebuild -project Powerman.xcodeproj -scheme Powerman -configuration Debug build

# Chạy toàn bộ Unit Tests
xcodebuild test -project Powerman.xcodeproj -scheme Powerman -destination 'platform=macOS'
```

## 3. Ràng buộc kỹ thuật quan trọng

- **Non-sandboxed App:** Không bật `com.apple.security.app-sandbox` trong entitlements vì sẽ chặn `IOKit`, `Bluetooth`, và `Charge Limit`.
- **Không phá vỡ tính năng đã xong:** Luôn chạy `xcodebuild test` sau khi chỉnh sửa model/service.
- **Không dùng giá trị hardcode thay cho dữ liệu thật:** Các thông số pin phải đọc từ `BatteryMonitoring` (`IOKitBatteryService`), chỉ dùng mock trong `PowermanTests` hoặc SwiftUI `#Preview`.
- **Cập nhật tài liệu bàn giao:** Sau khi hoàn thành từng phần hoặc cuối mỗi Phase, bắt buộc cập nhật `docs/PROGRESS.md` và `CHANGELOG.md` trước khi push lên GitHub.
