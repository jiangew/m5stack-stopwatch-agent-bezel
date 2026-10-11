# AgentBezel：DeepSeek Harness navigation plugin

独立、可选择安装的第三方 browser-client 插件，适配所检查的 DSH **0.2.0-rc.2** DOM/loader。不是 DeepSeek 官方插件。本次 **0.1.1 修复只修改本插件目录**，未安装或启用新版，未修改 App、live profile/provider 或真实用户配置。Host `apply()` 为空。

## 0.1.1 事故修复；0.1.0 已废弃

用户实际安装 0.1.0 后插件激活失败，Codex 已禁用旧插件并恢复 provider。原因不是“仅不支持平台不分派”：宿主在注册任意一个命令时会遍历六个平台 defaults；0.1.0 在所有平台声明 Control+Alt+Arrow，遇到 reserved default 即抛错，即使当前机器是受支持的 macOS Desktop 也失败。旧应用层还把异常重新抛给宿主，存在重复 boot 失败风险。

**禁止再安装或启用 0.1.0**。[旧 0.1.0 tarball](<artifacts/dsh-agentbezel-navigation-0.1.0.tgz>) 仅保留事故复现证据，不覆盖、不重打包；[废弃说明](<artifacts/DEPRECATED-0.1.0.md>) 随附。这里只作本地废弃标记，没有操作 npm registry。

0.1.1 仅为三个获准 profile 声明 defaults，另外三个省略（注册 schema 不接受显式 `null`，最终 catalog binding 为 `null`）。新增真实 `ShortcutRegistry.register` 回归，覆盖源码和生成 bundle 的全部命令/平台，旧 definition 必须被拒绝。注册失败会逆序释放已成功注册项、使保留回调失效，且不向宿主抛异常。release 失败仍继续清理其它项；effect 安装异常和诊断输出异常也隔离。只输出下列固定诊断，不输出 exception/用户数据：

```text
AgentBezel: navigation commands disabled because shortcut registration failed; check plugin/host compatibility.
AgentBezel: shortcut cleanup failed; navigation actions disabled; reload or disable this plugin.
```

清理边界：若宿主 release 自身抛错，插件只能保证尝试全部已取得的 disposer、阻止自己的遗留回调动作，不能保证宿主移除失败的 catalog 项。若宿主在产生 disposer 前先修改自身注册表再抛错，插件也没有公开 API 可撤销该未返回的句柄；不访问宿主私有 maps，不重试启动。

## 行为

| Companion 手势 | 命令 ID | 默认物理键 |
| --- | --- | --- |
| 上 | `agentbezel.previousThread` | Control + Alt + ArrowUp |
| 下 | `agentbezel.nextThread` | Control + Alt + ArrowDown |
| 右 | `agentbezel.toggleView` | Control + Alt + ArrowRight |
| 中心 | 无 | 不注册 |

- 上/下只按**当前主 sidebar 实际渲染顺序**切已有 thread，跨项目、嵌套项目；不按更新时间自行排序，不循环，不创建会话。
- 关闭的项目可通过其 `div[role=treeitem][data-row-key^=workspace:]` 本身展开；绝不点击内部新建按钮、项目菜单或调用 `openWorkspace`。
- **每次动作最多一个 click**：若需要展开项目或更多行，本次只准备，不切 thread；等待渲染结束后再转动一次。大量折叠项目可能需要多次手势。边界 no-op。
- overflow 的 `aria-expanded=false` 既表示首次折叠也可能表示只加载了部分本地行。会继续逐次展开直到 `true`，**从不点击 `true` 的“收起”按钮**。running rows 可穿插被隐藏的 idle rows，因此在认定相邻会话前先完整展开当前/候选所属项目，不猜测中间顺序。
- 未加载远程列表不猜序：只读 `sessions.list.phase` / `workspaces.list.phase`，不是 `ready` 则等待。没有自行 RPC、远程分页、标题查询或后台重试。加载后需要下一次手势。
- thread click 后，必须收到 DOM `aria-selected=true` 确认，并且 sidebar selection 与主 conversation 的 opaque session ID 一致、内容不处于 `settling`，后续 thread 手势才可运行。没有确认则保持 no-op；外部手动导航/重新渲染移除旧节点或重载插件可解除过期等待。展开/切视图同样等待 DOM 确认。
- 右只切主窗口 Chat / Trajectory；必须 developer-tools setting 开启、`slots.entries('conversation.view')` **恰好两个且唯一 ID 是 `chat` 和 `trajectory`**、DOM 恰好两个直接子 `button[role=tab]`、仅一个选中。采用相同 registry/render 顺序，不看标签、不猜自定义 tab。不主动开启 developer tools。

