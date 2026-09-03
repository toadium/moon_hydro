# 沐澜水文 (hydro)

> 基于 MoonBit 全栈多后端架构的分布式新安江模型 + 浅水方程水动力耦合流域洪水智能预报系统

[![CI](https://github.com/toadium/moon_hydro/actions/workflows/ci.yml/badge.svg)](https://github.com/toadium/moon_hydro/actions/workflows/ci.yml)
[![PR Check](https://github.com/toadium/moon_hydro/actions/workflows/pr-check.yml/badge.svg)](https://github.com/toadium/moon_hydro/actions/workflows/pr-check.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![MoonBit](https://img.shields.io/badge/MoonBit-0.1.20260827-blue)](https://moonbitlang.com)
[![Tests](https://img.shields.io/badge/tests-373%20%C3%97%204%20backends-green)]()
[![Version](https://img.shields.io/badge/version-1.0.0-orange)]()

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
| **AI 混合预报** | LSTM 拋差校正 + 物理模型+AI 混合预报 |
| **GIS 接口** | DEM 分析（D8 流向/汇流累积/流域 delineation）+ 河网提取（Strahler 河序） |
| **洪水淹没推演** | 2D SWE 淹没仿真 + 风险图（5级分类）+ 损失评估（JRC曲线） |

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
```

---

## 项目结构

```
moon_hydro/
├── shared/                     # 共享层：数据模型 + 算法内核
├── ml/                         # AI 机器学习层
├── gis/                        # GIS 接口层
├── flood/                      # 洪水淹没推演层
├── persistence/                # 持久化存储层
├── backend/                    # 后端 CLI
├── frontend/                   # 前端 TEA 架构
├── docs/                       # 项目文档
├── .github/workflows/          # CI/CD
└── roadmap.md                  # 开发路线图
```

---

## 许可证

[MIT](LICENSE)
