# 沐澜水文 (hydro)

> 基于 MoonBit 全栈多后端架构的分布式新安江模型 + 浅水方程水动力耦合流域洪水智能预报系统

[![CI](https://github.com/toadium/moon_hydro/actions/workflows/ci.yml/badge.svg)](https://github.com/toadium/moon_hydro/actions/workflows/ci.yml)
[![PR Check](https://github.com/toadium/moon_hydro/actions/workflows/pr-check.yml/badge.svg)](https://github.com/toadium/moon_hydro/actions/workflows/pr-check.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![MoonBit](https://img.shields.io/badge/MoonBit-0.1.20260713-blue)](https://moonbitlang.com)
[![Tests](https://img.shields.io/badge/tests-194%20%C3%97%204%20backends-green)]()

---

## 概述

沐澜水文以 MoonBit 单语言完成仿真内核、后端服务、前端界面全栈开发，前后端共享唯一一套数据模型。一套源码经四后端编译覆盖服务器集群、浏览器、Wasm 云函数、嵌入式边缘终端全部署场景。

### 核心能力

| 模块 | 功能 |
|------|------|
| **新安江模型** | 三水源四层蒸发完整移植，产汇流计算 |
| **浅水方程** | 1D/2D SWE 求解器，dam-break 模拟，CFL 自适应 |
| **双向耦合** | 新安江产流 → SWE 演算 → 水位反馈 |
| **参数率定** | SCE-UA 全局优化 + DDS 动态维度搜索 |
| **批量仿真** | 多流域批量/集合仿真/参数敏感性/蒙特卡洛不确定性 |
| **评价指标** | NSE/KGE/PBIAS/LogNSE/RSR/一致性指数/PFC 等 10+ 指标 |
| **流域校验** | 闽江竹岐/飞云江/青弋江实测流域验证 |
| **时间序列** | 统计/洪峰检测/基流分离/FDC/自相关 |
| **前端 TEA** | Model/Msg/Update/View 纯函数式架构 + 浏览器内试算 |

---

## 架构

```
                    ┌─────────────────────────────────┐
                    │          shared (核心层)          │
                    │  ┌──────────┐  ┌──────────┐     │
                    │  │ 新安江模型 │  │ SWE求解器 │     │
                    │  └────┬─────┘  └────┬─────┘     │
                    │       └──── 耦合 ────┘           │
                    │  ┌──────────┐  ┌──────────┐     │
                    │  │ SCE-UA率定│  │ DDS率定  │     │
                    │  └──────────┘  └──────────┘     │
                    │  ┌──────────┐  ┌──────────┐     │
                    │  │ 批量仿真  │  │ 评价指标 │     │
                    │  └──────────┘  └──────────┘     │
                    └────────┬──────────────┬────────┘
                             │              │
                    ┌────────▼────┐  ┌──────▼────────┐
                    │  backend    │  │  frontend     │
                    │  CLI 子命令  │  │  TEA 架构     │
                    │  (native)   │  │  (wasm-gc/js) │
                    └─────────────┘  └───────────────┘
```

### 四后端编译

| 后端 | 编译产物 | 部署场景 |
|------|----------|----------|
| `wasm-gc` | Wasm-GC + JS | 现代浏览器、WebView |
| `wasm` | Wasm + JS | Wasm 兼容环境 |
| `js` | 纯 JavaScript | Node.js、老旧浏览器 |
| `native` | 原生二进制 | Linux/Windows/macOS 服务器 |

---

## 快速开始

```bash
# 安装 MoonBit 工具链
curl -fsSL https://cli.moonbitlang.com/install/unix.sh | bash

# 克隆仓库
git clone https://github.com/toadium/moon_hydro.git
cd moon_hydro

# 编译检查
moon check

# 运行测试（四后端 × 194 测试）
moon test --target wasm-gc
moon test --target native

# 运行后端 CLI（15 个子命令）
moon run --target native backend
```

### CLI 子命令

| 命令 | 说明 |
|------|------|
| `sim` | 单次新安江模型仿真 |
| `calibrate` | SCE-UA 参数率定 |
| `dds` | DDS 动态维度搜索率定 |
| `validate` | 流域校验（闽江/飞云江/青弋江） |
| `batch` | 批量多流域仿真 |
| `ensemble` | 集合仿真 |
| `uncertainty` | 蒙特卡洛不确定性分析 |
| `sensitivity` | 参数敏感性扫描 |
| `swe` | 1D/2D 浅水方程仿真 |
| `coupling` | 新安江 + SWE 耦合仿真 |
| `timeseries` | 时间序列分析 |
| `metrics` | 扩展评价指标计算 |
| `json` | JSON API 端到端演示 |
| `demo` | 完整功能演示（默认） |

---

## 项目结构

```
moon_hydro/
├── shared/                     # 共享层：数据模型 + 算法内核
│   ├── model.mbt               # 核心结构体
│   ├── xaj_core.mbt            # 新安江演算内核
│   ├── swe_core.mbt            # 1D 浅水方程
│   ├── swe2d.mbt               # 2D 浅水方程
│   ├── coupling.mbt            # 新安江+SWE 耦合
│   ├── calibration.mbt         # DDS 率定
│   ├── sceua.mbt               # SCE-UA 全局优化
│   ├── evaluation.mbt          # 评价指标
│   ├── extended_metrics.mbt    # 扩展指标
│   ├── timeseries.mbt          # 时间序列分析
│   ├── batch_sim.mbt           # 批量/集合/敏感性/蒙特卡洛
│   ├── basin_cases.mbt         # 实测流域校验
│   └── serde_bind.mbt          # JSON 序列化
├── backend/                    # 后端 CLI
│   ├── main.mbt               # 入口分发器
│   └── cli.mbt                # 15 个子命令
├── frontend/                   # 前端 TEA 架构
│   ├── tea_arch.mbt           # Model 定义
│   ├── msg_enum.mbt           # Msg 枚举
│   ├── update_logic.mbt       # update 函数
│   ├── view_layout.mbt        # view 虚拟 DOM
│   └── wasm_slim_model.mbt    # 浏览器内试算
├── docs/                       # 项目文档
├── .github/workflows/          # CI/CD
└── roadmap.md                  # 开发路线图
```

---

## CI/CD

| 工作流 | 触发 | 内容 |
|--------|------|------|
| `ci.yml` | push/PR → main | 编译检查 + 四后端测试 + 格式检查 + 后端运行 |
| `pr-check.yml` | PR → main | 编译检查 + 格式检查 + wasm-gc 快速测试 |
| `release.yml` | tag `v*` | 四后端构建产物 + GitHub Release |

---

## 开发路线

详见 [roadmap.md](roadmap.md)。当前版本 **V0.4**，四后端 194 测试全通过。

| 版本 | 状态 | 核心内容 |
|------|------|----------|
| V0.1 | ✅ | 新安江模型 + 1D SWE |
| V0.2 | ✅ | JSON API + 耦合 + 2D SWE + 时间序列 |
| V0.3 | ✅ | 前端 TEA 架构 + 浏览器内试算 |
| V0.4 | ✅ | 率定 + 批量仿真 + 流域校验 + CI/CD |
| V1.0 | 待开发 | 文档完善 + 权限框架 + 开源发布 |
| V1.1 | 待开发 | AI 预测 + 分布式 + GIS + 洪水淹没 |

---

## 贡献

欢迎提交 Issue 和 Pull Request！详见 [CONTRIBUTING.md](CONTRIBUTING.md)。

## 许可证

[MIT](LICENSE)
