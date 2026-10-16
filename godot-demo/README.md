# BOOMERANG BRAWL · Godot v1.0.0

工作区双击根目录“试玩新版Demo.cmd”或 outputs/windows/HanabiArena.exe。Windows 正式包解压后双击“启动游戏.cmd”，exe 与 pck 放在一起，无需另装引擎。Godot 工程包用 Godot 4.7.2 导入 project.godot 运行。

六角色真实远程攻击已接入：GPT 按住喷火，接触按间隔扣血；Claude 单弹三次弹射；DeepSeek 飞餐刀往返；Eve 穿墙狙击；GLM 碰墙固定毒泽；酒狐单弹碰墙分三颗子弹。Eve 为主游戏 ID 3，GLM 为 4。

手柄 A / 空格 / 左键 / Enter 的原输入映射保留，GPT 使用按住状态。攻击第 3 帧出手，受击、冲刺与倒地打断；暂停冻结动画、轨迹和伤害计时。P1→P4 顺序选人、头像修复、透明 HUD、亚克力设置 / 暂停与常规结算保留。

操作与版本说明随 Windows 包附带。工程包 docs/ 附带菜单插画、三地图和六武器接入说明。完整测试源码与证据保留在开发工作区 automation/regression 和 reports，均不进入正式包。

1348 项有效回归 / 16 套通过，包含五场跨三地图的正式时长虚拟对局（28 分钟）。地图真实碰撞、出生 / 重生、AI 绕行与 58 次建筑遮挡验证通过；大厅三张黑胶低饱和插画按 v3 manifest 裁切。三种窗口尺寸、四入口及悬停 / 焦点导航通过，16:10 上下留边。实际 GPU 验证 120 个攻击帧、384 个弹体方向帧，以及多角色独立材质。实物四手柄联调和真人平衡尚未执行。

63 张人物 PNG、6 张弹体 PNG 与最新 design/role 原图 SHA256 相同。144 段人物动画、1488 帧与 119 个 ownership 裁剪保持原像素、比例和偏移；24 段弹体效果、96 帧使用真实 manifest 切片。运行资源完全在 assets/。

数值在 assets/config/ranged_defaults.json，是未确认的默认假设。工作区同步与审计工具在 automation；回归入口 automation/regression/godot/run_tests.ps1；构建 automation/build-release.ps1；正式打包 automation/package-release.py。测试脚本不在主工程中。

测试写入独立 QA 数据，不覆盖玩家设置和正式比赛记录。字体许可保留在 assets/fonts/LICENSE.txt，游戏没有新增字体来源文案。
