# EasyEDA SCH Agent Control

面向 Agent 的嘉立创 EDA 专业版原理图绘制与审核 Skill。通过 Run API Gateway 读取、创建、修改并验证原理图，重点保证电气连接、图页范围、紧凑排版、文字可读性以及保存后的实际渲染结果。

## 主要能力

- 新建、重绘和修改嘉立创 EDA 原理图功能块；
- 查询器件、属性、导线、电源符号和 GND 符号；
- 检查器件极性、引脚连接、网络隔离和 NC 状态；
- 按电源在上、GND 在下、功能分区清楚的原则整理布局；
- 控制普通导线的内部 `net`，避免出现多余蓝色网络文字；
- 保护元器件 Value、封装、制造商、供应商和数据手册等属性；
- 强制执行密集区与修改区的局部放大验收、稳定渲染检查和保存后复核；
- 处理 Gateway 启动缓慢、窗口 ID 变化和异步画面延迟等常见问题。

## 适用范围

适用于嘉立创 EDA 专业版原理图页的创建、修改、重绘和视觉审核。

不适用于：

- PCB 布局布线；
- 与嘉立创 EDA 无关的通用电路计算；
- 未经用户授权的其他图页复制或修改；
- 绕过本地权限、连接或工程范围限制的操作。

## 前置条件

- 已安装嘉立创 EDA 专业版；
- 已安装并启用 Run API Gateway 插件；
- 本地 EasyEDA Bridge 已启动，默认检测端口为 `49620`～`49629`；
- Agent 能够读取本 Skill，并获准操作目标工程和图页。

> Gateway 插件和 Bridge 不包含在本仓库中，需要单独安装和启动。

## 安装

将仓库克隆到 Agent Skills 目录：

```powershell
git clone git@github.com:Crabapple-Zhao/EasyEDA_SCH_Agent_Control.git "$env:USERPROFILE\.Agent\skills\easyeda-schematic"
```

如果目标目录已经存在，请先备份或选择其他目录，不要直接覆盖现有 Skill。

## 使用示例

在 Agent 中显式调用：

```text
$easyeda-schematic 在当前打开的工程中审核 P5 原理图，修复文字重叠并优化布局，保存前逐个放大检查所有修改区域。
```

也可以直接描述任务，Agent 在匹配到嘉立创 EDA 原理图操作时会自动加载该 Skill。

## 核心验收原则

1. 修改前确认项目、窗口、原理图和目标图页。
2. 参考页只用于密度、字体和布局原则，不复制图元、坐标或连接。
3. 普通局部导线从首次创建起保持 `net: ""`。
4. 元器件移动前深拷贝完整状态，移动后核对 Value、封装和供应链属性。
5. LED、二极管等极性器件必须按照实际引脚和电流方向验收。
6. 每个新建或移动的 GND 都要单独检查方向、导线端点和原生名称。
7. 每个密集区和修改区必须在最终修改后单独放大检查；整页缩略图不能替代局部验收。
8. 多对象或合并导线修改需要等待状态稳定，并确认连续两次查询或渲染一致。
9. 全部局部验收通过后才能检查整页、保存并报告完成。

## 目录结构

```text
easyeda-schematic/
├─ SKILL.md                         Skill 入口与强制工作流
├─ agents/openai.yaml              Agent 界面元数据
├─ references/
│  ├─ easyeda-gateway.md           Gateway API 与稳定操作规则
│  ├─ failure-patterns.md          已知失败模式和预防措施
│  └─ schematic-standard.md        通用原理图绘制规范
└─ scripts/
   └─ invoke-easyeda-gateway.ps1   Gateway 发现、检查与执行助手
```

## 版本

当前版本：`v1.0.0`。

后续版本应在 Git 提交标题中包含版本号，并在提交正文中说明主要更新内容。
