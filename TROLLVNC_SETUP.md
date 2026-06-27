# TrollVNC 接入 Aegis Web 控制台

适用于 **iOS 14.0～16.6.1、16.7 RC、17.0**（需 TrollStore）。与 Android 共用同一 Web 远程控制页面。

## 架构

```
Web 控制台 ──WebSocket──► Go 服务端 (vnc_bridge.go)
                              ▲
                    TrollVNC Repeater (:5500)
                              ▲
                         TrollVNC (iPhone)
                              ▲
                    Aegis iOS App（仅注册 controlMode=vnc）
```

远控指令（投屏/点击/滑动）由 **Go 服务端经 VNC 协议** 转发，不经过 iOS App。

## 1. 安装 TrollStore + TrollVNC

1. 按设备 iOS 版本安装 [TrollStore](https://ios.cfw.guide/installing-trollstore/)
2. 从 Havoc 源安装 **TrollVNC** IPA
3. TrollVNC 设置中配置 **VNC 密码**（与服务端 `AEGIS_VNC_PASSWORD` 一致）

## 2. 配置 Go 服务端

环境变量（可选）：

```bash
export AEGIS_VNC_PASSWORD=你的VNC密码
export AEGIS_VNC_REPEATER_ADDR=:5500   # 默认 :5500，留空可设 "" 禁用
```

启动服务端后日志应出现：

```
VNC repeater enabled on :5500 (TrollVNC reverse/repeater)
```

防火墙需放行 **5500/TCP**（TrollVNC 反向连入）。

## 3. 配置 TrollVNC（反向连接，推荐）

在 iPhone TrollVNC 设置中：

| 项 | 值 |
|---|---|
| 模式 | Repeater / Reverse |
| Repeater ID | **与 Aegis 设备 ID 相同**（App 内可见，或打包时自动生成） |
| 服务器 | `你的域名或IP:5500` |
| 密码 | 与 `AEGIS_VNC_PASSWORD` 一致 |

> Repeater ID 默认等于 Aegis iOS App 注册时的 `id` 字段（`vncRepeaterId`）。

## 4. 打包 / 配置 Aegis iOS App

**VNC 模式打包（Mac）：**

```bash
export IOS_DEVELOPMENT_TEAM=你的TeamID
export IOS_CONTROL_MODE=vnc

./scripts/build-client-ios.sh \
  wss://你的域名/ws/client \
  shop01 \
  你的client-token
```

安装 App 后打开即自动连接，Web 设备列表显示 **VNC** 徽章。

**局域网直连调试（可选）：**

```bash
export IOS_CONTROL_MODE=vnc
export IOS_VNC_HOST=192.168.1.100:5901
```

或在 App 内填写「VNC 直连地址」。

## 5. Web 控制台使用

1. 确认 TrollVNC 已连上服务器（服务端日志：`VNC repeater session ready: id=...`）
2. 选择带 **VNC** 标记的 iPhone
3. 远程控制 → **开始投屏**
4. 在画面上点击、滑动（与 Android 相同）

## 6. 与 WDA 对比

| 项 | TrollVNC | WDA |
|---|---|---|
| iOS 版本 | ≤16.6.1 / 17.0 | 全版本含 17.0.1+ |
| Mac 常驻 | 不需要 | 需要 |
| 证书过期 | 永久 | 7 天（免费账号） |

**iOS 17.0.1 及以上请改用 WDA**，见 [WDA_SETUP.md](./WDA_SETUP.md)。

## 常见问题

| 问题 | 处理 |
|---|---|
| 开始投屏提示 TrollVNC 未连接 | 检查 TrollVNC 反向连接、Repeater ID、防火墙 5500 |
| 认证失败 | 统一 TrollVNC 密码与 `AEGIS_VNC_PASSWORD` |
| 画面黑屏 | 重启 TrollVNC 服务，确认 iPhone 未锁屏 |
| Home 键无效 | VNC 模式点击屏幕底部中间区域 |
