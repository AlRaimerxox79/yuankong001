# Apple 开发者签名与分发指南（$99/年）

本文说明如何 **正规购买** Apple 开发者账号，并为 **Aegis iOS App** 与 **WebDriverAgent (WDA)** 配置签名，实现比免费 Apple ID 更长的有效期与多设备分发。

> ⚠️ 请只在 [Apple 官网](https://developer.apple.com/programs/) 购买，不要使用第三方「超级签名」「企业证书代购」等服务（易被封、不安全、可能违法）。

---

## 一、购买开发者账号

1. 打开 https://developer.apple.com/programs/enroll/
2. 使用 Apple ID 登录，选择 **Apple Developer Program**
3. 费用：**99 USD / 年**（个人或公司均可）
4. 完成身份验证（个人一般 24–48 小时审核）

购买成功后，在 https://developer.apple.com/account 可管理证书与设备。

---

## 二、付费账号 vs 免费 Apple ID

| 项目 | 免费 Apple ID | 付费开发者 $99 |
|------|---------------|----------------|
| WDA / App 签名有效期 | 约 **7 天** | 开发证书约 **1 年** |
| 登记测试设备 | 有限 | 每年约 **100 台**（Ad Hoc） |
| TestFlight 公测 | ❌ | ✅（仅正式 App，WDA 不能上架） |
| App Store 上架 | ❌ | ✅ |

---

## 三、登记测试设备（Ad Hoc 必做）

要给别人的 iPhone 安装你签名的包，需要先把设备 UDID 登记到账号里。

### 获取 UDID

**方式 A：Mac 连接 iPhone**

```bash
# 安装后执行
xcrun xctrace list devices
# 或 Finder → 选中 iPhone → 点序列号区域切换到 UDID
```

**方式 B：让用户访问**（需在 Safari 打开）

- 在 Mac 用 Apple Configurator 或第三方合规工具导出
- 或通过 Xcode：Window → Devices and Simulators → 选中设备复制 Identifier

### 在开发者网站添加

1. https://developer.apple.com/account/resources/devices/list
2. **+** → iPhone → 粘贴 UDID → 注册

每年新增设备有上限（100 台/年），请留给真正要用的机器。

---

## 四、签名 Aegis iOS App

### 4.1 Xcode 自动签名（最简单）

1. 用 **付费开发者账号** 登录 Xcode：Settings → Accounts
2. 打开 `ios/AegisControlClient.xcodeproj`
3. Target **AegisControlClient** → **Signing & Capabilities**
4. 勾选 **Automatically manage signing**
5. **Team** 选你的付费团队
6. **Bundle Identifier** 改成唯一值，例如：`com.yourcompany.aegis.ios`
7. 连接 iPhone，选真机，**Cmd + R** 运行安装

### 4.2 Ad Hoc 导出 IPA（分发给已登记 UDID 的设备）

1. Product → **Archive**
2. Organizer → **Distribute App**
3. 选 **Ad Hoc** → 选包含目标设备的 Profile
4. 导出 IPA，通过爱思助手 / Apple Configurator / 自建下载页发给用户安装
5. 用户安装后：设置 → 通用 → VPN与设备管理 → **信任** 你的开发者

### 4.3 用户安装后

- 在 App 内填写 WebSocket 与 WDA 地址（见 [WDA_SETUP.md](./WDA_SETUP.md)）
- iOS 16+ 需开启 **开发者模式**

---

## 五、签名 WebDriverAgent（远控核心）

WDA **不能** 上架 App Store / TestFlight，只能开发/Ad Hoc 安装。

### 5.1 克隆与打开工程

```bash
git clone https://github.com/appium/WebDriverAgent.git
cd WebDriverAgent
open WebDriverAgent.xcodeproj
```

### 5.2 配置两个 Target 的签名

对 **WebDriverAgentLib** 和 **WebDriverAgentRunner** 均执行：

1. Signing & Capabilities → Team 选付费团队
2. Bundle ID 改为唯一前缀，例如：
   - `com.yourcompany.WebDriverAgentLib`
   - `com.yourcompany.WebDriverAgentRunner`
3. 勾选 Automatically manage signing

### 5.3 运行到 iPhone

1. 顶部设备选目标 iPhone
2. Scheme 选 **WebDriverAgentRunner**
3. **Product → Test**（Cmd + U）
4. 手机允许「自动化」与「开发者 App」

成功后日志出现：`ServerURLHere->http://xxx:8100`

### 5.4 保持 WDA 常驻（可选）

- 开发阶段：Mac 保持 Xcode Test 运行
- 进阶：自行研究 `xcodebuild test` 脚本 + launchd 定时拉起（仍可能受系统限制）

付费证书 **1 年内** 一般无需每周重签；**证书到期前**需重新 Archive/Test 一次。

---

## 六、与 Aegis 控制中心对接

### 6.1 网络

在 **运行 Go 服务端的电脑** 上：

```bash
iproxy 8100 8100
```

### 6.2 iOS App 配置

| 字段 | 示例 |
|------|------|
| WebSocket | `ws://192.168.1.100:9000/ws/client` |
| WDA 地址 | `http://127.0.0.1:8100`（服务端与 iproxy 同机时） |

### 6.3 Web 控制台

选择带 **WDA** 标记的设备 → **远程控制** → **开始投屏** → 点击/滑动操控。

---

## 七、推荐工作流（给多台测试机）

```
1. 购买 $99 开发者账号
2. 收集每台 iPhone 的 UDID → 在开发者网站登记
3. 创建 Ad Hoc Provisioning Profile（含这些设备）
4. 分别给每台手机：
   - 安装 Ad Hoc 签名的 Aegis iOS App
   - Xcode Test 安装 WebDriverAgentRunner（或导出 WDA Ad Hoc 若你自行打包）
5. 用户手机：开发者模式 + 信任证书
6. 服务端 iproxy + Go 服务 + Web 控制台
```

---

## 八、费用与维护清单

| 项目 | 费用/周期 |
|------|-----------|
| Apple Developer Program | $99 / 年 |
| Mac（签名与跑 WDA 必备） | 已有或购置 |
| 证书续期 | 每年续费 $99 |
| 新增超过 100 台设备/年 | 需等下一年额度或换企业方案 |

---

## 九、常见问题

**Q：买了签名能否让陌生人随便装？**  
A：Ad Hoc 仍要 UDID 预登记，且需用户信任证书、开开发者模式，不是「发个链接全员静默安装」。

**Q：能否只买签名、不买 Mac？**  
A：正规签名必须在 Mac + Xcode 完成。无 Mac 只能考虑购置 Mac mini 或云 Mac。

**Q：第三方「企业签 / 超级签」？**  
A：不推荐。证书随时吊销、隐私风险高、违反 Apple 协议。

**Q：Aegis App 能上架 App Store 吗？**  
A：远程监控类 App 审核极严，大概率被拒；实际场景用 Ad Hoc / 企业内部分发。

---

## 十、相关文档

- [WDA_SETUP.md](./WDA_SETUP.md) — WDA 详细运行步骤
- [README.md](./README.md) — iOS 客户端总览
