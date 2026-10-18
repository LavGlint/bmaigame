# bmaigame · 项目导航

当前正式版：v1.0.0。三张固定地图、六角色远程攻击、完整人物动画、P1 至 P4 顺序选人、低饱和菜单插画与完整地图等比显示已接入。Windows 正式包仅包含运行文件、操作说明及许可证；测试源码移至 automation/regression，历史产物可恢复归档在 archive/release-v1.0.0。日常只需打开下列入口：

- [试玩新版 Demo](godot-demo/启动Godot试玩.cmd)：运行已导出的 Windows 游戏。。
- [查看 UI 组件库](查看UI组件库.cmd)：预览游戏内交互组件。

游戏运行素材放在 `godot-demo/assets/`，原始设计素材放在 `design/`。修改玩法去 `godot-demo/scripts/`，修改页面布局去 `scripts/screens.gd`，修改设置交互去 `scripts/main.gd`。

## 开发命令

在项目根目录运行：

```powershell
.\godot.cmd --editor --path godot-demo
.\automation\regression\godot\run_tests.ps1
.\godot.cmd --path godot-demo --script .\automation\regression\godot\ranged_render_test.gd
.\automation\build-release.ps1
python .\automation\package-godot.py
```

测试、截图及构建临时文件只写入 `work/` 和 `godot-demo/outputs/qa/`，两者按需自动创建并从 Git 忽略。Godot 的 `.godot/` 是自动生成缓存。源素材、`.gd.uid`、`.import`、字体许可及引擎配置应保留。

本轮 16 套回归 / 1348 项有效检查及五场正式时长对局通过，合计 28 分钟虚拟对局时间。实际 GPU 验证 58 次建筑遮挡、120 个攻击帧与 384 个弹体方向帧；29 张实际导出游戏截图。69 张战斗 PNG、三张地图及三张菜单插画与原件 SHA256 相同。实物四手柄联调尚未执行。[菜单插画接入](docs/菜单插画接入说明.md) · [三张地图接入](docs/三张地图接入说明.md) · [六武器与默认参数](docs/六角色远程攻击接入.md)。
