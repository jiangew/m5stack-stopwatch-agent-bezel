# Home 双阵营交互 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 实现上滑汽车人、下滑霸天虎、右滑固定大黄蜂头像，新增同风格全身与回应素材并保留已验收交互。

**Architecture:** CharacterSelector只决定角色；素材映射和Motion描述回应；PortraitCanvas缓存全部待机图及当前角色最多两张动作图。主循环复用当前手势及IMU接续，不增加协议或语音入口。

**Tech Stack:** C++17、ESP32-S3／PlatformIO、Ruby实际函数回归、Python/Pillow/numpy既有素材准备与校验管线、内置imagegen、原生M5GFX／SDL预览。

## Global Constraints

- 只升级Home；左滑、点击生命周期、600ms回应、按下3%压缩、25ms点击轻震、既有滑动轻震及320ms切换过渡保留。
- 上滑从八汽车人中等概率随机；下滑从八霸天虎中等概率随机；同阵营排除当前角色，跨阵营八人均可选；右滑固定Bumblebee头像且零随机调用。
- 原有Character枚举0..8身份保持；新增Megatron、Starscream、Soundwave、Shockwave、Thundercracker、Skywarp、Blitzwing、Astrotrain；共17个页面。
- 现有头像、汽车人待机及回应素材字节保持；新增八张待机及各至少一张实质不同的回应姿态，不用待机重编码冒充动作。
- 300×300 baseline RGB JPEG、小于50KiB；待机18px边缘JPEG容差12／255，动作沿用8px边缘容差16／255；动作使用对应待机的固定几何变换配准。
- 内置imagegen生成／编辑全部新角色图；沿用三头身、描边、赛璐璐、纯黑背景。Python仅按现有管线做几何适配／格式序列化及分析，不绘制或伪造角色／动作。
- 待机缓存17张，动作缓存当前角色最多两张；像素槽位上限19，不能全部动作常驻，也不能每个动画帧解码。
- 动作缓存不足保留正确待机和该角色原生变换；当前角色重复点击不解码；切换／清理撤销旧动作。
- IMU检测器、映射、门限、滤波、静默和滑动恢复语义保持；不改变默认发布环境启用方式、USB音频、Companion或配对。
- 本轮不接入语音助手、不烧录、不推送、不合并；保留当前c83363fcc22e固件及回滚。端口／新镜像授权另行取得。
- 正式素材／生成头文件／来源文档可提交；原始大图、废弃变体、报告、候选二进制和个人路径／设备身份只放ignored输出。

---

### Task 1: 双阵营选择与真实手势／IMU回归

**Files:**
- Modify: `include/RobotHomeCharacter.h`
- Modify: `simulator/robot_home_character_test.cpp`
- Modify: `simulator/robot_home_swipe_test.rb`
- Modify: `simulator/robot_home_imu_swipe_test.rb`
- Modify: `simulator/robot_home_ui_test.cpp`（总数与阵营行为断言；新图像映射的检查留Task2／3）

**Interfaces:**
- Consumes: `CharacterSelector::select(Direction,uint32_t,RandomFn) -> Character`, `character()`, `reset()`, `transitionProgress()`。
- Produces: Character旧0..8加新9..16；`kCharacterCount=17`、`kAutobotCount=8`、`kDecepticonCount=8`、`kFullbodyCount=16`；两个显式`std::array<Character,8>`池命名`kAutobots`、`kDecepticons`。后续素材和预览遍历使用这些身份。

- [ ] **Step 1: 先写失败选择器回归。** 使用当前已存在的方向和Bumblebee身份先证明右滑不应调用随机函数、下滑不应落在汽车人。运行实际C++测试并记录行为断言失败，不以新增符号编译错误作为唯一RED。

```cpp
CharacterSelector selector; unsigned calls=0;
selector.select(Direction::Right,100,[&]{++calls;return 0u;});
assert(selector.character()==Character::Bumblebee && calls==0);
```

- [ ] **Step 2: 最小实现。** 增加枚举和显式池；选择目标池，池内排除当前角色时range=7，否则range=8。保留现有拒绝采样算法；右滑返回头像、重启既有320ms过渡且不取随机数，左／None仍保持角色。

