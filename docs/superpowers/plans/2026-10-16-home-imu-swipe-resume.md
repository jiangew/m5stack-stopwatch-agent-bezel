# Home 角色滑动后姿态恢复 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 修复 Home 上／下／右滑切换角色后必须重新静止校准才能跟随的问题，构建并冻结待烧录候选。

**Architecture:** 在实际触摸开始时记录已校准检测状态，仅在成功的本地角色滑动后授权恢复。恢复保留中性方向与阶段，丢弃历史采样、滤波时间、动作候选计时；使用新鲜样本接续。外部输入保护和硬失效边界继续生效。

**Tech Stack:** ESP32-S3 C++、PlatformIO、Ruby 驱动的实际 main.cpp 函数集成测试、Clang ASan/UBSan。

## Global Constraints

- 仅针对 C152、显式选用的 `m5stack-stopwatch-home-imu`；默认环境和 USB 音频行为保持原样。
- 仅 Home 上／下／右滑成功选择本地角色后允许快速恢复；普通点击、未识别滑动、左滑不启用。
- 触摸／振动期间停采样，松手及振动结束后保留 250ms 静默。
- 保留已校准中性方向与 Held/Resting 阶段；丢弃历史样本、滤波时间及未完成的拿起／放稳计时。
- 已持握恢复时不重复发出 Pickup；Resting 的新运动仍需 60ms；暂停不能计入 600ms 放稳。
- 首次校准仍需静止 1500ms，非授权采样间隙大于 120ms 和坏样本仍重新校准。
- 工作区变化、按键／电源操作、叠层、IMU 禁用、传感器不可用使暂存失效；之后不能复活旧状态。
- 不修改倾斜方向、幅度、60ms 滤波时间常数、600ms 放稳门限、绘制节奏或 USB 音频行为。
- 仅构建候选，不烧录、不推送、不合并；保留已部署 `43d8e91` / `6cc50998db76` 镜像作为回滚。
- 运行日志、固件镜像及设备标识仅保存在 ignored artifacts；不得提交音频、账号、设备标识或个人绝对路径。

---

### Task 1: 实现、回归并构建本地角色滑动恢复

**Files:**
- Modify: `include/RobotHomeImu.h`：检测器接续新样本的生产接口。
- Modify: `src/main.cpp`：触摸起点暂存、成功角色滑动授权、静默后恢复、硬失效撤销。
- Create: `simulator/robot_home_imu_swipe_test.rb`：真实触摸及 IMU 函数组合回归。
- Modify as necessary: `simulator/robot_home_imu_main_test.rb`：新增生产接口依赖；保留原物理输入保护断言。
- Modify: `docs/HOME_IMU_PILOT.md`：新场景、验证边界及未烧录状态。
- Modify: `docs/superpowers/specs/2026-10-16-home-imu-swipe-resume-design.md`：记录回归结果，明确实机未验收。

**Interfaces:**
- Consumes: `Detector::update(const Sample&, uint32_t) -> Result`, `Detector::reset()`, `Detector::result() const -> const Result&`；实际 `beginTouchGesture(int,int)`, `updateTouchGesture(int,int)`, `updateRobotImu()`。
- Produces: 一个由生产恢复路径调用的 Detector 接续接口，保留已校准阶段及中性方向、清除瞬态并重新播种样本；主循环内部拥有范围受限的暂存／授权状态，不向设备协议增加控制入口。

- [x] **Step 1: 写失败回归并确认失败原因。** 新 Ruby fixture 按现有测试方式抽取真实函数，使用真实 CharacterSelector、Detector、Tap 和 Animation，仅替换硬件与昂贵绘制边界。主要断言：

```cpp
// Calibrate flat, qualify pickup; begin actual touch, feed while pressed;
// actual U/D/R selection starts haptic, keep finger down, release, quiet 250ms.
assert(samplesDuringTouch == samplesBeforeTouch);
assert(pickupsAfterResume == pickupsBeforeTouch);
assert(phaseAfterResume == robot_home::imu::Phase::Held);
assert(positiveTilt.angle > 0 && positiveTilt.x > 0);
// Do not feed an extra 1500ms stationary interval before this assertion.
```

Run: `ruby simulator/robot_home_imu_swipe_test.rb`。预期先在恢复后 Held／非零姿态断言失败，而非编译错误。记录完整 red 命令与失败原因到任务报告。

- [x] **Step 2: 实现最小状态恢复。** 在触摸开始早于绘制和输入 reset 时捕获有效已校准状态。仅成功的 Home U/D/R 设置恢复授权；静默后恢复一次并清除暂存。Detector 的生产接续接口语义为：

```cpp
// Preserve result_.phase and neutralRoll_/neutralPitch_.
// Clear result_.event/result_.since, valid_, motionPending_, stillPending_.
// The next update() seeds previous_/filter/last_ from a validated fresh sample.
```

在实际硬失效边界清除暂存与授权；不要通过放宽 kMaxGapMs 处理暂停，不要跳过恢复样本合法性检查。

- [x] **Step 3: 补齐行为回归并运行。** 覆盖三个方向、头像及八个全身角色、连续切换、延迟释放、振动延长、Held 正反向倾斜、Resting 静置无假 Pickup、Resting 恢复后仍需 60ms 运动、旧放稳计时不被继承、未校准滑动、普通点击／左滑、工作区离开返回、按键、电源 pending、叠层、禁用、不可用、坏样本及未授权长间隙。测试直接断言 phase/pose/event/counters，而非代码文本。模拟当前 65ms 提交成本，确认实际路径不会因新恢复逻辑制造重复绘制与超时。Run:

```sh
ruby simulator/robot_home_imu_swipe_test.rb
ruby simulator/robot_home_imu_main_test.rb
ruby simulator/robot_home_swipe_test.rb
clang++ -std=c++17 -fsanitize=address,undefined -Iinclude simulator/robot_home_imu_test.cpp -o /private/tmp/home-imu-unit-swipe
/private/tmp/home-imu-unit-swipe
clang++ -std=c++17 -fsanitize=address,undefined -Iinclude simulator/robot_home_imu_continuity_test.cpp -o /private/tmp/home-imu-continuity-swipe
/private/tmp/home-imu-continuity-swipe
```

- [x] **Step 4: 更新文档并提交。** 文档区分“已部署连续动作版”和“滑动恢复候选”，列明 red/green 证据与实机待验证。`git diff --check` 后，仅 stage 本任务明确文件并提交。报告写入指定 ignored 报告路径，包括提交、命令、失败及成功输出、未验证事项和自审结论。

- [x] **Step 5: 控制器完成构建及冻结。** 通过任务复核后，顺序构建默认环境、显式 IMU 环境与 native-preview；使用已有缓存，必要时窄范围沙箱升级，不安装新依赖。控制器计算 app SHA-256／大小，复制到新的 ignored artifacts 子目录并生成含源码提交、构建环境、未烧录标志和回滚摘要的 manifest。

```sh
/opt/homebrew/bin/pio run -e m5stack-stopwatch
/opt/homebrew/bin/pio run -d usb-mic -e m5stack-stopwatch-home-imu
HOMEBREW_PREFIX=/opt/homebrew /opt/homebrew/bin/pio run -e native-preview
```

- [x] **Step 6: 最终复核与交付。** 任务范围复核与完整分支复核均记录到本计划 ledger；修复有证据的阻塞发现后，检查候选 SHA 与当前生产源码一致、回滚镜像仍存在且摘要一致。仅交付候选与进入下载模式的实机准备请求；随后另行核对实际端口和该候选烧录授权。