## 安全与范围

- 仅 `ctx.shortcuts.register` 三个命令；没有全局键盘 listener、合成 KeyboardEvent、dispatchEvent、OS bridge、HTTP/RPC、定时器或 delayed click。
- `regions: ['page', 'editable']`, `modals: []`。Desktop 服务可能优先分派并绕过 region/modal，因此 **resolve 和 run 都额外检查** region/modal/focus/DOM。系统 held-repeat 由已有 shortcuts 服务抑制，不再实现连发。
- 仅当前 focused 顶层 document；唯一主 frame、主 center conversation、主 sidebar tree。失焦、隐藏、iframe、同页多个 conversation/frame、modal/menu、主面板不是 conversation、结构不匹配、disabled/hidden target、加载中均 no-op。编辑框可有草稿，插件不读取或改写草稿。
- **不枚举 OS/Electron 其它窗口**，无法单凭 DOM 证明进程只有一个窗口；本插件不能宣称“跨 OS 多窗口自动拒绝”。Companion process-targeted 事件由系统送到 focused native window。先用单主窗口验收；多个顶层窗口不在本交付的已验证范围。不扩展 AX/window-list 权限。
- 只读取白名单 role/ARIA、CSS classes、DOM父子结构、opaque row/session IDs、visibility/focus/readiness、activePanelId、developerTools boolean 和 registry IDs。不读取标题、正文、项目路径、标签/aria-label、草稿、模型 session/workspace records。测试的内容读取器直接抛错。
- 不读写 conversation localStorage（实际上没有任何 storage API）。**点击原生 UI 的宿主 handler 仍可能按宿主原有行为保存视图偏好/项目展开状态**；本插件不拦截也不自行写这些状态。
- 源码白名单包括 release 哈希 CSS class；DSH 升级改变 DOM 时必须重新检查并更新测试，不用模糊 class/text fallback。归档候选、选中会话被折叠、搜索结果、侧栏 rail/collapsed 不猜测，只 no-op。不会自动打开侧栏或跳过归档条目。

## 平台真实限制

非空 defaults 使用 schema 中正确的 `['control', 'alt']`，**不是 `ctrl`、不是 `primary`/Command**。macOS Alt 对应 Option。真实宿主没有名为 `validateDefinition` 的函数；验证入口是 `ShortcutRegistry.register`，仅 `undefined` 跳过，显式 `null` 会抛错。配置文件 override 支持 `null` 不代表注册 defaults 支持。

| Profile | Control+Alt+Arrow admission | 0.1.1 注册 default / effective catalog |
| --- | --- | --- |
| desktop:macos | allowed | 物理键绑定 |
| desktop:windows | allowed | 物理键绑定 |
| web:windows | allowed | 物理键绑定 |
| web:macos | reserved | 省略 / `null`（命令注册但无默认键） |
| desktop:linux | reserved | 省略 / `null`（命令注册但无默认键） |
| web:linux | reserved | 省略 / `null`（命令注册但无默认键） |