```cpp
// Target pool: Up -> kAutobots; Down -> kDecepticons.
// Find current index in target pool, skip only that index when present.
// Right assigns Bumblebee and transitionSince_=nowMs without randomFn().
```

- [ ] **Step 3: 扩展真实函数组合回归。** 覆盖两个池所有成员、同阵营不重复、跨阵营八人完整覆盖、拒绝采样边界、右滑从任意角色回头像以及已有头像右滑。实际updateTouchGesture验证一次轻震／零主机动作／黑屏唤醒消费／离线；实际begin/update/finish touch和IMU组合覆盖新角色及头像返回、快速连续、已持握接续和撤销边界。不要改IMU生产代码来适配角色。

Run:
```sh
clang++ -std=c++17 -fsanitize=address,undefined -Iinclude simulator/robot_home_character_test.cpp -o /private/tmp/home-factions-character
/private/tmp/home-factions-character
ruby simulator/robot_home_swipe_test.rb
ruby simulator/robot_home_imu_swipe_test.rb
ruby simulator/robot_home_imu_main_test.rb
```

- [ ] **Step 4: 自审并提交明确文件。** 报告RED/GREEN命令、完整结果、身份接口、剩余素材／缓存依赖。此阶段还未接入霸天虎图片，不宣称完整产品可交付。

### Task 2: 新素材准备、嵌入及来源／图像校验

**Files:**
- Create: `assets/robot-home/{megatron,starscream,soundwave,shockwave,thundercracker,skywarp,blitzwing,astrotrain}.png`
- Create: `assets/robot-home/generated/{name}-idle.jpg`、`assets/robot-home/actions/{name}-1.jpg`（上述八名）
- Modify: `scripts/prepare_robot_home_art.py`、`scripts/embed_robot_home_art.rb`、`scripts/embed_robot_home_action_art.rb`
- Modify: `include/RobotHomeArtData.h`、`include/RobotHomeActionArtData.h`、`include/RobotHomeCharacters.h`
- Modify: `simulator/robot_home_art_test.py`、`simulator/robot_home_art_test.swift`、`simulator/robot_home_action_art_test.py`
- Modify: `assets/robot-home/GENERATION.md`、`assets/robot-home/actions/{README.md,PROMPTS.md,manifest.json}`

**Interfaces:**
- Consumes: Task1的17个Character；控制器提供的ignored `artifacts/home-factions/imagegen/inputs.json`，含八对内置imagegen原图、对应待机参考与生成prompt。只在文件已齐且视觉检查后开始。
- Produces: `assetFor(Character)`映射17张待机；`kActions`加入八位`pose=1`，每个映射字节正确；所有旧图片及旧header内对应payload保持。注册到当前脚本可重复生成的基线JPEG。

- [ ] **Step 1: 先扩展真实字节图像测试，记录缺失素材RED。** 17张待机、18张回应的文件和header字节必须一致，旧素材摘要保留，新身份与现有图片不同。新增八张回应必须与各自待机显著不同；验证固定配准及实际解码／安全边缘。用已存在校验器证明缺少新文件失败，不伪造JPEG占位通过。

- [ ] **Step 2: 按现有几何／JPEG管线制作正式素材。** 仅对生成原图做固定比例适配、纯黑安全画布和序列化；回应必须使用待机的同一变换，不独立重心调整。记录源摘要、正式JPEG摘要和变换元数据；个人绝对路径不进入tracked manifest。

- [ ] **Step 3: 扩展脚本、映射与生成头文件。** 旧Bumblebee裁剪保持原算法及摘要；新增八名进入HEROES和两个embed列表。扩展Swift ImageIO解码检查17身份。运行实际生成，校验嵌入字节与重生成一致。

Run:
```sh
python3 scripts/prepare_robot_home_art.py
ruby scripts/embed_robot_home_art.rb assets/robot-home/generated include/RobotHomeArtData.h
ruby scripts/embed_robot_home_action_art.rb assets/robot-home/actions include/RobotHomeActionArtData.h
python3 simulator/robot_home_art_test.py
python3 simulator/robot_home_action_art_test.py
swift -module-cache-path /private/tmp/home-factions-art-swift simulator/robot_home_art_test.swift
```

