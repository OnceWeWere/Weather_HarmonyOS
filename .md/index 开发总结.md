# 🌦️ HarmonyOS 天气 APP 开发总结

## 一、 项目概况

- 
- **目标**：开发一个基于 ArkUI 的单页天气应用。
- **核心功能**：沉浸式 UI、实时定位（IP定位）、实时天气+预报、下拉刷新、网络状态检测与跳转设置。
- **数据源**：高德地图开放平台 (Web 服务 API)。
- **开发语言**：ArkTS (API 9+)。

------



## 二、 遇到的困难与解决方案

### 1. UI 与 沉浸式布局

**困难点**：

- 
- 如何让背景图/颜色充满整个屏幕（包括状态栏和底部导航条）。
- 内容区域会被刘海屏或底部横条遮挡。
- 列表 (List) 与底部导航条的间距难以把控，容易“吊”在半空或被遮住。

**✅ 解决方案**：

- 
- **全屏开启**：在 aboutToAppear 中调用 window.setWindowLayoutFullScreen(true)。
- **背景延伸**：给背景容器设置 .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])。
- **动态避让**：使用 window.getWindowAvoidArea() 获取系统状态栏和导航条的具体高度 (px2vp 转换)，将高度赋值给顶部和底部的 margin/padding。
- **布局权重**：使用 Blank().layoutWeight(1) 自动填充中间空隙，将底部列表自然推向页面下方。

### 2. ArkTS 严格模式 (Strict Mode)

**困难点**：

- 
- 报错 Object literals cannot be used as type declarations。
- 报错 Use explicit types instead of "any"。
- API 返回的 JSON 数据结构复杂，嵌套层级多。

**✅ 解决方案**：

- 
- **拒绝匿名对象**：所有嵌套的对象（如 lives, forecasts, casts）必须单独提取为 interface。
- **明确类型**：在 catch((err: BusinessError) => ...) 和 HTTP 回调中显式声明参数类型。
- **类型转换**：使用 JSON.parse(...) as InterfaceName 进行断言。

### 3. 定位方案的选择与实现

**困难点**：

- 
- **GPS 定位 (原生)**：精度高但实现复杂。需要处理权限弹窗、用户拒绝、系统开关、室内无信号、以及最麻烦的 **WGS-84 转 GCJ-02 坐标系偏移**问题。
- **IP 定位 (API)**：简单但曾遇到请求失败、无反应的问题。

**✅ 解决方案**：

- 
- **最终选择**：为了开发效率和用户体验（无弹窗、秒开），采用了 **高德 IP 定位 Web API**。
- **实现方式**：直接发送 HTTP GET 请求到高德 v3/ip 接口，获取城市名和 Adcode。

### 4. 网络请求与 API 调试 (最大的坑)

**困难点**：

- 
- **“无法获取”**：明明有网，代码也没报错，但就是拿不到数据。
- **模拟器网络**：模拟器显示连上 WiFi，但实际不通，或 connection 模块报错 Permission denied。
- **API Key 错误**：错误地使用了“HarmonyOS”类型的 Key，导致接口返回 10001 错误。

**✅ 解决方案**：

- 
- **Key 类型**：必须去高德控制台申请 **【Web 服务】** 类型的 Key。
- **权限补全**：除了 INTERNET，使用 connection 模块还需在 module.json5 添加 ohos.permission.GET_NETWORK_INFO。
- **HTTP 配置**：请求时必须加上 expectDataType: http.HttpDataType.STRING，防止系统自动转换对象导致解析崩溃；加上 connectTimeout 防止网络极差时卡死。
- **容错逻辑**：如果 connection 模块检测报错（如权限不足），**强行发起 HTTP 请求**尝试，而不是直接报错。

### 5. 交互体验优化

**困难点**：

- 
- 没网时刷新圈“秒退”，用户感觉像没反应。
- 不知道当前是在“定位中”还是“失败了”。

**✅ 解决方案**：

- 
- **人为延迟**：在失败回调中加入 setTimeout(..., 1000)，保证刷新动画至少展示 1 秒。
- **状态管理**：引入 isNetworkError 状态。失败后，城市名显示“无法获取”，并展示“打开网络...”的可点击提示条。
- **跳转设置**：使用 context.startAbility 拉起系统的 wifi_entry 页面，方便用户联网。

------



## 三、 核心代码片段回顾

### 1. 稳健的 HTTP 请求封装

codeTypeScript



```
req.request(url, {
  method: http.RequestMethod.GET,
  expectDataType: http.HttpDataType.STRING, // 关键：强制返回字符串
  connectTimeout: 3000, // 关键：设置超时
  readTimeout: 3000
}, (err: Error, data: http.HttpResponse) => {
  // ... 
});
```

### 2. 沉浸式与安全区

codeTypeScript



```
// 背景铺满
.expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])

// 内容避让
.margin({ top: this.topSafeHeight }) 
.margin({ bottom: this.bottomSafeHeight + 10 })
```

### 3. 跳转系统设置

codeTypeScript



```
let want: Want = {
  bundleName: 'com.huawei.hmos.settings',
  abilityName: 'com.huawei.hmos.settings.MainAbility',
  uri: 'wifi_entry' // 直接跳 WiFi
};
context.startAbility(want);
```

------



## 四、 总结

这次开发历程从最初的“跑通功能”，经历了“定位不准”、“模拟器网络假象”、“权限报错”等多个典型问题，最终打磨出了一个具备**容错能力**、**UI 精致**且**逻辑闭环**的天气 App。

**最大的经验**：

1. 
2. **看日志 (Log)** 是解决问题的核心手段（区分是 Key 错、没网还是解析错）。
3. **模拟器环境**不可全信，网络请求代码要做好异常捕获（try-catch）。
4. **用户体验**细节（如延迟结束刷新、按压动画）能让 App 质感提升一个档次。