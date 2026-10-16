# StopWatch AgentBezel based on M5Stack C152 StopWatch Dev Kit（ESP32-S3R8）

[English](README.md)

**Stopwatch AgentBezel C152** 是面向 **M5Stack StopWatch Dev Kit C152**
的独立、非官方开源五屏控制界面：机器人首页、Codex Micro 兼容面板、DeepSeek Harness 激活、super.engineering
项目控制、Hermes Desktop 会话控制，并提供本地额度面板和可选 USB 麦克风。

Codex Micro 兼容性为实验性且未文档化功能。运行标识、配对身份、音频名称与
Companion 身份保持不变。五屏体验需要匹配的源码构建 USB-mic 固件与 Companion。
验证仅覆盖一套本地环境，不代表所有应用版本均兼容。

## 当前版本速览

另有独立选择的 [Home IMU 交互试验](docs/HOME_IMU_PILOT.md)：使用
`m5stack-stopwatch-home-imu` 环境探索拿起、倾斜和放稳。默认发布环境不启用；
合成测试与原生预览不代表实机误触率、物理响应延迟或功耗已验收。
试验首版（`fe28100`，应用摘要前缀 `5bdd3ed9026a`）已于 2026-10-16 仅写入 app0，保护区与应用摘要校验通过；用户确认三轮
拿起／倾斜／放稳反馈正常、方向自然，后续试验也反馈正常，并选择不再追加至30轮。
实际动作分母未确认，不报告命中率。独立桌面静置600.80秒，非预期拿起与传感器读取错误
均为0；干扰场景误触、物理 P95 延迟与耗电仍待测，当前属于试验版本。
连续动作优化版本（`43d8e91`，应用摘要前缀 `6cc50998db76`）已于2026-10-16仅写入app0，
应用摘要与保护区校验、重启、IMU诊断和3.008秒USB麦克风短录音检查通过；用户确认拿起
接倾斜“更贴手，迟滞明显减轻”。新版仅起止读取状态的独立桌面静置601.22秒，非预期
拿起与读取错误新增均为0。加速度滤波按实际采样间隔使用60ms时间常数，
IMU帧间隔从绘制开始计时，Held放稳判据缩短为连续静止600ms；首次进入和异常恢复
校准仍为1500ms，并修复自动唤醒重复绘制。保留已确认的roll/pitch方向映射及所有输入保护。
连续重绘可能增加功耗，固定轮数统计、干扰误触和物理端到端延迟仍待量化；
首版600.80秒零误触不能用作新版本验收。

角色滑动恢复版（`df5480c`，应用摘要前缀 `c83363fcc22e`）已于2026-10-16仅写入app0，
应用摘要／保护区校验、重启、已校准IMU诊断及3.008秒USB麦克风短检查通过。
仅成功的首页上／下／右滑切换角色后恢复已有校准，保留触摸／振动抑制及250ms静默。
用户初次反馈持续倾斜慢半拍，随后反馈“现在测试效果比较好了”；期间没有追加烧录或调参。
随后明确确认“包括滑动后，当前手感可以接受”，保留当前固件，不追加调参。
用户选择本次不做新版静置复测；定量误触、物理端到端时延和耗电仍未测。

Companion build14 统一四个 Agent 桌面的前后台处理：左滑仅选择桌面；目标已在前台时
直接操作，未启动或在后台时点击中央启动或唤起。Mac 切换应用后保留手表所选桌面，
目标退到后台时恢复中央唤起状态。中央点按同时支持“进程仍在但窗口已关闭”的重新打开。
DeepSeek、SUPER、Hermes 还检查实际窗口：关闭最后一个窗口后，下一次每秒检查恢复
**TAP TO OPEN**；慢速唤起即使曾超时，窗口真正就绪后也自动恢复操作，不需再次点中央。
这次 Companion 更新最初沿用 build9；历史九图首页与本地已部署的17页双阵营版本在下文分别说明。
详见[功能诊断与验收记录](docs/CONTROL_AVAILABILITY.zh-CN.md)。

- 五屏循环：机器人首页 → Codex / ChatGPT → DSH → SUPER → HERMES → 首页。
- 当前本地清晰度修复版：`24676b8`／`298f1c7b3ef4`已于2026-10-17仅写app0，
  独立ROM校验、保护区一致性、HID／IMU及USB麦克风短采集检查通过；修复霸天虎缩图混叠，
  用户确认“清晰度明显改善，交互正常”。下述首页用户验收属于上一镜像；本版精确延迟、
  静置误触率及功耗仍未量化。
- 未烧录的全局轻短震候选：当前源码统一强度160，首页／普通触摸16ms、滑动／按键20ms、
  唤醒12ms、旅行关机确认24ms。短震活跃时保留重绘请求，停马达后继续绘制；首页首个回应帧
  先提交再启动短震，快速重复点击也先结束旧脉冲。普通触摸的Mac按键脉冲仍为55ms，马达在
  16ms时停止；关机提示等待总计仍为550ms。已验收镜像`298f1c7b3ef4`及其原物理反馈仍为
  已部署基线。候选起转可靠性、物理脉宽、手感与噪声尚未实测，模拟边界不证明实机声音已降低。
