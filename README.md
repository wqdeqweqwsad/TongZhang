# 同账 · TongZhang

情侣双人共同账本 iOS MVP，定位为一个精致、私密、有温度的共同生活空间，而不是传统财务软件。

## 当前交付

- [高保真浏览器原型](C:/Users/tanghong/Documents/Codex/2026-09-18/b-n/outputs/index.html)：可直接打开或通过 `http://127.0.0.1:4173/` 预览
- [SwiftUI Xcode 工程](C:/Users/tanghong/Documents/Codex/2026-09-18/b-n/TongZhang.xcodeproj)：iOS 17+，包含应用 target 和测试 target
- [SwiftUI 源码](C:/Users/tanghong/Documents/Codex/2026-09-18/b-n/TongZhang)
- [结算测试](C:/Users/tanghong/Documents/Codex/2026-09-18/b-n/TongZhangTests/SettlementEngineTests.swift)

## 功能范围

SwiftUI 版本已包含首页、快速记账、账单、账本、我们、结算弹层、删除确认和账单空状态。核心计算区分实际付款人和实际承担人，支持平分、请客、自定义金额/比例，并使用 `Int64` 分值避免浮点误差。原始消费记录在结算后保留。

数据层当前使用 `UserDefaults` 保存本地 JSON 快照，重启 App 后账单、结算状态、伴侣绑定和邀请码仍会保留。后续接入 CloudKit 时可将 `LedgerStore` 替换为 repository/service，不影响结算引擎和页面结构。Preview 使用关闭持久化的模拟 Store，不会污染真实数据。

## 验证说明

当前执行环境是 Windows，没有 Xcode、iOS SDK、Swift 编译器或 iOS Simulator，因此无法在本机编译运行 `.xcodeproj` 或完成两种 iPhone 模拟器截图验证。工程文件和 XCTest 已准备好，应在 macOS/Xcode 中打开后执行 `Product > Test`，并在 iPhone SE 与 iPhone 15/15 Pro 模拟器上检查布局。

在 macOS 上可从项目根目录执行：

```bash
xcodebuild -project TongZhang.xcodeproj \
  -scheme TongZhang \
  -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,name=iPhone 15 Pro' \
  test
```

然后在 Xcode Canvas 中分别选择 `iPhone SE (3rd generation)` 和 `iPhone 15 Pro Max` 预览，检查首页金额、记账表单、日期分组和底部操作按钮。