声明默认值不等于服务/浏览器/OS一定投递；插件不绕过 reserved、冲突、系统辅助功能或浏览器拦截。macOS VoiceOver 可能使用 Control+Option。若在 web macOS/Linux 使用，当前服务限制下本物理映射不可用；需用户另行批准键位/Companion 同步变更或宿主服务升级。本交付不改键位、不改宿主。

## 本地构建和测试（无需安装依赖）

在本插件目录运行：

```sh
node scripts/build.mjs
node scripts/build.mjs --check
node --test test/*.test.js
```

Node >=22；构建使用**已存在的 TypeScript 5.9.2**。脚本先检查 `DSH_PLUGIN_TYPESCRIPT`，再本地 package resolution，再常见 Homebrew/global 路径。也可显式指定：

```sh
DSH_PLUGIN_TYPESCRIPT=/path/to/existing/typescript node scripts/build.mjs
```

没有 npm install/npx/download。版本不符或编译器缺失明确失败。`--check` 比较确定性产物，检测过期文件。

Browser 产物是宿主真正支持的 `window.__ModuleLoader__.load({ id, factory })` **lazy CommonJS factory**：TypeScript 把两个 ESM 模块编译成 CommonJS，脚本把它们打包进局部 module table，所有执行留在 factory 内。**不是直接加载源码 ESM，不是 System.register**。Host 产物保持 ESM 空 apply。没有运行时 npm dependency；使用已有宿主注入服务。

可选只读核对源码副本（不启动/安装宿主）：

```sh
node scripts/check-installed-contract.mjs /path/to/dsh/node_modules
```

该检查读取指定宿主源码，直接提取并执行**原样的完整 `ShortcutRegistry` 类和它依赖的 binding/configuration 函数**，不重写规则；仅 snapshot store 是轻量替身。源码和生成 bundle 各在六种环境注册全部三个命令，验证实际 catalog/bindings、disposal，逐命令证明旧六平台 defaults 必失败、显式 `null` 必失败，同时保留 selector/registry 和 held-repeat 证据检查。不会启动宿主、读 profile、安装或启用插件。

`node --test` 在本工作区自动使用已有的 inspection 副本；可设置 `DSH_INSPECTED_NODE_MODULES=/path/to/dsh/node_modules`。缺失默认副本时会**显式 skip**真实宿主测试，不假称通过；显式指定错误路径则失败。发布前必须单独运行上方 contract 命令，不能以 skip 放行。提取边界变化会失败，升级宿主需重新检查。

本次 0.1.1：96 tests passed、0 failed、0 skipped；build/check 均通过。真实源 SHA-256 `431343dccb72093c5732151616ea28dab7177ba94940d2daa29f9fdc9d5a18a6`。源码/bundle 共 36 次命令注册、36 次旧 definition 拒绝和 36 次显式 null 拒绝；仅三种允许 profile 有三项有效键位，另三种 catalog 全为 null。第 1/2/3 项注册失败、apply 不抛、逆序 cleanup、release/effect/logger 抛错均有回归。没有完整 Cordis boot、真实渲染、OS 键投递或硬件验证。

测试覆盖：跨项目/嵌套项目/flat 顺序、边界、collapsed/overflow/interleaved running rows、未知结构、失焦/modal/重复视图/ready guards、三个命令和六平台 defaults、run重验证、ACK pending/disposal、factory materialization和空Host。使用自包含 **fake DOM**；本次检查的本地 package locations 没有 jsdom/linkedom，不下载。fake DOM 非完整浏览器，不将通过单元测试宣称真实 UI/硬件已经验证。

## 将来安装（仅用户批准后手工执行；本次未执行）