- 首页：大黄蜂头像＋八位汽车人＋八位霸天虎，共17页。上滑随机汽车人、下滑随机霸天虎，
  同阵营排除当前角色、跨阵营八人均可选；右滑固定回到头像。按下立即缩小3%，500ms内松手播放
  约600ms回应并轻震一次25ms，连点立即打断重触发。源码`81f91fef`／应用摘要前缀`0aaa4606a3c3`
  已于2026-10-16仅写app0，独立ROM校验、保护区一致性、HID／IMU诊断及USB麦克风短采集通过。
  用户确认角色切换、点击回应均正常，滑动后倾斜跟随可以接受；本版未量化静置误触、物理延迟或功耗。
  历史九图首页 `4b1b6e9` 的 USB-mic 应用于2026-10-14刷入，仅写app0。
  应用摘要、受保护元数据、重启、USB 纯输入音频、BLE HID 状态 RPC 及短录音检查均通过，原配对配置保留。
  用户已于2026-10-14确认该历史九图首页交互正常；上述历史IMU滑动恢复反馈属于`df5480c`／`c83363fcc22e`。
  延迟、帧率、震动时长及PSRAM余量尚未量化测量。
- DSH：桌面标题显示为 `DSH`，沿用 SUPER 的四色三角布局和标题字体；上下按侧栏顺序切换已有 thread、跨项目边界，
  右滑切“对话／轨迹”。需要配套导航插件；已激活时中央与实体操作键保持无动作。
- 所有 harness 未运行时，左滑仅选择对应桌面，中央点按才启动；启动中阻止连点，失败可重试。
  **CODEX 所有状态始终保留原仪表盘 UI**，不改四向布局、不添加新提示；仅未启动时中央改为启动／重试。
  另外三个桌面显示启动提示。已运行时保留既有控制；四个 Agent 均按真实前台状态决定是否等待中央点按。
- 专属导航保留 350ms 释放门控；切屏/启动保留 800ms 保护，按键序列间隔 30ms。

详见[变更及验证记录](docs/DEEPSEEK_BLINK.md)。
**DSH 命名更新已于 2026-10-12 刷入；用户确认标题及上／下／右操作正常。**
[此前首页验收](docs/superpowers/plans/2026-09-21-home-equal-spacing-half-volume.md)和
[导航验收](docs/superpowers/plans/2026-09-12-paced-navigation-verification.md)
上述记录覆盖历史版本；本次 DSH 验收范围见当前变更记录。

## 机器人首页与四个工作区

首页需要匹配的源码构建 Companion 和 USB-mic 固件。开机、重连和 Companion 启动
都选中首页，不激活 Mac 应用，Mac 前台变化也不会离开首页。17页双阵营包括大黄蜂头像（默认）、八位汽车人（大黄蜂全身、擎天柱、爵士、热破、千斤顶、探长、铁皮、救护车），以及八位霸天虎（威震天、红蜘蛛、声波、震荡波、惊天雷、闹翻天、闪电、大火车）。角色区域 x=64..402/y=64..398 内按下立即缩小 3%，未滑动且
500ms 内松手时播放约 600ms 的角色回应；未烧录候选轻震一次16ms（已部署基线为25ms）。
连点可立即打断旧动画、重新回应。
大黄蜂头像点头，全身挥手；擎天柱举拳点头，爵士双手点赞，热破挥手前倾，千斤顶举扳手，探长胸前握拳致意后回到敬礼，铁皮举拳，救护车做 OK 手势。
触点移出角色区或位移达到 52px 即取消点击。上滑在八位汽车人中均匀随机选择，下滑在八位霸天虎中均匀随机选择；同阵营排除当前角色，从头像或另一阵营进入时八人均可选。右滑固定回到大黄蜂头像，不调用随机数。
同方向可以连续使用；每次有效选择保留320ms切换过渡，候选一次20ms振动（已部署基线为40ms），离线有效，
持续滑动不重复触发。左滑保留工作页循环。熄屏首触只唤醒，离页、熄屏和电源确认取消动画，
既有电源长按保持。所有图像无装饰外圈。
固件在 PSRAM 缓存17张待机图和当前角色最多两张动作图，像素槽位上限19张／3,420,000字节（不含帧缓冲等内存）。换角色先释放旧动作；同角色重复点击直接复用。新增霸天虎使用单张回应姿态持续约600ms并叠加小幅原生变换，旧汽车人动作时序保持。
待机缓存不足可单张复用；动作缓存不足时保留原角色图做轻微动作，不会每帧反复解码 JPEG。静止时只因状态变化重绘。
原生预览使用同一缓存渲染路径；构建和预览不等于 C152 延迟实测。角色互动静音且不发送
Mac 操作，USB 麦克风和 Codex 完成提示音保持原样。
本地17页版本（`81f91fef`／`0aaa4606a3c3`）已通过用户切换、点击和连续IMU跟随试用。图片及缓存容量不代表实测延迟或功耗；历史IMU与静置结果仍归各自版本，本版未做静置复测。详见[Home IMU验证记录](docs/HOME_IMU_PILOT.md)。
[已部署九形象回应的历史原生预览](artifacts/robot-home-responses.png)。
首页亮屏且 Companion 就绪时，左滑触发与其他桌面相同的一次振动；离线左滑仍无振动。
振动仅确认手势反馈，不代表 Mac 激活成功。
连接和电量来自真实状态，不使用预览中的固定示例值。

