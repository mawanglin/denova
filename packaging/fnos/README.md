# Denova 飞牛 fnOS 原生 fpk

以原生进程运行 Denova，不依赖 Docker。每次构建同时产出 x86_64 和 ARM64 两个包。

## 构建

依赖：Go（版本见 `go.mod`）、pnpm、python3 + Pillow（生成图标），以及能访问 GitHub（下载 ripgrep）和 `static2.fnnas.com`（下载 fnpack）的网络。

```bash
packaging/fnos/build-fpk.sh              # 构建前端，打包 x86 和 arm
packaging/fnos/build-fpk.sh --skip-web   # 直接用已有的 web/dist
packaging/fnos/build-fpk.sh arm          # 只打 ARM 包
```

产物：`packaging/fnos/out/denova-<版本>-<x86|arm>.fpk`，以及对应的 `SHA256SUMS-<版本>.txt`。

- 包版本默认为 `<最近的 tag>.<tag 之后的提交数>`，例如 `0.5.1.90`，与上游同步后会自动递增。需要指定时设置 `FPK_VERSION`。
- 程序版本：HEAD 正好在 tag 上时使用该 tag，否则为 `dev`，与 `scripts/build.sh` 的规则一致。可以用 `DENOVA_VERSION` 覆盖。
- 二进制使用 `CGO_ENABLED=0` 交叉编译，不依赖 NAS 上的 libc。

## 安装与使用

安装向导会询问服务端口（默认 18080）和登录用户名、密码。安装完成后，从飞牛桌面图标打开 `http://<NAS 地址>:<端口>/`，用向导里设置的账号登录，再到 Denova 设置中配置模型 API。

| 内容 | 位置 |
| --- | --- |
| 创作数据（`DENOVA_DIR`） | 共享文件夹 `denova`，卸载应用后保留 |
| 端口与数据目录记录 | `${TRIM_PKGETC}/settings.env` |
| 运行日志 | `${TRIM_PKGVAR}/logs/denova.log` |
| Agent 运行时的 HOME | `${TRIM_PKGVAR}/home` |

- 安装时会开启“允许局域网访问”并写入登录账号。之后可以在应用设置向导中修改，留空的项保持不变；也可以在 Denova 设置中修改。
- 端口安装后固定不变，需要更换时请重新安装。
- 程序升级只通过 fpk 进行。fpk 构建时注入了 `buildinfo.InstallManager=fnos`，所以 Denova 设置页只检查新版本，不提供应用内下载或上传安装包。

## 已知限制

- 网页抓取的浏览器渲染兜底需要 Chromium，NAS 上一般没有，该功能会降级为普通抓取。
- Codex、Claude Code 等外部 Agent 运行时需要自行在 NAS 上安装对应的 CLI。默认可用的是 Native 运行时。
- 安装向导的文案只有中文，飞牛向导不支持多语言资源。
