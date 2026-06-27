# iPhone WebDriverAgent (WDA) 远控配置

通过 WDA，Web 控制台可对 iPhone 进行**投屏 + 点击 + 滑动 + Home/返回**（与 Android 远控类似）。

## 前置条件

- Mac + Xcode 15+
- iPhone 数据线连接 Mac（首次建议 USB）
- iPhone 开启 **开发者模式**：设置 → 隐私与安全性 → 开发者模式
- iPhone 信任此电脑

## 1. 安装 WebDriverAgent

```bash
# 安装依赖（若未安装）
brew install libimobiledevice

# 克隆 WDA（Appium 维护分支）
git clone https://github.com/appium/WebDriverAgent.git
cd WebDriverAgent
open WebDriverAgent.xcodeproj
```

在 Xcode 中：

1. 选择 Target **WebDriverAgentRunner**
2. **Signing & Capabilities** → 选择你的 Apple ID 团队
3. 修改 **Bundle Identifier**（如 `com.yourname.WebDriverAgentRunner`)
4. 顶部设备选你的 **iPhone**
5. 菜单 **Product → Test**（或 `Cmd + U`）运行测试

首次会在手机上弹出「允许自动化」，需点允许。成功后 Xcode 控制台出现 `ServerURLHere->http://xxx:8100`。

## 2. 让 Go 服务端能访问 WDA

WDA 跑在 iPhone 的 `8100` 端口。Go 服务端在电脑上，需要转发：

### 方式 A：USB + iproxy（推荐）

在**运行 Go 服务端的电脑**上执行：

```bash
iproxy 8100 8100
```

WDA 地址填：`http://127.0.0.1:8100`

### 方式 B：同一 WiFi

部分 WDA 构建会监听局域网 IP，可直接填：

```
http://192.168.1.xxx:8100
```

（以 Xcode 日志里 `ServerURLHere` 为准）

## 3. 在 Aegis iOS App 中配置

1. **控制中心 WebSocket**：`ws://电脑IP:9000/ws/client`
2. **WDA 地址**：`http://127.0.0.1:8100`（若 Go 服务端与 iproxy 在同一台 Mac）
3. 点击「连接并激活」

## 4. Web 控制台使用

1. 打开 `http://电脑IP:9000`
2. 选择带 **WDA** 标记的 iPhone
3. 进入 **远程控制** → **开始投屏**
4. 在画面上点击、拖动进行操控

## 常见问题

| 问题 | 处理 |
|------|------|
| 连接 WDA 失败 | 确认 Xcode Test 仍在运行、iproxy 已启动 |
| 投屏黑屏 | 重新 Product → Test，重启 iproxy |
| 点击无反应 | 检查 WDA 地址是否从**服务端电脑**可访问 |
| 证书错误 | 在 Xcode 重新签名 WebDriverAgentRunner |

## 架构说明

```
Web 控制台 ──WebSocket──► Go 服务端 ──HTTP──► WDA (iPhone:8100)
                │
iOS App ──WebSocket──► Go 服务端  （仅注册设备信息 + wdaUrl）
```

远控指令由 **Go 服务端直连 WDA**，不经过 iOS App 转发。

## 限制

- 需保持 Mac 上 WDA 测试进程运行（或自行部署常驻方案）
- 免费 Apple 开发者证书约 7 天需重新签名
- 不适合 App Store 公开发布，适合**自用测试机 / 开发机**