<table>
  <tr><th>大黄蜂头像（默认）</th><th>大黄蜂全身</th><th>擎天柱</th><th>爵士</th></tr>
  <tr>
    <td width="25%"><img src="artifacts/robot-home-bumblebee.png" alt="首页大黄蜂头像"></td>
    <td width="25%"><img src="artifacts/robot-home-bumblebeefullbody.png" alt="首页大黄蜂全身"></td>
    <td width="25%"><img src="artifacts/robot-home-optimus.png" alt="首页擎天柱全身"></td>
    <td width="25%"><img src="artifacts/robot-home-jazz.png" alt="首页爵士全身"></td>
  </tr>
  <tr><th>热破</th><th>千斤顶</th><th>探长</th><th>铁皮</th></tr>
  <tr>
    <td width="25%"><img src="artifacts/robot-home-hotrod.png" alt="首页热破全身"></td>
    <td width="25%"><img src="artifacts/robot-home-wheeljack.png" alt="首页千斤顶全身"></td>
    <td width="25%"><img src="artifacts/robot-home-hound.png" alt="首页探长全身"></td>
    <td width="25%"><img src="artifacts/robot-home-ironhide.png" alt="首页铁皮全身"></td>
  </tr>
  <tr><th>救护车</th><th></th><th></th><th></th></tr>
  <tr><td width="25%"><img src="artifacts/robot-home-ratchet.png" alt="首页救护车全身"></td><td width="25%"></td><td width="25%"></td><td width="25%"></td></tr>
</table>

保留的大黄蜂头像与八张内建 imagegen 全身插画均为非官方同人素材，以 baseline JPEG
内置在固件中；并非官方授权素材，运行时不联网获取图像。离开首页后，下次进入会重置为大黄蜂。

<table>
  <tr><th>Codex Micro</th><th>DSH</th><th>super.engineering</th><th>Hermes Desktop</th></tr>
  <tr>
    <td width="25%"><img src="artifacts/dashboard-preview-v2-round.png" alt="含六项控制、额度与电量的 Codex Micro 面板"></td>
    <td width="25%"><img src="artifacts/deepseek-workspace-preview.png" alt="DSH 四向 CYCLE、PREV、NEXT、VIEW 布局"></td>
    <td width="25%"><img src="artifacts/super-workspace-preview.png" alt="四色三角形、无独立中心边框的 SUPER 屏幕"></td>
    <td width="25%"><img src="artifacts/hermes-workspace-preview.png" alt="含 CYCLE、PREV、NEXT、OPEN 的 HERMES 屏幕"></td>
  </tr>
</table>

以上是 native framebuffer 设计预览，不是真机照片。

**左滑循环：首页 → Codex / ChatGPT → DSH → SUPER → HERMES → 首页。**
当前 Codex / ChatGPT 入口使用 `com.openai.codex`，只算一个目标，不拆成两个。
从首页左滑选择 Codex：未运行时仅显示待启动页，点中央才启动；已在前台时直接可操作，后台运行时等待中央点按唤起。
返回首页不改变 Mac 前台。找不到或无法激活的目标不会被自动跳过，错误页可点中央重试或左滑继续。
原来的“返回之前应用”已被固定循环替代。

| 输入 | 机器人首页 | Codex Micro | DSH | SUPER | HERMES |
| --- | --- | --- | --- | --- | --- |
| 左实体键 / 右实体键 | 无动作¹ | Push to talk / Voice Chat | 无动作¹ | 无动作¹ | 无动作¹ |
| 中心短点 | 按压轻缩／角色回应＋短震 | 待启动时启动／重试；操作页 Send | 待启动时启动／重试；操作页无动作 | 待启动时启动／重试；操作页无动作 | 待启动时启动／重试；操作页无动作 |
| 左滑 | 选择 Codex | 选择 DSH | 选择 SUPER | 选中 HERMES 待启动页 | 进入首页 |
| 上滑 | 随机选择汽车人（同阵营排除当前） | 应用现有映射 | 上一条 thread | 上一个项目 | 浏览上一个会话 |
| 下滑 | 随机选择霸天虎（同阵营排除当前） | 应用现有映射 | 下一条 thread | 下一个项目 | 浏览下一个会话 |
| 右滑 | 固定回到大黄蜂头像 | 应用现有映射 | 对话／轨迹切换 | 下一个会话 Tab | 打开本次选择；无选择则无动作 |
| 电源操作 | 桌面休眠 / 旅行关机 | 相同 | 相同 | 相同 | 相同 |

¹ 专属屏幕和设备侧隔离需要用户明确选择、且匹配的 `usb-mic` 固件。
默认无线固件仍显示 Codex 面板；Companion 方向控制仅在真实 `--watch` 中启用。

## Codex Micro 工作区

