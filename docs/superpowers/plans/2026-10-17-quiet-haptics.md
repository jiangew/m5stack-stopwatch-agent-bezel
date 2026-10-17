# Quiet Haptics Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 制作更弱、更短且不被同步绘制拖长的全局震动候选。

**Architecture:** 沿用实际main的马达控制与主循环期限；仅调整常量，在长绘制前为仍活跃的短震让出循环，并显式缩短关机确认脉冲。无需新线程、定时器、RPC或依赖补丁。

**Tech Stack:** C++17、PlatformIO、Ruby实际主函数及原生M5GFX像素回归。

## Global Constraints

- 按键、触摸、滑动强度160；首页／普通触摸16ms、滑动／按键20ms、唤醒12ms、旅行关机24ms。保留触发条件和一次触发语义。
- 首页首个回应帧先绘制、后启动短震。后续绘制若短震活跃则保留重绘请求并返回，期限到后继续；不能忙等、阻塞输入或添加线程。
- 实施澄清：首页重叠点击先停旧脉冲，再画新回应首帧并启动一次新反馈。跨循环保留重绘请求，但Agent变化检测仍仅消费本次`latest.dirty`；默认与USB-mic都门控。普通触摸原55ms按键等待拆为16ms、停马达、39ms，按键语义及程序等待总长不变。
- 旅行关机先停旧脉冲，再画提示；新确认脉冲24ms后显式停止，原提示总等待550ms保持。
- PWM保持2000Hz；不改驱动、素材、动画、手势、IMU及250ms保护、USB音频、Companion、配对或默认IMU启用方式。
- 保留已验收`298f1c7b3ef4`镜像。160是未实测的候选起点；不把软件期限或原生模拟当作物理脉宽、可靠起转或最低噪声结果。
- 本轮只构建、复核和冻结，不烧录、合并或推送；真实端口和新镜像另确认。日志及临时文件只放ignored输出。

---

### Task 1: 全局轻短震与绘制期间停止保证

**Files:**
- Modify: `src/main.cpp`
- Create: `simulator/haptic_main_test.rb`（实际函数、实际常量；仅替换硬件时钟／马达边界）
- Modify: `simulator/codex_dashboard_draw_test.rb`（真实drawScreen门控与像素恢复）
- Modify if required: `simulator/robot_home_imu_swipe_test.rb`、`simulator/robot_speech_reaction_test.rb`（实际函数fixture常量接口同步）
- Modify: `README.md`、`README.zh-CN.md`（已部署基线与候选区别）

**Interfaces:**
- Consumes: 实际`startHaptic(uint8_t,uint32_t)`、`stopHaptic()`、`updateHaptic()`、`drawScreen()`及`enterTravelPowerOff()`。
- Produces: 现有常量更新；新增`kHomeTapHapticDurationMs=16`与`kPowerOffHapticDurationMs=24`取代两处字面值。保持函数签名。

- [ ] **Step 1: 写并运行行为RED。** 从当前main抽取真实常量和现有函数，运行马达边界记录，证明旧触摸请求176／32ms不符合强度<=160与短脉冲期限。不是只以新增符号编译失败证明RED。新增真实drawScreen集成场景：短震未过期时画面不变、请求仍待绘制；期限到后先停马达再提交65ms模拟耗时绘制，实际记录的开启窗口不会包含该绘制。保留首页首帧后启动、同一输入一次震动的回归。关机执行到硬件断电哨兵，断言确认脉冲24ms且提示等待总计550ms。

```cpp
startHaptic(kTouchHapticIntensity,kTouchHapticDurationMs);
assert(recordedLevel<=160);
// Advance fake clock before and at deadline; execute actual drawScreen.
// No new frame before deadline, pending redraw survives; stop precedes transfer.
```

- [ ] **Step 2: 最小实现。** 更新强度与脉宽常量；首页25ms字面值改用`kHomeTapHapticDurationMs`。在drawScreen中保留原deskSleeping检查，先updateHaptic，再对活跃短震设置shouldRedraw并return。

`shouldRedraw`改为跨循环状态，poll时与`latest.dirty`合并，实际绘制才清除；状态变化检测仍使用`latest.dirty`。普通触摸键在现有55ms等待中先等16ms停马达，再等39ms释放按键。重叠首页点击在首帧之前显式结束旧脉冲。

```cpp
updateHaptic();
if(hapticActive){shouldRedraw=true;return;}
```

关机路径先stopHaptic，再显示已有提示；启动24ms脉冲、delay相同24ms、stopHaptic，剩余等待为550-24ms。不要改变关机判断或释放顺序。

- [ ] **Step 3: GREEN与自审。** 跑新haptic_main和实际drawScreen回归，再跑Home手势／实际IMU主循环／触摸IMU接续／音频和回应请求相关Ruby回归。新fixture引用真实常量；现有使用边界假常量的fixture可补充新增名称，不能用新硬编码期望掩盖生产行为。检查重绘请求不丢、过期及时停止、重复触发重设期限、wraparound，以及前台和电源状态未变。

```sh
ruby simulator/haptic_main_test.rb
ruby simulator/codex_dashboard_draw_test.rb
ruby simulator/robot_home_swipe_test.rb
ruby simulator/robot_home_imu_main_test.rb
ruby simulator/robot_home_imu_swipe_test.rb
ruby simulator/robot_speech_audio_test.rb
ruby simulator/robot_speech_reaction_test.rb
ruby simulator/robot_speech_request_test.rb
```

- [ ] **Step 4: 文档、提交与报告。** README明确全局轻短震为未烧录候选，旧物理反馈仍属于`298f1c7b3ef4`。只提交明确文件。报告RED/GREEN命令与输出、实际边界时序、重绘恢复和未实测项。

- [ ] **Step 5: 控制器构建、冻结及复核。** 独立任务复核后，顺序构建默认、Home IMU和原生预览，补齐相关原生／实际函数回归；核对app小于0x640000，冻结源码提交及SHA-256。全分支复核后保留候选分支，准确端口及新镜像确认后才另行烧录。

## 首版交付后的参数调校

上文实现计划已完成；160档首版已烧录，用户实测反馈触感太弱、偶尔感觉不到。后续仅调整档位为统一176，触摸／首页／滑动／按键24ms，唤醒20ms，关机24ms，替代上文首版参数；停止与绘制逻辑、按键总等待和关机等待保持。实际函数测试先验证旧档位不符合新请求，再验证新档位及既有交互回归。新镜像构建、复核后仍须重新核对端口并确认烧录，不能以软件检查宣称已达到可靠触感或低噪声。

## 用户指定的76档试验

用户在176/255、24ms版实测后认可触感与声音，但报告IMU动作消失；桌面静止诊断为校准中，陀螺仪约6.5度／秒超过4度／秒门限，启动校零原因仍待静止重启验证。用户随后明确指定点击／滑动改为76/255、30ms。本轮只修改首页／普通触摸及滑动参数，实体按键保持176/255、24ms，唤醒20ms、关机24ms；不改IMU算法。76低于此前偶尔不可感知的160档，软件请求不证明马达起转、触感或声音，必须实机验证。新参数取代此前触摸／滑动候选值，其他既有停止／绘制顺序及等待不变。
