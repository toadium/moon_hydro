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

---

## 待开发版本

### V1.0 — 开源发布（第 6 个月末，2027 年 2 月）

- [ ] 全套文档完善（用户手册/API 文档/部署指南）
- [ ] README 精美化（示例图/性能基准/对比表）
- [ ] 权限框架（API 鉴权/多用户/方案隔离）
- [ ] 数据库持久化（仿真方案/历史结果/参数库）
- [ ] 异步任务调度（并行仿真/进度推送）
- [ ] 单位测试覆盖率提升至 90%+
- [ ] 性能基准测试与优化
- [ ] 开源 license/CONTRIBUTING/CHANGELOG
- [ ] mooncakes.io 包发布

### V1.1 — AI 预测 + 分布式（2027 年 3-8 月）

- [ ] LSTM 洪水预报 AI 模型
- [ ] 混合预报（物理模型 + AI 校正）
- [ ] 分布式集群仿真调度
- [ ] GIS 接口（流域边界/河网/DEM）
- [ ] 洪水淹没推演（2D 水深/淹没范围/风险图）
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

| 优先级 | 事项 | 说明 |
|--------|------|------|
| P1 | frontend blackbox 测试警告 | Main package 不应有 `_test.mbt`，需拆分为非 main 包 |
| P2 | 生态库依赖 | Proton/Rabbita/moonNum/sqlite3/async/Rui 待 MoonBit 生态可用后集成 |
| P2 | `moon info` 接口文件管理 | `pkg.generated.mbti` 是否纳入版本控制 |
| P3 | CI 缓存优化 | MoonBit 工具链安装缓存，减少 CI 耗时 |

---

## 里程碑统计

| 版本 | 测试数 | 文件数 | 状态 |
|------|--------|--------|------|
| V0.1 | ~80 | ~15 | ✅ |
| V0.2 | ~120 | ~22 | ✅ |
| V0.3 | ~160 | ~28 | ✅ |
| V0.4 | 194 | 35 | ✅ |
| V1.0 | — | — | 待开发 |

---

*最后更新：2026-08-14｜当前版本：V0.4｜四后端 194 测试全通过｜CI/CD 全绿*