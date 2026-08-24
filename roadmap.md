# 沐澜水文 · 开发路线图

> 项目代号：moon-hydro ｜ 仓库：[toadium/moon_hydro](https://github.com/toadium/moon_hydro)

---

## 已完成版本

### V0.1 — 新安江模型核心 ✅

- [x] 工程骨架（shared/backend/frontend 三层）
- [x] 新安江三水源模型完整移植（`xaj_core.mbt`）
- [x] 一维浅水方程求解器（`swe_core.mbt`）
- [x] 基础评价指标（NSE/KGE/PBIAS）
- [x] native 后端验证

### V0.2 — JSON API 层 + 耦合 + 2D SWE ✅

- [x] JSON 序列化/反序列化服务（`serde_bind.mbt`）
- [x] 新安江 + SWE 双向耦合（`coupling.mbt`）
- [x] 二维浅水方程求解器（`swe2d.mbt`，dam-break）
- [x] 时间序列分析（统计/洪峰检测/基流分离/FDC/自相关）
- [x] API 请求/响应类型定义（`api.mbt`）

### V0.3 — 前端 TEA 架构 ✅

- [x] TEA Model 定义（AppModel/SimConfig/SimResultState/UiState/Page）
- [x] Msg 枚举（导航/仿真/率定/评价/批量/UI控制/错误/历史/重置）
- [x] update 纯函数式状态更新
- [x] ViewNode 虚拟 DOM + 文本渲染
- [x] 浏览器内轻量化试算封装（`wasm_slim_model.mbt`）

### V0.4 — 率定 + 批量仿真 + 流域校验 + CI/CD ✅

- [x] SCE-UA 全局优化算法（Shuffled Complex Evolution + CCE + Nelder-Mead）
- [x] DDS 动态维度搜索率定（已修复除零边界 bug）
- [x] 批量多流域仿真（`batch_sim.mbt`）
- [x] 集合仿真
- [x] 参数敏感性扫描
- [x] 蒙特卡洛不确定性分析（50 次采样，90% 置信区间）
- [x] 扩展评价指标（LogNSE/KGE 分解/MAE/MSE/RSR/一致性指数/PFC/持续性指数）
- [x] 实测流域校验（闽江竹岐/飞云江/青弋江 + 合成基准）
- [x] 边界容错测试（18 个鲁棒性用例：空输入/单元素/极端值/零除保护）
- [x] backend CLI 子命令（15 个：sim/calibrate/dds/validate/batch/ensemble/uncertainty/sensitivity/swe/coupling/timeseries/metrics/json/demo/help）
- [x] GitHub Actions CI/CD（ci.yml + pr-check.yml + release.yml）
- [x] 四后端全量测试通过（wasm/wasm-gc/js/native × 194 测试）

### V0.5 — 持久化 + 任务调度 + 覆盖率提升 ✅

- [x] frontend包拆分（`frontend/lib` 库包 + 薄入口），消除blackbox测试警告
- [x] 持久化存储模块（`persistence/`）：DataStore + JSON序列化 + C FFI文件I/O
- [x] 任务调度模块（`shared/task_scheduler.mbt`）：TaskScheduler + 进度回调
- [x] 性能基准测试模块（`shared/benchmark.mbt`）：10项基准测试
- [x] 测试覆盖率提升（238→150未覆盖行，256测试）
- [x] mooncakes.io发布dry-run验证通过
- [x] 权限框架（`shared/auth.mbt`）：用户管理 + API鉴权 + 方案隔离（26测试）

### V0.6 — AI 混合预报 ✅

- [x] LSTM 洪水预报 AI 模型（`ml/lstm.mbt`，前向传播+权重展平+随机搜索训练）
- [x] 混合预报（物理模型 + AI 校正）（`ml/hybrid.mbt`，残差学习+NSE改进）
- [x] AI矩阵运算库（`ml/matrix.mbt`，乘法/转置/sigmoid/tanh/归一化/Xavier初始化）

### V0.7 — GIS 接口 ✅

- [x] GIS基础类型（`gis/types.mbt`：点/线/多边形/DEM/河网拓扑）
- [x] DEM分析（`gis/dem.mbt`：D8流向/汇流累积/流域delineation/河网提取）
- [x] 河网处理（`gis/river.mbt`：Strahler河序/拓扑排序/上下游追溯）
- [x] `gis` CLI子命令演示

### V0.8 — 洪水淹没推演 ✅

- [x] 淹没推演核心（`flood/inundation.mbt`：2D SWE淹没仿真/到达时间/持续时间）
- [x] 风险图生成（`flood/risk_map.mbt`：5级风险分类/ASCII渲染/统计）
- [x] 损失评估（`flood/damage.mbt`：JRC水深-损失率曲线/6种土地利用/损失统计）
- [x] `flood` CLI子命令演示

### V0.9 — 全面代码审查与修复 ✅

- [x] 4路并行代码审查（shared/frontend+backend/ml+gis+flood/persistence+CI/CD+docs）
- [x] 105 项问题发现（1P0 + 19P1 + 43P2 + 42P3）
- [x] 102 项问题修复（3项P3合理跳过）
- [x] P0 修复：dem_to_swe_grid 索引顺序修正（非方阵网格不再错位）
- [x] P1 修复：C FFI 安全性、CLI argv 解析、评价功能实现、LSTM 优化等 19 项
- [x] CI/CD 增强：工具链缓存、Release 测试门禁、SHA256 校验和、PR native 检查
- [x] 新增 5 个回归测试，测试总数 368→373
- [x] moon check 0 错误 0 警告，CI/CD 全绿

### V0.9.1 — 第二轮审查修复 ✅

- [x] 4路并行代码审查（shared核心/ml+gis+flood/backend+frontend+persistence/config+CI+docs）
- [x] 17 项 P1 修复（重要bug/崩溃/错误结果）
- [x] 关键 P2 修复（文档同步、前端状态管理、C FFI 安全性）
- [x] 3 个编译警告清理（0 错误 0 警告）
- [x] 弱断言修复（matrix_test/gis types_test 用 .abs()）

### V0.9.2 — 第三轮深度审查修复 ✅

- [x] 4路并行深度审查（shared核心/shared辅助/ml+gis+flood/persistence+backend+frontend）
- [x] 10 项严重问题修复（新安江蒸散发/产流/不透水、LSTM预报、数据泄露、鉴权绕过、abort崩溃、季节相位、分位数截断）
- [x] 34 项一般问题修复（swe2d稳定性/耦合副作用/评价指标/错误处理/TEA状态完备性等）
- [x] 20 项轻微问题修复（注释/死代码/容差/版本号等）
- [x] 43 文件修改，moon check 0 错误 0 警告，415 测试通过

---

## 待开发版本

### V1.0 — 开源发布（第 6 个月末，2027 年 2 月）

- [ ] 全套文档完善（用户手册/API 文档/部署指南）
- [ ] README 精美化（示例图/性能基准/对比表）
- [x] 权限框架（API 鉴权/多用户/方案隔离） ✅ V0.5
- [x] 数据库持久化（仿真方案/历史结果/参数库） ✅ V0.5
- [x] 异步任务调度（并行仿真/进度推送） ✅ V0.5（顺序执行版，并行待async库）
- [x] 单位测试覆盖率提升至 90%+ ✅ V0.5
- [x] 性能基准测试与优化 ✅ V0.5
- [x] 开源 license/CONTRIBUTING/CHANGELOG ✅ V0.4
- [ ] mooncakes.io 包正式发布（dry-run已通过，待账号匹配）

### V1.1 — AI 预测 + 分布式（2027 年 3-8 月）

- [x] LSTM 洪水预报 AI 模型 ✅ V0.6（`ml/lstm.mbt`，前向传播+权重展平+随机搜索训练）
- [x] 混合预报（物理模型 + AI 校正） ✅ V0.6（`ml/hybrid.mbt`，残差学习+NSE改进）
- [x] GIS 接口（流域边界/河网/DEM） ✅ V0.7（`gis/`，D8流向/汇流累积/Strahler河序）
- [x] 洪水淹没推演（2D 水深/淹没范围/风险图） ✅ V0.8（`flood/`，淹没仿真/风险分类/损失评估）
- [ ] 分布式集群仿真调度
- [ ] RISC-V 嵌入式边缘终端适配
- [ ] 实时数据接入（气象雷达/雨量站/水位站）

### V1.2 — 生态扩展（2027 年 9 月+）

- [ ] Proton HTTP/WebSocket 后端框架集成
- [ ] Rabbita 前端框架集成（替换手写 TEA）
- [ ] moonNum 多维数组/SIMD 加速集成
- [ ] sqlite3 数据库绑定集成
- [ ] Rui 可视化图表组件库集成
- [ ] WebAssembly 云函数部署方案
- [ ] 多语言 FFI 绑定（Python/Julia 调用接口）

---

## 技术债务

| 优先级* | 事项 | 说明 |
|--------|------|------|
| ~~P1~~ | ~~frontend blackbox 测试警告~~ | ✅ V0.5已修复：拆分为frontend/lib库包 |
| ~~P1~~ | ~~全面代码审查与修复~~ | ✅ V0.9已完成：102/105项修复 |
| ~~P3~~ | ~~CI 缓存优化~~ | ✅ V0.9已修复：添加 actions/cache |
| P2 | 生态库依赖 | Proton/Rabbita/moonNum/sqlite-3/async/Rui 待 MoonBit 生态可用后集成 |
| P2 | `moon info` 接口文件管理 | `pkg.generated.mbti` 是否纳入版本控制 |
| ~~P3~~ | ~~moon.mod 包名与仓库 URL 组织不一致~~ | ✅ V0.9已修复：walkzzz→toadium，同步所有内部导入 |
| P3 | CI 覆盖率报告 | MoonBit 工具链尚无内置覆盖率支持 |

---

## 里程碑统计

| 版本 | 测试数 | 文件数 | 状态 |
|------|--------|--------|------|
| V0.1 | ~80 | ~15 | ✅ |
| V0.2 | ~120 | ~22 | ✅ |
| V0.3 | ~160 | ~28 | ✅ |
| V0.4 | 194 | 35 | ✅ |
| V0.5 | 282 | 44 | ✅ |
| V0.6 | 315 | 51 | ✅ |
| V0.7 | 339 | 57 | ✅ |
| V0.8 | 374 | 64 | ✅ |
| V0.9 | 383 | 72 | ✅ |
| V0.9.1 | 383 | 72 | ✅ |
| V0.9.2 | 415+ | 72 | ✅ |
| V1.0 | — | — | 待开发 |

---

*最后更新：2026-08-24｜当前版本：V0.9.2｜415+ 测试通过｜CI/CD 全绿｜mooncakes.io dry-run通过*