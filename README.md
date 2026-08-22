# 沐澜水文 (hydro)

> 基于 MoonBit 全栈多后端架构的分布式新安江模型 + 浅水方程水动力耦合流域洪水智能预报系统

[![CI](https://github.com/toadium/moon_hydro/actions/workflows/ci.yml/badge.svg)](https://github.com/toadium/moon_hydro/actions/workflows/ci.yml)
[![PR Check](https://github.com/toadium/moon_hydro/actions/workflows/pr-check.yml/badge.svg)](https://github.com/toadium/moon_hydro/actions/workflows/pr-check.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![MoonBit](https://img.shields.io/badge/MoonBit-0.1.20260819-blue)](https://moonbitlang.com)
[![Tests](https://img.shields.io/badge/tests-368%20%C3%97%204%20backends-green)]()
[![Version](https://img.shields.io/badge/version-0.8.0-orange)]()

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
| **持久化存储** | 仿真方案/历史结果/参数库 CRUD + JSON 文件 I/O（C FFI） |
| **任务调度** | 批量仿真任务队列 + 进度回调 + 状态跟踪 |
| **性能基准** | 10 项基准测试，均值/标准差/吞吐量统计 |
| **权限框架** | 用户管理 + API 鉴权（Token） + 方案隔离（RBAC） |
| **AI 混合预报** | LSTM 残差校正 + 物理模型+AI 混合预报 |
| **GIS 接口** | DEM 分析（D8 流向/汇流累积/流域 delineation）+ 河网提取（Strahler 河序） |
| **洪水淹没推演** | 2D SWE 淹没仿真 + 风险图（5级分类）+ 损失评估（JRC曲线） |

---

## 架构

```
                    ┌─────────────────────────────────────┐
                    │           shared (核心层)             │
                    │  ┌──────────┐  ┌──────────┐         │
                    │  │ 新安江模型 │  │ SWE求解器 │         │
                    │  └────┬─────┘  └────┬─────┘         │
                    │       └──── 耦合 ────┘               │
                    │  ┌──────────┐  ┌──────────┐         │
                    │  │ SCE-UA率定│  │ DDS率定  │         │
                    │  └──────────┘  └──────────┘         │
                    │  ┌──────────┐  ┌──────────┐         │
                    │  │ 批量仿真  │  │ 评价指标 │         │
                    │  └──────────┘  └──────────┘         │
                    │  ┌──────────┐  ┌──────────┐         │
                   │  │ 任务调度  │  │ 性能基准  │         │
                   │  └──────────┘  └──────────┘         │
                   └──────┬──────────────────┬──────────┘
                          │                  │
                   ┌──────▼────┐    ┌────────▼──────┐
                   │  backend   │    │  frontend     │
                   │  CLI 20命令 │    │  TEA 架构     │
                   │  (native)  │    │  (wasm-gc/js) │
                   └──────┬─────┘    └───────────────┘
                          │
              ┌───────────┼───────────┐
              │           │           │
       ┌──────▼──────┐ ┌──▼───┐ ┌────▼────┐
       │ persistence │ │ ml/  │ │  gis/   │
       │ DataStore   │ │ LSTM │ │ DEM/河网│
       │ + C FFI I/O │ │ 混合 │ │ 流域分析│
       │ (native)    │ │ 预报 │ │         │
       └─────────────┘ └──────┘ └─────────┘
                              │
                       ┌──────▼──────┐
                       │   flood/    │
                       │ 淹没推演    │
                       │ 风险图+损失 │
                       └─────────────┘
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

# 运行测试（四后端 × 368 测试）
moon test --target wasm-gc
moon test --target native

# 运行后端 CLI（20 个子命令）
moon run --target native backend

# 运行性能基准测试
moon run --target native backend benchmark

# 运行AI混合预报演示
moon run --target native backend ai_forecast

# 运行GIS接口演示
moon run --target native backend gis

# 运行洪水淹没推演演示
moon run --target native backend flood
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
| `persistence` | 持久化存储演示（方案/结果/参数库 CRUD） |
| `benchmark` | 性能基准测试（10 项基准） |
| `auth` | 权限框架演示（用户/鉴权/方案隔离） |
| `ai_forecast` | AI 混合预报演示（LSTM 残差校正） |
| `gis` | GIS 接口演示（DEM 流向/汇流累积/河网提取） |
| `flood` | 洪水淹没推演（2D 水深/风险图/损失评估） |
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
│   ├── task_scheduler.mbt      # 任务调度 + 进度回调
│   ├── benchmark.mbt           # 性能基准测试框架
│   ├── auth.mbt                # 权限框架（用户/鉴权/方案隔离）
│   └── serde_bind.mbt          # JSON 序列化
├── ml/                         # AI 机器学习层
│   ├── matrix.mbt              # 矩阵/向量运算
│   ├── lstm.mbt                # LSTM 模型（前向传播/训练）
│   └── hybrid.mbt              # 混合预报（物理+AI残差校正）
├── gis/                        # GIS 接口层
│   ├── types.mbt               # 基础类型（点/线/多边形/DEM/河网）
│   ├── dem.mbt                 # DEM 分析（D8流向/汇流累积/流域delineation）
│   └── river.mbt               # 河网处理（Strahler河序/拓扑排序/追溯）
├── flood/                      # 洪水淹没推演层
│   ├── inundation.mbt          # 淹没仿真（2D SWE/到达时间/持续时间）
│   ├── risk_map.mbt            # 风险图（5级分类/ASCII渲染/统计）
│   └── damage.mbt              # 损失评估（JRC曲线/土地利用/损失统计）
├── persistence/                # 持久化存储层
│   ├── store.mbt               # DataStore + JSON 序列化
│   ├── file_io.mbt             # C FFI 文件 I/O（native）
│   └── fileio.c                # C 实现
├── backend/                    # 后端 CLI
│   ├── main.mbt               # 入口分发器
│   └── cli.mbt                # 20 个子命令
├── frontend/                   # 前端 TEA 架构
│   ├── main.mbt               # 薄入口
│   └── lib/                   # TEA 库包
│       ├── tea_arch.mbt       # Model 定义
│       ├── msg_enum.mbt       # Msg 枚举
│       ├── update_logic.mbt   # update 函数
│       ├── view_layout.mbt    # view 虚拟 DOM
│       └── wasm_slim_model.mbt# 浏览器内试算
├── docs/                       # 项目文档
│   ├── 用户手册.md             # 完整使用指南
│   ├── 部署指南.md             # 部署指南
│   └── API.md                 # API 文档
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

## 性能基准

`moon run --target native backend benchmark` 输出 10 项基准测试结果（native 后端，典型值）：

| 基准测试 | 规模 | 典型吞吐 |
|----------|------|----------|
| 新安江模型仿真 | 100 步 | ~5000 ops/s |
| 1D SWE 求解 | 100 单元 × 100 步 | ~3000 ops/s |
| 2D SWE 求解 | 30×30 网格 × 50 步 | ~500 ops/s |
| SCE-UA 率定 | 11 参数 × 30 迭代 | ~50 ops/s |
| DDS 率定 | 11 参数 × 30 迭代 | ~80 ops/s |
| 批量仿真 | 10 流域 × 100 步 | ~800 ops/s |
| 耦合仿真 | 20 步 | ~4000 ops/s |
| 扩展评价指标 | 100 点 | ~50000 ops/s |
| 蒙特卡洛不确定性 | 20 采样 | ~30 ops/s |
| JSON 序列化 | 100 步请求 | ~30000 ops/s |

> 实际数值取决于硬件。基准测试统计均值/最小/最大/标准差/吞吐量。

---

## 功能对比

| 特性 | 沐澜水文 | 传统 Fortran/C | Python 框架 |
|------|:--------:|:--------------:|:-----------:|
| 单语言全栈 | ✅ | ❌ | ✅ |
| 四后端编译 | ✅ | ❌ | ❌ |
| 前后端共享数据模型 | ✅ | ❌ | ✅ |
| 浏览器内试算 | ✅ | ❌ | ❌ |
| Wasm 云函数 | ✅ | ❌ | ❌ |
| 嵌入式边缘终端 | ✅ | ✅ | ❌ |
| 类型安全 | ✅ | ❌ | ❌ |
| 无 GC 运行时（native） | ✅ | ✅ | ❌ |

---

## 开发路线

详见 [roadmap.md](roadmap.md)。当前版本 **V0.8**，四后端 368 测试全通过。

| 版本 | 状态 | 核心内容 |
|------|------|----------|
| V0.1 | ✅ | 新安江模型 + 1D SWE |
| V0.2 | ✅ | JSON API + 耦合 + 2D SWE + 时间序列 |
| V0.3 | ✅ | 前端 TEA 架构 + 浏览器内试算 |
| V0.4 | ✅ | 率定 + 批量仿真 + 流域校验 + CI/CD |
| V0.5 | ✅ | 持久化 + 任务调度 + 性能基准 + 权限框架 |
| V0.6 | ✅ | AI 混合预报（LSTM + 物理模型残差校正） |
| V0.7 | ✅ | GIS 接口（DEM 分析 + 河网提取 + 流域 delineation） |
| V0.8 | ✅ | 洪水淹没推演（2D SWE + 风险图 + 损失评估） |
| V1.0 | 待开发 | 文档完善 + 开源发布 |
| V1.1 | 待开发 | 分布式 + 实时数据 |

---

## 贡献

欢迎提交 Issue 和 Pull Request！详见 [CONTRIBUTING.md](CONTRIBUTING.md)。

## 许可证

[MIT](LICENSE)
