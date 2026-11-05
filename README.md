# VoiceInput — 给 OpenCode / Claude Code 用的语音输入

按住 **右 Option（⌥）** 说话，松开后自动把语音转成文字并输入到当前终端窗口。
对 OpenCode、Claude Code、任何编辑器或聊天框都通用。

- 原生 macOS 菜单栏 App，Swift 编写，无 Node / Python 依赖
- 使用 Apple 系统语音识别，**免费、无需 API Key**
- 默认优先使用**设备端识别**，语音不出本机
- 中文（`zh-CN`）为主，中英混说可用；技术词可通过 `contextualStrings` 增强

> 为什么不做成 OpenCode 插件：OpenCode / Claude Code 的插件运行在各自的进程里，
> 既拿不到麦克风，也无法向终端模拟键盘输入。系统级菜单栏工具才是正确架构，
> 而且一次做好，两边都能用。

## 快速开始

```bash
cd voice-input
./install.sh
```

安装到 `/Applications/VoiceInput.app` 并启动。

### 首次授权（重要）

按菜单栏的麦克风图标，逐项授权：

1. **麦克风** — 录音
2. **语音识别** — 把录音转成文字
3. **辅助功能** — 监听右 Option 快捷键，并把文字粘贴进当前窗口

安装后首次从「应用程序」目录启动时，会自动加入登录项（开机启动）；不想开机启动的话，
在菜单里点一下「开机启动（已开启）」即可关闭，之后不会再自动打开。

想用**完全离线**的设备端识别，还需要下载中文语言包：

系统设置 → 键盘 → 听写 → 开启听写并添加「中文（普通话）」，
等语言包下载完成。菜单里「设备端识别」不再显示“语言包未下载”即表示可用。
语言包没下载时，程序会自动退回 Apple 在线识别，功能不受影响，但音频会发送给 Apple。

授权后如果快捷键没反应，退出 App 再打开一次（macOS 的权限对进程生效）。

系统设置路径：

- 隐私与安全性 → 麦克风
- 隐私与安全性 → 语音识别
- 隐私与安全性 → 辅助功能

## 使用

1. 光标停在 OpenCode / Claude Code 的输入框里
2. 按住 **右 Option**，看到底部“正在聆听…”后说话
3. 松开，文字自动出现在输入框
4. 按回车发送

说明：

- 按住时间太短（<0.35s）不会触发，避免误触
- 按住右 Option 时按了别的键（例如 `Option+方向键`），本次录音自动取消，不影响原快捷键
- 录音中按 `Esc` 取消
- 单次最长 60 秒（Apple 语音识别的限制），超时会自动结束并输入已识别内容

悬浮窗外观可以在菜单栏里直接调：点菜单栏 🎤 →「悬浮窗透明度」，拖动滑块即可实时预览。
范围 0.30 ~ 1.0，越小越透明；不需要重新编译。

## 配置

配置文件：`~/.config/voice-input/config.json`（第一次启动自动生成）。
菜单里点「打开配置文件」或「重新加载配置」。修改后选「重新加载配置」即可生效。

```jsonc
{
  "locale": "zh-CN",              // 识别语言，英文为主可改 en-US
  "insertMethod": "paste",        // paste = 剪贴板粘贴；type = 模拟键盘输入
  "restoreClipboard": false,      // true = 粘贴后恢复原剪贴板；false = 保留识别文字
  "onDeviceRecognition": true,    // 优先设备端识别；false 则允许使用 Apple 在线识别
  "maxRecordingSeconds": 60,      // 单次录音上限
  "minHoldSeconds": 0.35,         // 最短按住时间，防误触
  "playFeedbackSound": true,      // 开始/结束提示音
  "showHUD": true,                // 底部悬浮提示
  "hudOpacity": 0.45,             // 悬浮窗蒙层不透明度，0.30 ~ 1.0，越小越透明
  "contextualStrings": ["OpenCode", "Claude Code", "插件", "终端"]
}
```

### 识别不准怎么办