默认仪表盘显示 Agent 状态、本周 Codex 剩余额度、reset 倒计时、电量和
充电/Dock 状态，以及 Codex、BLE 和额度同步是否健康。Agent 完成时会变绿并
播放柔和提示音。左侧实体键是 Push to talk，右键是 Voice Chat，中央圆盘是
Send，上/下/右仍在 ChatGPT Desktop 中配置，Companion 真实 watch 模式下左滑用于工作区循环；实体键和触摸手势均有
振动反馈。

正常中心圆采用四行均衡布局：连接状态、剩余额度、重置倒计时、电量。
删除冗余的 `WEEKLY LEFT` 标签；异常状态仍保留 `SYNC STALE`、`WAITING CODEX`
等诊断提示。

兼容的 `Codex Micro` BLE HID 通道负责控制；本地额度 companion 使用独立的
项目自有 BLE GATT 服务，因此手表不会保存 OpenAI token。开发时使用的
ChatGPT Desktop 仅暴露一个 Mic key，而非单独的 `ACT10` 和 `ACT11`：
右键有意发送可配置的 `ACT09`（`Command Key 4`），不是 `ACT11`。

电池供电时，屏幕两分钟后变暗、五分钟后进入桌面休眠；Dock Mode 分别延长到
十和三十分钟。桌面休眠保持 BLE 提醒在线。双击红色电源键执行经固件确认的
旅行模式关机，按电源键或接入 USB 即可唤醒；长按中央六秒是带未接收提醒警告的
较慢旅行模式兜底。物理电源切换的 soak 测试仍待完成，因此时间和唤醒行为在
清单完成前均为实验性。

## DeepSeek Harness 工作区

**DSH** 通过准确的应用 bundle `com.deepseek.dsh` 激活桌面客户端，不打开浏览器 URL
或 CLI。从 Codex 左滑进入；从 DSH 左滑选择 SUPER。四色三角形布局与 SUPER 一致：
上 PREV、下 NEXT、右 VIEW、左 CYCLE。上/下按侧栏顺序选上一条/下一条已有 thread，
到项目边界继续相邻项目；右滑在当前主工作窗口“对话／轨迹”之间切换。未启动时中央用于启动／重试；
真实激活后的中央及实体操作键无动作。待启动／启动中／错误页仅允许左滑和有效的中央启动，不发送导航键。

当前 Harness 没有对应原生快捷键，需要另行审阅并安装本项目的
[DeepSeek 导航插件](deepseek-plugin/README.md)。Companion 仅向复核后的前台 DeepSeek 进程
投递固定 `Control-Option-Up/Down/Right`，由插件接收，不发送 Codex 原生方向事件。
插件仅在浏览器本地识别结构性行 ID，不读取标题、消息正文、草稿、凭据，也不创建新会话。
轨迹页必须已可用；界面结构不符或状态有歧义时不执行，不自动开启开发者工具。
上一轮插件 **0.1.1** 与 build8 已完成用户实机导航验收；不要安装导致启动故障的旧插件 0.1.0。
build9 新增三连眨眼／角色振动／通用中央启动已另行实机验收；更新签名后曾重新授权 Companion 并重启，三向导航恢复正常。

激活失败不跳过目标；共享 5 秒心跳、15 秒租约和回首页机制。额度仍为 Codex 额度。

## super.engineering 工作区

识别运行中应用时兼容当前 bundle `engineering.super.app` 和旧 bundle
`com.zarifpour.superconductor`；启动缺失应用时使用当前 bundle。在应用快捷键中配置：
Previous Project = `Control-Option-Up`、Next Project = `Control-Option-Down`、
Next Tab = `Control-Option-Right`。上/下/右仅定向发送给该前台进程。
左滑进入 Hermes，不再返回任意旧应用。

## Hermes Desktop 工作区

使用本次源码构建的 **Companion** 与匹配的五屏 USB-mic 固件。
SUPER/HERMES 使用专属 `host.workspace_navigation`，不同时发送 Codex 原生方向事件。
Codex 上/下/右绑定保持不变，并实测 Codex 无后台动作；安装、回滚保持组件兼容。
构建号、源码提交及默认关闭的限时导航诊断详见 [Companion 文档](companion/README.md)。

从 SUPER 左滑选择 HERMES：已在前台时直接启用导航；否则显示 **TAP TO OPEN**，
Mac 保持原前台，不启动或激活后台 Hermes。短点中央正方形内部才启动客户端，显示 **OPENING**。
实际确认 Hermes 前台后才启用下面的方向导航。失败或 3 秒未确认时显示
**TAP TO RETRY**，不自动发起打开请求；后续实时确认所选前台窗口就绪后自动恢复操作。
等待期间忽略重复点按。
待启动、启动中、失败状态均屏蔽上/下/右，左滑均进入首页。
Dock、Command-Tab 切换保留手表所选桌面；目标退到后台时恢复中央唤起状态。
重连或 Companion 重启则选中首页。包括 Codex 在内的工作页每 5 秒续租，15 秒到期后回首页；
必须收到首页确认才能再次接受工作页心跳，防止旧心跳把首页覆盖。切换页面不唤醒屏幕。
本次需成套安装、成套回滚，详见[首页验证记录](docs/superpowers/plans/2026-09-15-robot-home-verification.md)。

点按须按下和释放均在中央内部、少于 500ms，且全程未达到滑动阈值，
与方向操作共享 800ms 防抖。熄屏后第一次点按只亮屏，第二次才启动；
操作页中央短点无动作，长按电源流程保留。