1. 关闭目标 Harness，确认实际使用的**外部 profile**并备份。Desktop 源码使用 `<DSH_HOME>/profiles/desktop`；`DSH_HOME` 默认用户主目录下 `.dsh`，有 override 时以实际配置为准。Web 使用其独立启动 profile；不要把本插件写入 App bundle 内或假定 Desktop profile 就是当前 web profile。
2. 构建、测试、核对 DSH 版本。已提供打包好的产物，也可以在本插件目录生成 tarball：

   ```sh
   mkdir -p outputs/local
   npm pack --ignore-scripts --cache ./outputs/local/npm-cache --pack-destination ./outputs/local
   ```

   新包和 npm cache 仅落本插件目录的 ignored `outputs/local/`，不进入历史 artifacts、不覆盖 0.1.0。仅打包，无安装/脚本执行。不要使用未经检查的远程同名包。
3. **推荐由 Harness 的插件管理 UI安装本地打包文件并启用该 bundle**，前提是你的版本提供本地包输入。若没有，使用明确的外部 profile 手工步骤：

   ```sh
   # 进入已确认、已备份且已停止运行的外部 profile；不要在 App 目录执行。
   pnpm add /absolute/path/to/dsh-agentbezel-navigation-0.1.1.tgz --ignore-scripts
   ```

   这是将来经批准的安装动作，会改变该 profile 的 dependencies/lock/node_modules；本次没有执行。包本身没有 dependencies。用该 profile 已配置的 package manager，勿擅改其 pnpm 配置。
4. **保留现有 manifest 字段和 bundles**，在该 profile 的 `dsh.profile.bundles` 数组追加 `dsh-agentbezel-navigation` 一次。选中后包内 bundle patch 会插入 `id: agentbezel-navigation` / `name: dsh-agentbezel-navigation` 的空配置 Host 节点，Host loader 再通过 `dsh.client` 和 `exports['./client']` 发现 browser half。不要同时手工往用户 patch 插入同一节点，会重复注册。
5. 完全重启目标 Harness（或按版本支持的插件 reload），Web 刷新**原来使用的 URL**。本插件不启动替代 server，不声称 HMR 自动更新。设置中检查三条命令、无 duplicate/conflict/error；先键盘测试再启用 Companion process-targeted 按键。

手动 manifest 合并示意（**非完整文件，不可覆盖原文件**）：

```json
{
  "dependencies": { "dsh-agentbezel-navigation": "file:/absolute/path/to/package.tgz" },
  "dsh": { "profile": { "bundles": ["...保留原有bundle...", "dsh-agentbezel-navigation"] } }
}
```

禁用/卸载：先在插件管理 UI禁用 bundle，或从外部 profile 的 bundle 列表仅移除本项；重启/刷新并确认三个命令消失。之后才按 profile 的 package manager remove 本包。不要删除或覆盖其它 profile 配置，不触碰 App 内容。

## 安装后验收清单（尚未执行）

- 单 focused Desktop 主窗口，至少两个项目和多个已存在 thread；验证上下跨边界和不循环。
- 折叠项目、超过五条 idle 及穿插 running thread；本次仅展开，下一次按实际顺序切一个。
- 关 developer-tools setting / 加自定义第三 tab：右 no-op；两标准 tabs时双向切换。
- 草稿保持原样；菜单/modal/失焦/同页嵌入conversation/列表加载中/快速重复手势均不误操作。
- 列表切换失败无 ACK时不重复 click；可手动导航或 reload恢复。
- Process-targeted Companion键、真实 native窗口投递和 C152转动需另外验收；本仓库测试不验证这些层。

## 核对依据

只读检查 DSH 0.2.0-rc.2 包：`ui-workspace` client register 104–205、workspace row 1285–1290、session row 1590–1599、overflow 2598–2609、collapsed idle过滤2122–2133；`ui-conversation` tabs 16512–16525、registry及developerTools 17972–17984；`client-shortcuts` modifiers 33–55、平台policy109–130/214–242、dispatch660–705；`client-modules` lazy-CJS契约16–23；`dsh-app-boot` patch schema2721–2760；Desktop外部profile初始化 sibling main 3258–3305/3515–3517。这些为静态源码证据，不是已运行安装证明。