- 在 `contextualStrings` 里加上你常用的项目名、框架名、人名
- 说话时中英混用没问题，但整句语言切换太多会掉准确率
- 如果设备端模型不可用，把 `onDeviceRecognition` 设为 `false`，改用 Apple 在线识别
- 对技术术语要求更高时，可以后续接入云端 Whisper 兼容接口（见下）

## 开机启动

菜单里勾选「开机启动」。若显示“需在系统设置中批准”，到
系统设置 → 通用 → 登录项 中允许 `VoiceInput`。

## 常见问题

**按右 Option 没反应**

- 确认「辅助功能」已授权，且授权后重启过 App
- 某些键盘改键工具（Karabiner 等）可能映射了右 Option，需要放行或换键
- 菜单栏图标变红才代表正在录音

**菜单显示“设备端识别（语言包未下载）”**

- 到 系统设置 → 键盘 → 听写 开启听写并添加中文，等语言包下载完
- 未下载时自动使用 Apple 在线识别，需要联网
- 也可以用 `"onDeviceRecognition": false` 明确使用在线识别

**有“正在聆听”但松开后没输入**

- 确认「辅助功能」已授权；`paste` 模式依赖它发送 `⌘V`
- 试试菜单里把输入方式切成「模拟键盘输入」
- 查看日志：`~/Library/Logs/VoiceInput.log`

**粘贴后剪贴板内容变了**

- 默认会把识别出的文字保留在剪贴板，方便再次粘贴
- 如果想粘贴后恢复原来的内容，设 `"restoreClipboard": true`

**重新编译后权限失效**

- ad-hoc 签名在每次重新编译后会变化，macOS 可能要求重新授权
- 点菜单里的「辅助功能：未授权」，会自动清理旧记录并打开系统设置，重新把 VoiceInput 的开关打开即可
- 仍然不行就把列表里的旧 VoiceInput 用 `-` 删掉，再 `+` 添加 `/Applications/VoiceInput.app`

**Claude Code 未安装也能用吗**

- 能。这是系统级输入工具，与具体 CLI 无关；只要光标在任意输入框里就能用

## 开发

```
Sources/
  main.swift           程序入口
  AppDelegate.swift    菜单栏、状态机、菜单
  HotkeyMonitor.swift  全局右 Option 按住/松开监听
  SpeechSession.swift  录音 + Apple 语音识别
  TextInjector.swift   剪贴板粘贴 / Unicode 键盘事件
  HUD.swift            底部悬浮提示
  Config.swift         配置文件
  Permissions.swift    权限状态与授权
  Log.swift            日志
tools/
  make_icon.swift      生成 App 图标
  安装说明.txt          随安装包分发的说明
```

```bash
./build.sh      # 通用二进制（arm64 + x86_64），构建到 build/VoiceInput.app
./install.sh    # 构建 + 安装到 /Applications + 启动
./package.sh    # 构建并生成 dist/VoiceInput-<版本>.dmg 和 .zip（分发用）
```

`package.sh` 会生成：

- `dist/VoiceInput-1.1.6.dmg`：App + Applications 快捷方式 + 中文安装说明
- `dist/VoiceInput-1.1.6.zip`：只含 App，适合直接传文件

注意：当前使用 ad-hoc 签名，没有 Apple 公证。其他人第一次打开需要右键 →「打开」，
或在终端执行 `xattr -dr com.apple.quarantine /Applications/VoiceInput.app`。
要做到双击无提示安装，需要 Apple Developer ID 证书签名并公证。

## 后续可加

- 朗读 AI 回复（TTS）：需要按工具对接输出流，OpenCode 可通过 HTTP API/事件订阅，
  Claude Code 可通过 hooks/日志，二者实现方式不同
- 云端识别：OpenAI 兼容的 `/audio/transcriptions`（OpenAI、硅基流动、Groq 等），
  适合对技术术语和中英混说准确率要求更高的场景
- 自定义快捷键、双击 Fn 切换模式、识别历史