**Desktop 自动拉起与屏幕心跳不是一回事。** Companion 每 5 秒的 HID 心跳
只续租屏幕，不启动应用。本机另外安装的 `ai.hermes.desktop` 任务因 `KeepAlive`
在客户端退出后重复拉起；经批准已备份、卸载并禁用，原 plist 保留供恢复，
gateway/dashboard 不变。其他安装不一定有这个任务，不应盲目停用其他服务。
恢复方法见 [Companion 文档](companion/README.md#hermes-desktop-launch-policy)。

中央启动统一调用 `NSWorkspace.openApplication`，包括 Hermes 已在后台运行时；
启用激活、禁止创建新实例。针对前台 Hermes 的准确进程，辅助功能只获取 focused/main
窗口句柄并请求窗口聚焦，不读取内容或标题；三个快捷操作桌面另在本机有限检查 AX 窗口句柄
和角色，用于同步关窗状态。这些检查用于修复“进程已前台，但必须点击
标题栏才能导航”的情况。用户已确认交互恢复；接口返回成功不能代替其他安装上的可见窗口验收。

<table><tr><th>待启动</th><th>启动中</th><th>点按重试</th></tr><tr>
<td><img src="artifacts/hermes-idle-preview.png" alt="HERMES TAP TO OPEN"></td>
<td><img src="artifacts/hermes-opening-preview.png" alt="HERMES OPENING"></td>
<td><img src="artifacts/hermes-error-preview.png" alt="HERMES TAP TO RETRY"></td>
</tr></table>

仅匹配原生桌面应用 `com.nousresearch.hermes`，不是 CLI、网页面板或安装器。
上滑发送 `Control-Shift-Tab`，下滑发送 `Control-Tab`，保留
[原生桌面浏览快捷键](https://hermes-agent.nousresearch.com/docs/user-guide/desktop#windows-tabs--panes)。
屏幕中央会话选择器出现时，上下选择、右滑打开高亮会话。Companion 在连续上下操作间
保持自己按下的 Control，右滑才释放并清除修饰键标记；没有本次导航持有的选择时右滑无动作。
已用物理键盘确认 Hermes 0.17.0 选择器在 Control 松开时确认；不发送 Enter 或 Command-T，
右滑不是新建 Tab。
安装前请核验你的 Hermes 版本；原生浏览受聚焦 Tab 区域影响，并不保证按
Project 树排序。无需 Hermes 插件或源码扩展。Companion 不检测选择器状态，
不读取会话数据或应用设置，也不自动重试确认。本次安装已分别确认物理键盘行为
和手表上下浏览、右滑打开；重复右滑及无选择器时右滑均未新建会话、发送草稿或
造成 Control 卡键。更新 Hermes 版本后请重新验收。

## 共用配置与屏幕行为

1. 安装四个目标桌面应用。需要独立 Space 时，人工使用
   **Dock → Options → Assign To → This Desktop** 分配。
   Companion 激活应用并恢复 Hermes focused/main 窗口焦点；不创建/枚举 Space，也不按窗口内容选窗。
2. 为 `CodexWatchCompanion.app` 开启输入监控、辅助功能，并保留额度同步所需的蓝牙权限。
3. ChatGPT 控制器的 **Analog stick left** 保持未绑定，上/下/右保留现有映射。
   权限变更后重启原 Companion LaunchAgent。
4. 在源码验证、备份及当次准确端口刷写确认后，再安装匹配的 Companion 和明确选择的 USB-mic 固件。

SUPER/HERMES 使用四个向外三角形，不绘制独立中心方框。电池图标与百分比作为
整体居中显示在标题和连接状态下方，也覆盖未知电量和三位数百分比。每次本地有效滑动从
12 色池中抽取四种不同边框颜色，每个方向不沿用自己的上一次颜色，文字色保持稳定。
配色反馈独立执行 800ms 冷却；重绘、心跳、额度变化和 Dock/Command-Tab 切换不换色。
换色只是本地输入反馈，不证明 Mac 快捷键执行成功。

所有桌面保留手表的手动选择，目标退到后台时进入同一 Agent 的中央唤起状态。
心跳 5 秒、连接所有者租约 15 秒；租约过期或所有者断开则恢复首页。
前台变化不唤醒屏幕；禁用短点和实体控制也不唤醒方向桌面，真实滑动可以唤醒，
但该次唤醒滑动不同时执行看不见的操作。中央长按及红色电源行为保留。

SUPER/HERMES 隔离 Agent、Send、ChatGPT 麦克风/语音按键；模式切换释放已按住的控制，
不补发过期完成提示，USB 麦克风端点持续可用。
MainActor 路由在发送前校验前台 PID/bundle，只投递固定的进程定向按键，
不使用全局键盘注入，不读取应用内容。

### 验证状态与新安装检查

[最新首页验收](docs/superpowers/plans/2026-09-21-home-equal-spacing-half-volume.md)
覆盖用户确认的最终布局、中央降音量、角色选择及四屏操作。
[节奏导航记录](docs/superpowers/plans/2026-09-12-paced-navigation-verification.md)
包含此前导航、后台窗口恢复和录音验收；
[最初三桌面记录](docs/superpowers/plans/2026-09-04-hermes-open-physical-acceptance.md)
作为历史证据保留，不能理解为每个后续固件都重跑了全部项目。本次微调未重复录音和长时间稳定性测试。
开发机的 Command Line Tools 缺少 XCTest，完整 XCTest 仍不可执行；
Swift harness 不等于完整 XCTest。

每套新安装仍需确认完整左滑循环、未启动应用启动、失败不跳过、Space、各方向动作、350ms 导航／800ms 切屏启动保护、
随机色、熄屏唤醒、输入隔离、ChatGPT 无后台误动作、15 秒回退、断开重连、
USB 麦克风短采集、额度及原自动启动。构建和 native 预览不等于 C152 实机通过。

## 推荐安装方式

这是源码构建项目，不分发预编译 macOS App、DMG 或 PKG。推荐在将与 C152 配对的
支持蓝牙的 Mac 上，用 Codex 在本地打开本仓库。它需要 macOS 14+、Swift 5.10+
（Xcode 15.3 Command Line Tools+）、PlatformIO Core、首次刷机所需的数据
USB-C 线，以及已登录且支持 Codex Micro 的 ChatGPT Desktop。本移植只支持
**M5Stack StopWatch Dev Kit，SKU C152**，不支持其他 M5Stack 设备。

先明确要安装哪一种体验：

| 体验 | 固件 | 包含功能 |
| --- | --- | --- |
| 上文完整五屏 AgentBezel | 明确选择 `pio run -d usb-mic`＋匹配的源码构建 Companion | 角色回应首页、Codex、DSH、SUPER、HERMES、纯输入 USB 麦克风 |
| 基础 Codex 兼容面板 | `pio run -e m5stack-stopwatch` | Codex 面板和 BLE 控制，使用 Mac 所选麦克风；不含多屏首页及角色选择 |

以下提示词**明确选择五屏 USB-mic 版本**。如果只需要基础 Codex 面板，请改用手动章节的
基础构建目标，不要混用两种固件的启动检查。连接 C152，切勿猜测串口，再粘贴给 Codex：

```text
请在我的 M5Stack StopWatch Dev Kit C152 上安装五屏 AgentBezel。
我选择独立 USB-mic 固件及匹配的 Companion，包含首页、Codex、DSH、SUPER、HERMES。
首页点按播放静音角色回应并轻震。

开始前完整阅读 AGENTS.md 和 README.zh-CN.md。请自主完成安装流程，但严格遵守：

1. 先做只读检查，确认 macOS、C152 硬件、现有构建工具，以及刚刚接入的准确串口。
2. 使用 `pio run -d usb-mic` 构建已选择的 USB-mic 版本，说明依赖下载与磁盘成本；
   不启用其他无关音频实验。
3. 安装任何缺失依赖之前先向我解释。不要向我索要 OpenAI API key、登录 cookie、
   access token 或其他凭据。
4. 先向我展示 M5Stack 官方恢复出厂固件链接，再完成固件编译。
5. 刷机前再次解析并报告准确的 /dev/cu.* 端口，只针对这一次设备写入征求确认。
6. 刷机并重启手表后，分别验证 Codex StopWatch Mic USB 输入及 BLE/HID。
   此版本没有普通串口 READY 控制台。
7. 帮我给 ChatGPT 开启输入监控，并配置 ChatGPT Desktop：左键 = Push to talk，
   Command Key 4 = Toggle voice chat，中间 = Send；上/下/右保留可配置，左方向留空供 watch 模式循环。
8. 从源码编译 Swift 额度 companion。先用 demo discovery 找出这台 Mac 看到的
   CoreBluetooth UUID，再把真实额度写入绑定到这一台设备。
9. 如果我同意开机自动运行，只在本机生成 app wrapper 和 LaunchAgent。路径、UUID、
   日志和生成的 app 都不能进入 Git。
10. 引导我完成 Companion 输入监控/辅助功能、SUPER 快捷键及可选的人工 Space 分配；
    不静默改权限或应用设置，保留原有 LaunchAgent 配置和私有设备绑定。
11. 验证五屏循环、角色选择、Hermes 中央启动及导航、SUPER 控制、Codex 原操作、
    输入隔离、熄屏/重连、额度及短时间本地麦克风录音；验收后删除录音。
12. 未提供有权使用的本地音频时保持公开构建静音，不上传私有语音。
    只把真机实际观察到的结果记为通过，替换前保留匹配的固件及 Companion 备份。
```

仓库中的 [AGENTS.md](AGENTS.md) 为安装和隐私提供持续生效的边界。Claude Code
和其他本地 coding agent 也可以遵循同一说明，但本项目文档默认使用 Codex。

## macOS 权限与应用配置

Codex 负责终端工作；用户仍需确认缺失工具和准确刷机操作，在 **系统设置 >
蓝牙** 中配对 **Codex Micro**，并在 **系统设置 > 隐私与安全性 > 输入监控** 中
允许 **ChatGPT**，随后退出并重新打开 ChatGPT。请在 **ChatGPT Desktop >
Settings > Codex Micro** 配置动作。基础安装需要为本地构建的 companion 授予蓝牙
访问；可选 SUPER/HERMES 阶段还需要为 `CodexWatchCompanion.app` 开启输入
监控和辅助功能。

从源码构建额度 companion，运行 demo discovery，并且只将真实写入绑定到该 Mac
打印的 CoreBluetooth UUID。除非安装了自动启动，否则应保持 `--watch` 进程运行。
经同意后，可由本机构建的 wrapper 和当前用户 LaunchAgent 实现自动启动；生成的
app、路径、UUID 和日志均保留在本地。LaunchAgent 模板标识为
`io.github.codex-micro-stopwatch.companion`，可执行文件保持为
`codex-watch-companion`。

更新镜像后分别检查 BLE 连接和 HID 枚举；蓝牙显示已连接不等于控制通道已就绪。
仅在排障确认旧配对有问题时重新配对这块 StopWatch，不要反复删除正常配对或重置系统权限。
保留真实 Codex Micro 的配对记录，但验证本移植时应断开或关闭它：一次仅支持一个 active Micro。

## 可选 USB 麦克风

默认 `m5stack-stopwatch` 镜像使用 Mac 麦克风。明确选择独立 `usb-mic` 构建的
用户可将 StopWatch 暴露为 **Codex StopWatch Mic**：48 kHz、16-bit、mono、
纯输入 USB Audio，不提供 USB speaker/output endpoint。BLE 控制和仪表盘仍然
保留；只有 Mac 未传输麦克风音频时才播放本地完成提示音。录音时保持 USB 连接，
在 **系统设置 > 声音 > 输入** 中选择 **Codex StopWatch Mic**；Push to talk 和
Voice Chat 动作继续走蓝牙，音频采样则通过 USB 传输。

使用 `pio run -d usb-mic` 构建此独立目标；开始前应解释其首次构建的工具链下载、
时间和磁盘成本。遵守同样的官方恢复和准确端口确认规则。完成后不应期待默认串口
READY 标记：验证已选择的 **Codex StopWatch Mic** 输入，另行验证 BLE/HID，并完成
简短的本地录音测试。不要提交录音、设备标识或本地路径。

## 隐私与架构

Swift `CodexWatchCompanion` 使用用户现有的本地登录上下文启动本地 Codex App
Server，并读取 `account/rateLimits/read`。它只通过项目自有额度 GATT 服务向
明确绑定的手表发送剩余百分比和 reset 倒计时；兼容 HID 接口不包含账户额度。

在真实 `--watch` 运行中，可选工作区集成还仅通过 vendor HID Report ID 6 发送
固定的 `home`、`codex`、`deepseek`、`super` 或 `hermes` 显示模式枚举及 Hermes 可选的
`idle`/`opening`/`error` 状态；中央点按仅发送固定 `open_hermes` 动作。
专属方向事件仅携带固定的桌面、方向、按下/释放枚举，不含项目或会话数据。
它不会发送 API key、token、账户标识、
提示词、任务文本、音频、项目/会话/窗口/Space 元数据或用户内容；不会抓取 UI、
使用云中继、检查键盘文本、调用 shell 或 AppleScript、使用私有 Space API，或
检查 super.engineering 或 Hermes 设置。
Hermes 中央启动有一项有限的辅助功能操作：仅在本机使用 focused/main 窗口句柄和焦点状态，
抬起并聚焦准确进程的窗口；三个快捷操作桌面只在本机有限检查 AX 窗口句柄和角色，
不读取窗口标题或内容，也不向手表发送窗口列表。

设备 MAC 地址、CoreBluetooth UUID、用户名、home-directory path 和日志均为
本地安装数据，绝不能提交。BLE 配对使用平台的无 passkey Just Works 流程：请在
可信环境中使用；Mac 或手表更换所有者时，移除旧配对。参见
[companion 文档](companion/README.md)和 [GATT 合约](docs/COMPANION_PROTOCOL.md)。

## 手动编译与刷机

推荐使用 Codex 辅助流程。维护者也可使用
[PlatformIO Core](https://docs.platformio.org/en/latest/core/index.html)：

```sh
pio run -e m5stack-stopwatch
pio device list
```

识别连接 C152 后新出现的准确串口。先完成构建、阅读 M5Stack
[官方 StopWatch 恢复出厂指南](https://docs.m5stack.com/en/guide/restore_factory/stopwatch)，
再在得到明确确认后刷入已解析的端口：

```sh
pio run -e m5stack-stopwatch --target upload --upload-port /dev/cu.YOUR_C152_PORT
```

绝不能照抄其他用户文档中的端口。默认镜像成功启动会打印
`CODEX_MICRO_STOPWATCH_READY`；必须在同一端口上验证：

```sh
python3 scripts/serial_probe.py /dev/cu.YOUR_C152_PORT --seconds 30 \
  --expect CODEX_MICRO_STOPWATCH_READY
```

可选 USB-mic 镜像同样必须遵守恢复和准确端口安全边界：

```sh
pio run -d usb-mic
pio run -d usb-mic -e m5stack-stopwatch-usb-mic --target upload \
  --upload-port /dev/cu.YOUR_C152_PORT
```

USB-mic 镜像以音频替代普通 USB 串口，因此不出现
`CODEX_MICRO_STOPWATCH_READY` 属于预期。以后的更新可以使用 companion 加密的
`--enter-bootloader` 命令，但仍必须重新发现并确认新出现的端口；M5Stack 手动
恢复手势始终是兜底。

手动运行额度 companion：

```sh
cd companion
swift build -c release

# 只写入演示数据，并打印这台 Mac 看到的 UUID。
.build/release/codex-watch-companion --demo --verbose

# 只在本机替换占位符，绝不能提交生成的 UUID。
.build/release/codex-watch-companion \
  --device-id YOUR_COREBLUETOOTH_UUID --watch --interval 60
```

## 常见问题

### 找不到 C152 串口

- 更换确认支持数据传输的 USB-C 线和接口。
- 断开其他开发板，重新列出端口，再只连接 C152。
- 如果现有固件无法启动，按照 M5Stack 官方 download-mode 和恢复出厂流程操作。

### 蓝牙设置中看不到 Codex Micro

- 重启手表后重新扫描。
- 确认旧配对有问题后才重新配对这块 StopWatch；不要跳过 BLE/HID 分层检查而反复重置配对。
- 默认镜像应在串口上确认 `CODEX_MICRO_STOPWATCH_READY`；USB-mic 应独立验证音频
  接口和 BLE/HID。

### ChatGPT 能看到 Micro，但控制没有作用

- 在输入监控中允许 ChatGPT，然后退出并重新打开。
- 断开其他正在工作的 Codex Micro。
- 暂时退出可能占用或拦截 HID 的键盘 remapper 或安全工具，再重新连接。

### 右键没有打开 Voice Chat

在 ChatGPT Desktop 中把 **Command Key 4** 设置为 **Toggle voice chat**。右键
发送 `ACT09`，不是 `ACT11`。

### 屏幕显示 `SYNCING MAC`，或者额度已经 stale

- 确认 companion 正在已经配对的 Mac 上运行。
- 重新运行 demo discovery，并绑定那台 Mac 当次打印的准确 UUID。
- 不要复制其他电脑上的 UUID；CoreBluetooth 标识属于本地主机。

### 可选工作区导航不可用

- 确认 SUPER 前台 bundle 是 `engineering.super.app` 或旧 `com.zarifpour.superconductor`，
  HERMES 是 `com.nousresearch.hermes`；对应快捷键能由物理键盘使用，
  且 `CodexWatchCompanion.app` 已开启辅助功能。
- 输入监控是接收径向手势所必需的。若缺少辅助功能，仅项目/标签导航会被禁用；
  左滑循环、额度和 USB 麦克风输入仍可用。
- Hermes 应先进入待启动页，点中央并等到操作页；下/下/上移动选择，右滑释放后打开。
  没有 Companion 本次持有的选择时，右滑无动作是预期行为。
- 如果物理键盘 Control-Tab 也要点击标题栏后才生效，应检查窗口焦点和已安装 Companion
  0.1.4 的身份、权限；不能把进程前台当作窗口已聚焦，也不要改成全局按键投递。

## 致谢、许可证与商标

本仓库属于一条持续演进的开源实现谱系：

1. [`imliubo/codex-micro-4-core2`](https://github.com/imliubo/codex-micro-4-core2)
   较早在 M5Stack Core2 上实现了 Codex Micro 兼容能力，也是部分 BLE vendor-HID
   兼容层的实现参考。
2. [`digitsisyph/codex-micro-stopwatch`](https://github.com/digitsisyph/codex-micro-stopwatch)
   将其中部分 BLE 兼容层改编到 M5Stack StopWatch C152，并进一步加入 StopWatch
   UI、电源逻辑、额度 Companion 和可选 USB 麦克风；本仓库直接建立在这套代码基础上。
3. **Stopwatch AgentBezel C152** 延续 StopWatch 代码线，增加 Codex Micro、
   super.engineering 与 Hermes Desktop 工作区、Companion 前台联动和独立方向屏幕，
   并增加机器人首页、本地语音支持及 USB 麦克风优先处理。

这里描述的是实现谱系，并不表示这些仓库是运行时包依赖，也不表示它们彼此存在官方
隶属关系。后续每一层实现都依赖、引用并扩展了前人的开源成果。再次分发时，请保留原始
声明，清楚说明自己的修改，明确引用所依赖的项目，并在合适时将通用修复回馈上游；
同时尊重每一位维护者和贡献者。健康的开源生态需要共同守护：大家一起维护兼容性，
也一起维护开放协作的公共成果。

改编代码与本项目变更依据 MIT License 分发，适用归属保留在 [LICENSE](LICENSE)
和 [NOTICE.md](NOTICE.md) 中。Space Mono 继续使用 `assets/fonts/OFL.txt` 中的 SIL
Open Font License 1.1。

OpenAI 关于原始设备的说明见
[Codex Micro](https://learn.chatgpt.com/docs/features/codex-micro)，companion 所用的
本地客户端接口见 [Codex App Server](https://learn.chatgpt.com/docs/app-server)。

所有名称和标识只用于说明兼容性。归属、协议、安全、免责声明和商标说明见
[NOTICE.md](NOTICE.md)。
