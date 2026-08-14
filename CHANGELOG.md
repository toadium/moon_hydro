# 变更日志

本项目遵循 [Keep a Changelog](https://keepachangelog.com/) 格式。

## [Unreleased]

### 计划中
- 全套文档完善（用户手册/API 文档/部署指南）
- 权限框架（API 鉴权/多用户/方案隔离）
- 数据库持久化（仿真方案/历史结果/参数库）
- 异步任务调度（并行仿真/进度推送）
- 性能基准测试与优化
- mooncakes.io 包发布

## [0.4.0] - 2026-08-14

### 新增
- SCE-UA 全局优化率定算法（Shuffled Complex Evolution + CCE + Nelder-Mead 单纯形）
- 批量多流域仿真（`shared/batch_sim.mbt`）
- 多情景集合仿真
- 参数敏感性扫描
- 蒙特卡洛不确定性分析（采样/分位数/置信区间）
- 扩展评价指标：LogNSE、KGE 分解(r/α/β)、MAE、MSE、RSR、一致性指数、PFC、持续性指数
- 实测流域校验案例：闽江竹岐/飞云江/青弋江 + 合成基准
- 边界容错测试（18 个鲁棒性用例）
- backend CLI 子命令（15 个：sim/calibrate/dds/validate/batch/ensemble/uncertainty/sensitivity/swe/coupling/timeseries/metrics/json/demo/help）
- GitHub Actions CI/CD（ci.yml + pr-check.yml + release.yml）
- 开发路线图 `roadmap.md`

### 修复
- DDS 率定 `dds_perturb` 函数空参数除零崩溃（`calibration.mbt`）
- `robustness_test.mbt` 中 `fail` 调用的未解析类型变量警告
- MoonBit 安装脚本 URL 从 `install.sh` 更正为 `install/unix.sh`
- `actions/checkout` 升级至 v5 消除 Node.js 20 弃用警告

### 变更
- 技术文档更新依赖清单、目录结构、开发计划
- 新增 V0.4 交付清单

## [0.3.0] - 2026-08-14

### 新增
- frontend TEA 架构（Model/Msg/Update/View 四层）
- AppModel/SimConfig/SimResultState/UiState/Page 状态定义
- Msg 枚举（导航/仿真/率定/评价/批量/UI控制/错误/历史/重置）
- ViewNode 虚拟 DOM + 文本渲染
- 浏览器内轻量化试算封装（`wasm_slim_model.mbt`）
- TEA 架构测试 + 轻内试算测试

## [0.2.0] - 2026-08-14

### 新增
- JSON 序列化/反序列化服务层（`serde_bind.mbt`）
- 新安江 + SWE 双向耦合仿真（`coupling.mbt`）
- 二维浅水方程求解器（`swe2d.mbt`，支持 dam-break 初始条件）
- 时间序列分析（统计/洪峰检测/基流分离/流量历时曲线/自相关）
- API 请求/响应类型定义（`api.mbt`）
- JSON 端点函数（xaj_json_endpoint/swe_json_endpoint/evaluate_json_endpoint）

## [0.1.0] - 2026-08-14

### 新增
- 工程骨架（shared/backend/frontend 三层 + moon.mod）
- 新安江三水源模型完整移植（`xaj_core.mbt`）
- 一维浅水方程求解器（`swe_core.mbt`）
- 基础评价指标（NSE/KGE/PBIAS/预报等级评定）
- DDS 动态维度搜索率定（`calibration.mbt`）
- HydroModel 统一特征接口（`hydro_trait.mbt`）
- 核心数据结构（XinanjiangParams/ForcingData/SimResult 等）
- native 后端验证

---

## 版本约定

- `MAJOR.MINOR.PATCH` 语义化版本
- `0.x.y` 阶段：API 不保证稳定，向前兼容不保证
- `1.0.0` 起：遵循语义化版本规范