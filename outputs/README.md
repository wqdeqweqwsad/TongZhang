# 同账 · Together

一个面向情侣的高保真双人共同账本原型。当前版本使用本地模拟数据，重点验证视觉方向、信息层级和核心交互。

## 运行

直接在浏览器打开 `index.html` 即可预览，也可以在 `outputs` 目录运行任意静态文件服务器。

## 已覆盖

- 首页共同生活摘要、预算进度、最近记录
- 快速记账底部弹层：金额、付款人、分摊方式、分类、备注
- 账单月份摘要与筛选
- 旅行账本和共同目标视觉入口
- 双人关系与隐私设置页
- 结算确认流程与已平账状态
- 空间适配：窄屏优先，桌面保持手机画布质感

## SwiftUI 迁移建议

将 `app.js` 中的 `expenses` 映射为 `Expense` 数组，金额用 `Int64 amountInCents` 保存。UI 可拆分为 `HomeView`、`BillsView`、`LedgersView`、`ProfileView`、`ExpenseSheet` 和 `SettlementSheet`。核心结算可使用以下规则：

```swift
let balance = totalPaid - totalShare
// balance > 0: 该用户多付，应收
// balance < 0: 该用户少付，应付
```

## 说明

此环境为 Windows，未安装 Xcode / iOS Simulator，因此无法在本机编译或运行 SwiftUI 工程；本目录提供的是可直接打开的交互式高保真原型，便于在 macOS/Xcode 环境中继续迁移实现。
