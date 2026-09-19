# TongZhang iOS

这是「同账」的 SwiftUI 开发中工程，最低 iOS 17。用 macOS 上的 Xcode 15 或更新版本直接打开根目录 `TongZhang.xcodeproj`，选择共享 scheme `TongZhang` 和已安装的 iPhone 模拟器，运行应用；使用 Product > Test 运行测试，无需新建工程。当前源码尚未在 Xcode 中编译或验收。

模拟器无需配置开发者团队；真机运行时，在 Signing & Capabilities 中选择自己的 Team，并把 Bundle Identifier 改为自己的唯一标识。当前未配置 App Store 发布所需图标和签名。

在项目根目录运行 `xcodebuild -project TongZhang.xcodeproj -scheme TongZhang -showdestinations` 获取可用设备，然后用实际模拟器 UUID 执行：

```sh
xcodebuild -project TongZhang.xcodeproj -scheme TongZhang -destination 'platform=iOS Simulator,id=SIMULATOR_UUID' -resultBundlePath work/TongZhangTests.xcresult test
```

结果路径必须尚不存在。测试后需分别在小屏 iPhone SE 和大屏 iPhone 上检查浅色、深色、长昵称和大字体，验证记账、删除、历史结算、头像选取、重启恢复；浏览器原型不能替代原生验收。

## 设计与结构

- `Models.swift`：人物、消费、分摊方式、结算引擎和本地 Store
- `ContentView.swift`：首页、账单、账本、我们、记账弹层和结算弹层
- `TongZhangTests/SettlementEngineTests.swift`：整数分币、合并结算、请客、无需结算、自定义金额和比例测试
- 金额统一以 `Int64` 的分为单位，界面显示时才转换为人民币文本

当前数据层使用 `UserDefaults` 保存本地 JSON 快照，账单、结算状态、伴侣绑定和邀请码会在重启 App 后保留。下一步可将 `LedgerStore` 替换为 CloudKit repository，并将伴侣绑定与共享数据库放入独立 service。Preview 使用关闭持久化的模拟 Store。主题颜色使用浅色/深色自适应值，源码末尾提供 iPhone SE 和 iPhone 15 Pro Max 两个 Preview 配置。
