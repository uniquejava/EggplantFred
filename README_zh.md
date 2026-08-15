# EggplantFred

原生 **macOS 14+** Alfred 风格应用启动器 — 仅菜单栏，SwiftUI + AppKit。

[English](./README.md)

预编译 DMG 见 **[Releases](https://github.com/uniquejava/EggplantFred/releases)** — 推送 `v*` 标签即可自动打包。

<p align="center">
  <img src="./docs/screenshot.png" alt="EggplantFred 启动器搜索 Fre" width="640">
</p>

## 功能

- **仅菜单栏** — 不占 Dock（打开偏好设置时才显示 Dock 图标）
- **全局快捷键** — 默认 **⌥ 双击**；也支持 ⌃ / ⇧ / ⌘ 双击或修饰键+按键组合
- **模糊搜索** — 按应用名或 `.app` 文件名匹配；空查询不显示列表
- **紧凑界面** — 搜索框展开最多 9 条结果；Alfred 风格紫色选中
- **快速打开** — Enter 或 **⌘1**…**⌘9**；Esc / 点空白处关闭
- **偏好设置** — 菜单栏入口，或搜索框上的帽子图标

## 系统要求

- macOS **14** 或更高
- 全局快捷键需要 [辅助功能](x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility) 权限  
  （系统设置 → 隐私与安全性）。未授权时快捷键无效。

## 安装

1. 从 [Releases](https://github.com/uniquejava/EggplantFred/releases) 下载 `.dmg`，拖到「应用程序」
2. 若 Gatekeeper 拦截：`xattr -cr /Applications/EggplantFred.app`
3. 打开应用 → 按提示授予辅助功能权限

## 从源码运行

```bash
open EggplantFred.xcodeproj
# or
xcodebuild -scheme EggplantFred -configuration Debug -derivedDataPath build build
open build/Build/Products/Debug/EggplantFred.app
```

Release 构建、安装到 `/Applications`、打 DMG、打标签发 GitHub Release：见 **[docs/commands.md](docs/commands.md)**。

## 文档

| 文档 | 内容 |
|------|------|
| [docs/commands.md](docs/commands.md) | 构建、运行、安装、DMG、GitHub Release、图标、辅助功能 |
| [docs/menu-bar-icon.md](docs/menu-bar-icon.md) | 菜单栏 `HatGlyph` 设计说明 |
| [docs/app-icon.md](docs/app-icon.md) | Dock / Finder 应用图标 |