- [ ] **Step 4: 来源文档、视觉检查、自审及提交。** 来源说明内置imagegen、prompt、非官方同人属性和仅本地嵌入，保留旧素材来源。生成ignored对照预览；检查完整头脚、风格、角色辨识、idle与动作尺度／脚底位置、黑边和无环形头像替代。报告源和正式图清单／测试证据，不宣称硬件效果。

### Task 3: 有界动作缓存、回应映射及端到端预览

**Files:**
- Modify: `include/RobotHomePortraitCanvas.h`、`include/RobotHomeMotion.h`、必要时`include/RobotHomePortraitCache.h`
- Modify: `src/main.cpp`（准备当前角色动作的调用点，不改变手势／IMU／音频语义）
- Modify: `simulator/preview_main.cpp`、`simulator/robot_home_cache_test.cpp`、`simulator/robot_home_motion_test.cpp`、`simulator/robot_home_ui_test.cpp`、`simulator/robot_home_spacing_test.rb`
- Create if needed: `simulator/robot_home_portrait_canvas_test.cpp`（真实PortraitCanvas的缓存生命周期，硬件边界可替换）
- Modify: `README.md`、`README.zh-CN.md`、`docs/HOME_IMU_PILOT.md`、本设计状态文档

**Interfaces:**
- Consumes: Task1池／身份、Task2待机／回应映射。
- Produces: `PortraitCanvas::preparePortraits(Character current = Character::Bumblebee)` 准备所有待机且只准备当前角色回应；重复相同角色不解码。Idle cache显式容量`kCharacterCount`，action cache容量2。`clearPortraits()`清空角色和两类缓存状态。

- [ ] **Step 1: 先写行为RED。** 证明切换新角色后回应正确、当前角色无重复解码、分配槽位<=19、分配失败与clear后重新准备正确；不是仅assert常量。新角色Skill中应选pose1且有可见原生变换，expiry回待机；旧Motion精确行为保留。

```cpp
// Instrument only Sprite allocation/decode boundary; run actual Canvas/cache.
// Prepare role A, prepare A again: decode count unchanged.
// Prepare B: at most two current-role action sprites; old A action not reused.
// Fail action allocation: correct B idle + native transform, no per-frame decode.
```

- [ ] **Step 2: 实现缓存与回应。** 对当前角色筛选最多两张ActionAsset；切换时clear并预备其动作，在角色呈现前完成。避免循环分配／JPEG解码；分配失败不影响idle。霸天虎按约600ms单姿态加小幅挥手／握拳／致意native变换回应，不修改旧角色动作。更新main和所有真实预览循环传入当前角色。

- [ ] **Step 3: 扩展17角色像素／边界及真实主循环回归。** 所有新旧角色点击压缩／回应／最终回到精确idle、状态电量不变、安全留白、方向手势、IMU连续恢复、睡眠和缓存重新准备。运行受影响C++ sanitizer及Ruby实际代码回归；无源文件字面断言替代真实行为。

- [ ] **Step 4: 文档及提交。** 新当前规则和候选状态进入双语README；旧IMU物理验收明确属于c833版本。声明新17角色没有烧录／实机验收，图片／缓存大小不是实测延迟或功耗。报告测试、接口、缓存槽位和已知限制。

- [ ] **Step 5: 控制器验证构建和冻结。** 任务复核后顺序构建默认环境、Home IMU环境、native-preview；运行完整原生／素材回归及17角色像素检查。保存三个构建日志，核对应用镜像小于app0的0x640000字节；计算摘要、源码提交及回滚摘要，冻结到ignored `artifacts/home-factions/`。不烧录。

```sh
/opt/homebrew/bin/pio run -e m5stack-stopwatch
/opt/homebrew/bin/pio run -d usb-mic -e m5stack-stopwatch-home-imu
HOMEBREW_PREFIX=/opt/homebrew /opt/homebrew/bin/pio run -e native-preview
ruby simulator/robot_home_spacing_test.rb .pio/build/native-preview/program
```

- [ ] **Step 6: 最终复核及交付。** 全分支独立复核通过后展示17角色和8对霸天虎回应预览，交付候选和实际未验收项。保留分支及当前设备固件；确认新镜像与准确端口后才能进入另一次烧录流程。
