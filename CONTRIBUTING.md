# 贡献指南

感谢您对沐澜水文项目的关注！欢迎提交 Issue、Pull Request 或参与讨论。

## 开发环境

### 前置要求

- [MoonBit](https://moonbitlang.com) 工具链 >= 0.1.20260713
- [Git](https://git-scm.com/)

### 本地开发

```bash
# 克隆仓库
git clone https://github.com/toadium/moon_hydro.git
cd moon_hydro

# 编译检查
moon check

# 运行测试（四后端）
moon test --target wasm-gc
moon test --target wasm
moon test --target js
moon test --target native

# 格式化
moon fmt

# 运行后端 CLI
moon run --target native backend
```

## 项目结构

```
shared/     共享层：数据模型 + 算法内核（四后端复用）
backend/    后端：CLI 子命令
frontend/   前端：TEA 架构 + 浏览器内试算
docs/       项目文档
```

## 开发规范

### 代码风格

- 提交前必须运行 `moon fmt` 格式化
- 遵循 MoonBit 命名约定：`snake_case` 函数/变量，`PascalCase` 类型
- 公开 API 必须添加 `///|` 文档注释
- 新增结构体派生 `Debug, ToJson, FromJson`（如需序列化）

### 测试要求

- 新功能必须附带测试（`*_test.mbt`）
- 测试需在四后端（wasm/wasm-gc/js/native）全部通过
- 边界用例：空输入、单元素、极端值必须覆盖

### MoonBit 注意事项

- 不支持科学计数法字面量（`1e10` → `10000000000.0`）
- `Ref::new` 已废弃，使用 `Ref(value)`
- `derive(Show)` 已废弃，手动实现 `Show` trait
- 结构体字段默认 immutable，用 `{ ..base, field: value }` 更新
- `fn main` 中调用 raise 函数需用 `fn main raise`

### 提交规范

使用 [Conventional Commits](https://www.conventionalcommits.org/) 格式：

```
<type>: <description>

type 可选值:
  feat     新功能
  fix      修复
  docs     文档
  refactor 重构
  test     测试
  ci       CI/CD
```

示例：
- `feat: 添加SCE-UA全局优化率定算法`
- `fix: 修复DDS率定空参数除零崩溃`
- `docs: 更新技术文档反映V0.4进展`

## Pull Request 流程

1. Fork 仓库并创建特性分支（`git checkout -b feat/your-feature`）
2. 编写代码 + 测试，确保 `moon check` 和 `moon test` 通过
3. 运行 `moon fmt` 格式化
4. 提交 PR，描述变更内容和动机
5. 等待 CI 检查通过 + Code Review

## Issue 指南

- Bug 报告：描述复现步骤、预期行为、实际行为
- 功能请求：描述使用场景和期望接口
- 算法讨论：附参考文献或基准实现

## 许可证

贡献的代码将在 [MIT License](LICENSE) 下发布。