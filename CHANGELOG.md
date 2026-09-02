# Changelog

## v1.0.0 (2026-09-02)

### 新增

- **SKILL.md**：Skill 入口与强制工作流,包含 Preflight、Plan Around Pins、增量绘制、Flag 与文字放置、紧凑性检查、Verify and Save 六步流程
- **agents/openai.yaml**：Agent 界面元数据,支持隐式调用
- **references/schematic-standard.md**：通用原理图绘制规范(13 章),涵盖布局、导线、电源/GND、文字、验收清单、禁止事项
- **references/easyeda-gateway.md**：Run API Gateway 连接与操作参考,包含端口发现、慢连接恢复、Component Modify 元数据保护、稳定渲染门控、Wire/NetFlag/GND 处理规则
- **references/failure-patterns.md**：16 条已知失败模式速查表,按症状归因与预防措施
- **scripts/invoke-easyeda-gateway.ps1**：Gateway 端口发现、健康检查、窗口查询与 JavaScript 执行封装
- **README.md**：中文说明文档,包含安装方式、使用示例与核心验收原则
