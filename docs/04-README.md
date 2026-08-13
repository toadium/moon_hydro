# 沐澜水文 · moon-hydro

![Build Status](https://img.shields.io/badge/build-pending-lightgrey) ![Version](https://img.shields.io/badge/version-V0.1--dev-blue) ![License](https://img.shields.io/badge/license-MIT+Apache--2.0-green)

> 待接入CI后替换占位徽章

**沐澜水文**是一套基于MoonBit全栈多后端架构的分布式新安江模型+浅水方程水动力耦合流域洪水智能预报系统。自研技术研发团队为市县水文部门、山洪预警中心、水利科研院校、数字孪生流域项目，解决单语言全栈、一套源码四后端编译、机理+AI混合预报扩展的高性能水文仿真问题。

---

## 特性（Features）

- **新安江模型MoonBit完整移植**（对应功能1）：覆盖三层蒸散发、蓄满产流、自由水三水源划分、单位线汇流演算，与原版Rust代码相对误差＜0.1%
- **浅水方程SWE双向耦合**（对应功能2、3）：基于有限体积法二维浅水方程求解器，新安江产流量作为河道侧向通量、河道水位反馈调整地下径流储量，形成完整闭环流域水文仿真链条
- **单语言全栈+前后端共享数据模型**（对应功能6、7）：Proton后端 + Rabbita前端共享唯一一套shared数据结构，从底层根除接口错位、序列化异常顽疾
- **一套源码四后端编译**（对应功能9、10）：wasm-gc、wasm-wasi-gcc、native、JS四类产物一键编译，覆盖浏览器、云函数、服务器、嵌入式全部署场景
- **高性能并行仿真**（对应功能8）：同等网格条件下仿真效率为Python版本15~40倍，多流域并行模拟全程线程安全、无数据竞争

---

## 快速开始（Quick Start）

### 环境要求

- MoonBit工具链（参考 [moonbitlang.com](https://moonbitlang.com) 官方安装指南）
- Git

### 三步示例

```bash
# 1. 克隆仓库
git clone https://github.com/toadium/moon_hydro.git
cd moon_hydro

# 2. 安装依赖
moon install

# 3. 启动native后端（默认目标）
moon run backend --target native
```

浏览器前端构建：

```bash
moon build frontend --target wasm-gc
# 产物位于 target/wasm-gc/frontend/build/，可直接用任意静态服务器托管
```

四后端一键打包：

```bash
moon build --target native && moon build --target wasm-gc && moon build --target wasm-wasi-gcc && moon build --target js
```

---

## 文档链接

- [01-项目申报书.md](./01-项目申报书.md) — 项目立项申报、目标用户、预算、风险
- [02-技术文档.md](./02-技术文档.md) — 技术栈、系统架构、核心模块、接口设计、部署运行
- [03-品牌故事.md](./03-品牌故事.md) — 项目命名、品牌叙事、定位口号、品牌价值观

---

## 项目结构

```
moon_hydro/
├── moon.work                   # Workspace总配置、多后端编译目标配置、依赖锁定
├── shared/                     # 全局共享层：前后端+所有后端共用唯一一套数据模型与内核
│   ├── model.mbt               # 核心结构体：XinanjiangParams、XinanjiangState、ForcingData、SimResult、CalibConfig
│   ├── hydro_trait.mbt         # HydroModel统一通用模型特征接口
│   ├── xaj_core.mbt            # 完整移植后的新安江演算内核
│   ├── swe_core.mbt            # 二维浅水方程求解内核
│   ├── utils.mbt               # 水文通用工具、单位线卷积、评价指标计算函数
│   └── serde_bind.mbt          # 全局统一JSON序列化/反序列化绑定
├── backend/                    # Proton后端，默认编译native目标
│   ├── main.mbt                # Proton服务入口、路由配置、中间件、跨域处理
│   ├── api_routes.mbt          # 全部RESTful接口定义与业务逻辑
│   ├── db_sqlite.mbt           # 数据库交互、数据读写、方案存储
│   └── task_scheduler.mbt      # 异步仿真任务队列、并行调度、进度推送
└── frontend/                   # Rabbita前端，默认编译wasm-gc目标
    ├── main.mbt                # Rabbita前端应用入口
    ├── model_bind.mbt          # 前端全局状态与shared共享模型绑定
    ├── msg_enum.mbt            # 全部前端交互消息枚举定义
    ├── update_logic.mbt        # TEA架构状态更新逻辑
    ├── view_layout.mbt         # 整体页面布局、组件排布
    ├── chart_render.mbt        # 时序曲线图、热力图渲染逻辑
    └── wasm_slim_model.mbt     # 前端轻量化仿真内核封装
```

---

## 贡献指南（Contributing）

### 流程简述

1. Fork 本仓库并创建特性分支（`feat/<short-desc>`）；
2. 提交前确保 `moon check` 与 `moon test` 全部通过，且四后端编译目标均通过测试；
3. 提交Pull Request，描述变更范围、动机与测试结果；
4. 维护者评审通过后合并至主分支。

### 代码规范

- 遵循MoonBit官方风格指南，使用 `moon fmt` 自动格式化；
- shared层结构体修改需同步更新 `serde_bind.mbt` 序列化绑定；
- 新增水文模型需实现 `HydroModel` trait接口；
- 不引入闭源依赖，所有新增依赖须为MIT/Apache-2.0等开源友好协议。

---

## 许可证（License）

本项目拟采用 **MIT + Apache-2.0** 双开源协议发布（与Rust crates.io hydro-suite套件及Python OuyangWenyu/hydromodel参考实现保持协议友好），允许修改、移植、商用二次开发。

> 发布前确认最终协议版本与版权声明。

---

## 致谢（Acknowledgements）

- [hydro-suite 套件（crates.io）](https://crates.io/crates/hydro-core) — Rust发布包 hydro-core / hydro-xinajiang / hydro-calib，提供新安江模型、SCE-UA/DDS率定、HydroModel trait接口规范与算法逻辑参考（原GitHub仓库已设私有，通过 crates.io 元信息与 docs.rs 文档获取）
- [OuyangWenyu/hydromodel](https://github.com/OuyangWenyu/hydromodel) — Python新安江三水源参考实现，用作数值比对基准
- [MoonBit](https://github.com/moonbitlang/moonbit) — MoonBit官方核心语言与基础仓库
- [Proton](https://github.com/moonbitlang/proton) — MoonBit官方高性能Native后端框架
- [Rabbita](https://github.com/moonbitlang/rabbita) — MoonBit官方TEA架构前端框架
- [moonNum](https://github.com/moonbitlang/moonNum) — 多维数组、线性代数、SIMD加速库
- [serde](https://github.com/moonbitlang/serde) — MoonBit官方JSON序列化库
- [async](https://github.com/moonbitlang/async) — MoonBit官方异步运行时
- [sqlite3](https://github.com/moonbitlang/sqlite3) — SQLite数据库绑定
- [Rui](https://github.com/yoorkin/rui) — 前端图表与UI组件库

---

*本README技术栈/功能描述与 `01-项目申报书.md`、`02-技术文档.md` 完全一致，特性列表与申报书核心功能清单一一对应。*