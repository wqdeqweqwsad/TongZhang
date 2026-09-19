# 同账 iOS 运行与验收

当前是开发中源码，尚未完成原生编译和视觉验收。

## 打开工程

交付包 `TongZhang-iOS-source.zip` 包含下述三个同级目录及本说明，解压后即可在 Mac 上打开工程。该包是源码，不是可直接安装的 IPA。

将工作区中的 `TongZhang.xcodeproj`、`TongZhang`、`TongZhangTests` 保持同级放在 Mac 上。使用 Xcode 15 或更新版本打开已有工程，选择 `TongZhang` scheme 和 iOS 17 以上的 iPhone 模拟器，点击运行。无需重新创建项目。

真机运行需在 Signing & Capabilities 选择自己的 Team，并设置唯一 Bundle Identifier。模拟器不需要开发者团队。App Store 图标与发布配置尚未完成。

## 没有 Mac 时：云端编译

工程附带 `.github/workflows/ios.yml`。将解压后的工程上传到自己的 GitHub repository，进入 **Actions**，开启 workflow 后执行一次；GitHub 会在 macOS runner 中使用 iPhone 15 Simulator 编译并运行 XCTest。完成后可在该次 workflow 的 Artifacts 下载 `xcodebuild-log`。

这条路径可以验证 Swift 编译、工程配置和单元测试，但不能替代真实设备的触控、相机、字体和视觉验收。GitHub Actions 的 macOS 使用额度及可用性以你的 GitHub 账户为准。

## 用现有 iPhone 做真实验收

GitHub Actions 的测试通过后，可以使用云端 macOS 构建服务把签名后的版本上传到 TestFlight，再在 iPhone 上安装。推荐流程如下：

1. 在 Apple Developer 账户中注册 App ID，并准备 App Store Connect 应用记录。个人开发者计划通常需要付费，具体价格以 Apple 当前页面为准。
2. 将本项目导入 Codemagic、Bitrise 或 Xcode Cloud，连接 GitHub repository，设置 `TongZhang` scheme、iOS 17+ 和 App Store distribution signing。
3. 让云端构建服务上传 TestFlight build，并在 App Store Connect 中添加自己的 Apple ID 为内部测试员。
4. 在 iPhone 安装 TestFlight，从邀请的测试版本中打开“同账”，检查浅色/深色、录入速度、键盘、头像、月份切换和删除确认。

仅用 iPhone 无法直接编译本地 SwiftUI 工程，也不能安装 GitHub Actions 产生的未签名构建产物。若暂时没有 Apple Developer 账户，仍可先用 Actions 验证编译与 XCTest，之后再做 TestFlight 分发。

## 零花费个人安装：免费 Apple ID + Sideloadly

如果只是你和女朋友在自己的手机上体验，可以不购买 Apple Developer Program。GitHub Actions 现在还会生成 `TongZhang-unsigned-ipa` artifact；下载后，在 Windows 使用 Sideloadly（或 AltStore/SideStore）用你自己的免费 Apple ID 签名，再通过 USB 安装到 iPhone。首次安装时按工具提示连接并信任设备，不要把 Apple ID 密码发给任何人或提交到 GitHub。

这种方式不是 TestFlight，限制包括：免费签名通常约 7 天后需要重新签名/刷新；每台设备有免费开发者签名的 App 数量限制；系统更新或证书状态可能要求重新安装。你和女朋友可以分别在各自 iPhone 上安装，但两台手机仍不会因为安装了同一个 App 就自动共享数据。

操作步骤：

1. 打开本次成功运行记录：[35412406866](https://github.com/wqdeqweqwsad/TongZhang/actions/runs/35412406866)，在页面底部下载 Artifacts 中的 `TongZhang-unsigned-ipa`（约 333 KB）。
2. 在 Windows 安装 Sideloadly，选择这个 IPA，输入你自己的 Apple ID，并连接 iPhone。
3. 按 Sideloadly 提示完成签名和安装；如果 iPhone 提示不受信任，到“设置 > 通用 > VPN 与设备管理”信任对应开发者。
4. 在女朋友的 iPhone 上重复一次。两部手机必须分别完成签名安装，不能只把已签名 App 文件通过数据线复制过去。

免费安装方案只适合体验当前本地版 MVP。要让两个人的消费真正同步，仍需后续接入 CloudKit 或自建同步服务；要长期稳定分发，则使用 Apple Developer + TestFlight。

## 运行测试

可使用 Xcode 的 Product > Test。命令行先在项目根目录列出设备：

```sh
xcodebuild -project TongZhang.xcodeproj -scheme TongZhang -showdestinations
```

将实际模拟器 UUID 填入下方命令；结果路径必须尚不存在：

```sh
xcodebuild -project TongZhang.xcodeproj -scheme TongZhang -destination 'platform=iOS Simulator,id=SIMULATOR_UUID' -resultBundlePath work/TongZhangTests.xcresult test
```

## 必须完成的原生验收

- 在小屏 iPhone SE 和大屏 iPhone 上检查浅色、深色、长昵称及大字体，保存截图。
- 测量默认平分消费的录入耗时，目标约 10 秒。
- 验证五种分摊方式、不同付款人、结算后新增消费及删除消费的余额。
- 检查日常/旅行归属、月份切换、空状态、删除确认和结算历史。
- 从旅行账本详情的工具栏新增消费，确认默认归入旅行账本；账本与关系页不应出现全局日常记账按钮。
- 开启辅助功能大字体，确认账单三项统计及头像选择纵向排列，深色模式下绑定和结算按钮文字清晰。
- 验证头像读取、移除、昵称编辑及重启后的恢复。
- 执行 XCTest，检查损坏快照保护、金额解析和整数分币等测试结果。

数据目前只保存在本机 UserDefaults JSON 快照中，邀请码为本地模拟。不能作为两台手机间真实同步使用。浏览器原型仅供早期视觉参考，不证明 iOS 工程可运行。
