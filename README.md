# Aegis iOS 客户端

iPhone / iPad 客户端，接入与 Android 相同的 Go WebSocket 服务端。

## 功能对照（与 Android Web 控制台）

| 功能 | iOS 支持 | 说明 |
|------|----------|------|
| WebSocket 连接 / owner / client-token | ✅ | App 内配置绑定用户与密钥 |
| 屏幕投屏 | ✅ | ReplayKit；WDA 模式下由服务端代理 |
| 远程点击 / 滑动 / 系统键 | VNC / WDA | VNC：TrollVNC（iOS≤17.0）；WDA：见 [WDA_SETUP.md](./WDA_SETUP.md) |
| 通讯录 | ✅ | 去重、limit，需通讯录权限 |
| 通话记录 | ⚠️ | 返回空列表（iOS 不开放 API） |
| 短信读/发 | ⚠️ | 返回空列表 / 不可发送（系统限制） |
| GPS 定位 | ✅ | 含 status 字段 |
| 相册同步 | ✅ | PhotoKit，照片 id 为 localIdentifier |
| 文件管理 | ✅ | App 沙盒 Documents（`/sdcard` 映射到 Documents） |
| 应用列表 | ✅ | 私有 API，需真机开发者签名 |
| 相机拍照 | ✅ | 前后摄，需相机权限且 App 前台 |
| 开屏/应用锁密码 | ⚠️ | 命令兼容，无无障碍无法自动捕获 |
| 键盘记录 / 操作记录 | ⚠️ | 命令兼容，可清空/查询历史，无法后台采集 |
| Shell | ⚠️ | 返回系统限制说明 |
| UI 树远程点击 | ❌ | 请使用 WDA 远程控制 |

**完整远控：**
- iOS 16 及以下 / 17.0 → [TrollVNC](./TROLLVNC_SETUP.md)（推荐，无需 Mac 常驻）
- 全版本含 17.0.1+ → [WebDriverAgent](./WDA_SETUP.md)

**购买 Apple 开发者签名（$99/年）** 与 Ad Hoc 分发，见 [APPLE_DEVELOPER_SETUP.md](./APPLE_DEVELOPER_SETUP.md)。

## 按用户打包（构建时写入 owner，无需扫码）

与 Android `build-client-apk.sh` 相同，在 **Mac** 上为每个用户单独编译 IPA。

**只上传了 `ios/` 文件夹时**（Mac 上最常见）：

```bash
cd ~/aegis-build/ios          # 或 ~/Downloads/ios
export IOS_DEVELOPMENT_TEAM=你的AppleTeamID
export IOS_CONTROL_MODE=wda   # WDA 模式；TrollVNC 用 vnc

chmod +x scripts/build-client-ios.sh

./scripts/build-client-ios.sh \
  wss://你的域名/ws/client \
  shop01 \
  你的client-token \
  http://wda-local.aegis:8100

# 输出 ios/dist/aegis-ios-shop01.ipa
```

**完整项目根目录**时也可用根目录脚本：

```bash
export IOS_DEVELOPMENT_TEAM=你的AppleTeamID

./scripts/build-client-ios.sh \
  wss://你的域名/ws/client \
  shop01 \
  你的client-token \
  http://127.0.0.1:8100

# 输出 web/downloads/aegis-ios-shop01.ipa
```

安装后 App 首次打开会读取包内配置（服务器、owner、token、WDA），并 **自动连接**，无需扫码。

仅复制已导出的 IPA：

```bash
./scripts/build-client-ios.sh --copy /path/to/exported.ipa shop01
```

## 构建步骤（Xcode 手动）

1. 用 Xcode 打开 `ios/AegisControlClient.xcodeproj`
2. 在 Signing & Capabilities 中选择你的开发团队
3. 修改 Bundle Identifier（如 `com.yourname.aegis.ios`）
4. 用数据线连接 iPhone，选择真机运行（模拟器也可测试连接，投屏需在真机）

## 配置

在 App 内填写：

- **控制中心 WebSocket**：`ws://IP:9000/ws/client` 或 `wss://域名/ws/client`
- **绑定用户名 (owner)**：与 Web 控制台登录名一致
- **客户端密钥**：与服务端 `-client-token` 一致（若已启用）
- **WDA 地址**：运行 Go 服务端的电脑可访问的 WDA URL（如 `http://127.0.0.1:8100`）

## Web 控制台

连接后设备显示 Apple 图标。在「远程控制」页点击「开始投屏」；首次需在 iPhone 上允许屏幕录制。

## 系统要求

- iOS 15.0+
- Xcode 15+
