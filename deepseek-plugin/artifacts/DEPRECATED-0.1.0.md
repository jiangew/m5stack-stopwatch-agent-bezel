# 0.1.0 已废弃 — 禁止安装或启用

[0.1.0 tarball](<dsh-agentbezel-navigation-0.1.0.tgz>) 保留原始字节，仅供事故复现，未覆盖。

该版对六个 profile 声明 Control+Alt+Arrow。DSH 0.2.0-rc.2 的真实 `ShortcutRegistry.register` 在任何设备注册时都会检查全部 profile，因 reserved defaults 抛错，导致用户实际安装后插件激活失败；旧应用层重抛异常可能重复触发 boot 失败。旧插件已经由 Codex 禁用并恢复 provider，本次没有再次操作 live profile。

请勿使用该旧包；0.1.1 修复仅在三个允许 profile 设置 defaults，其余省略为 unbound，并保护注册与释放异常。[修复说明及验证局限](<../README.md>)。这是仓库本地废弃说明，不代表执行过 npm registry deprecate。
