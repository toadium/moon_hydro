# 沐澜水文 (hydro)

> 基于MoonBit的分布式新安江模型+浅水方程水动力耦合流域洪水智能预报系统

[![CI](https://github.com/toadium/hydro/actions/workflows/ci.yml/badge.svg)](https://github.com/toadium/hydro/actions/workflows/ci.yml)
[![PR Check](https://github.com/toadium/hydro/actions/workflows/pr-check.yml/badge.svg)](https://github.com/toadium/hydro/actions/workflows/pr-check.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

## 快速开始

```bash
# 安装 MoonBit 工具链 (https://moonbitlang.com)
curl -fsSL https://cli.moonbitlang.com/install.sh | bash

# 克隆并编译
git clone https://github.com/toadium/hydro.git
cd hydro
moon check

# 运行测试 (四后端)
moon test --target wasm-gc
moon test --target native

# 运行后端 CLI
moon run --target native backend
```

## 项目结构

| 目录 | 说明 |
|------|------|
| `shared/` | 共享层：新安江模型、SWE求解器、率定算法、评价指标、批量仿真 |
| `backend/` | 后端：CLI子命令（sim/calibrate/validate/batch/...） |
| `frontend/` | 前端：TEA架构（Model/Msg/Update/View）+ 浏览器内试算 |

## CI/CD

| 工作流 | 触发条件 | 内容 |
|--------|----------|------|
| `ci.yml` | push/PR → main | 编译检查 + 四后端测试 + 格式检查 + 后端运行 |
| `pr-check.yml` | PR → main | 编译检查 + 格式检查 + wasm-gc快速测试 |
| `release.yml` | tag `v*` | 四后端构建产物 + GitHub Release发布 |

## License

MIT
