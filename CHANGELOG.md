# Changelog

## v1.0.1 (2026-09-03)

### 绘图规则

- 将绘图规则统一维护在 SKILL.md 中，移除重复规范文件及外部本地文档依赖。
- 明确"电源在上、接地在下"是局部供电层次原则，不强制标识朝向。
- 完善局部公共供电线、同网引脚就近汇接及支撑元件靠近相关引脚的布局方法。
- 根据符号、位号、参数和附属图形的完整边界安排间距，减少文字拥挤与多余留白。
- 同时检查功能组的宽度、高度和连接清晰度，避免孤立地追求单根导线最短。

### 检查与操作

- 按图页和图元归属处理 DRC，优先检查当前页错误及新增问题。
- 补充合并导线按独立有限线段重建的操作说明。
- 保留元件信息保护、局部放大检查、稳定渲染及保存后复核要求。
- 改为查找实际配置的 Bridge 启动位置，避免依赖固定的个人目录。

### 文档

- 同步使用说明、故障排查参考及版本元数据。

## v1.0.0 (2026-09-02)

### 新增

- **SKILL.md**：Skill 入口与强制工作流,包含 Preflight、Plan Around Pins、增量绘制、Flag 与文字放置、紧凑性检查、Verify and Save 六步流程
- **agents/openai.yaml**：Agent 界面元数据,支持隐式调用
- **references/schematic-standard.md**：通用原理图绘制规范(13 章),涵盖布局、导线、电源/GND、文字、验收清单、禁止事项
- **references/easyeda-gateway.md**：Run API Gateway 连接与操作参考,包含端口发现、慢连接恢复、Component Modify 元数据保护、稳定渲染门控、Wire/NetFlag/GND 处理规则
- **references/failure-patterns.md**：16 条已知失败模式速查表,按症状归因与预防措施
- **scripts/invoke-easyeda-gateway.ps1**：Gateway 端口发现、健康检查、窗口查询与 JavaScript 执行封装
- **README.md**：中文说明文档,包含安装方式、使用示例与核心验收原则