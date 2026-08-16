# 变更日志

本项目遵循 [Keep a Changelog](https://keepachangelog.com/) 格式。

## [Unreleased]

### 计划中
- 全套文档完善（用户手册/API 文档/部署指南）
- 性能优化与并行仿真（接入async库后）
- mooncakes.io 包正式发布

## [0.5.1] - 2026-08-16

### 新增
- 权限框架模块 `shared/auth.mbt`：用户管理 + API鉴权 + 方案隔离
  - `Role` 枚举（Admin/Engineer/Viewer）、`Permission` 枚举（7项权限）
  - `AuthManager` 认证管理器：注册/登录/登出/Token验证
  - 方案所有权隔离：`grant_scheme_ownership`/`check_scheme_access`/`make_scheme_public`
  - 密码哈希（FNV-1a + splitmix）、Token生成（splitmix伪随机）
  - `auth` CLI子命令演示
  - 26个测试用例（角色权限/注册登录/Token验证/方案隔离/用户删除清理）

### 变更
- 测试数量 256 → 282（native）/ 276（wasm/wasm-gc/js）
- CLI子命令 16 → 17（新增 auth）
- API文档 150+ → 180+ 公开函数

## [0.5.0] - 2026-08-15

### 新增
- 持久化存储模块 `persistence/`：仿真方案/历史结果/参数库的JSON文件持久化读写
  - 内存DataStore + JSON序列化（全后端） + C FFI文件I/O（native）
  - `DataStore` CRUD操作、`SimulationScheme`/`ResultRecord`/`ParameterSet` 数据类型
  - `save_to_file`/`load_from_file` 文件持久化（native后端）
  - `persistence` CLI子命令
- 任务调度模块 `shared/task_scheduler.mbt`：批量仿真任务调度与进度推送
  - `TaskScheduler` 调度器、`TaskStatus` 状态跟踪、`ProgressInfo` 进度信息
  - `run_task`/`run_tasks` 带进度回调的批量执行
  - `create_task_from_basin`/`create_basin_tasks` 流域任务创建
- frontend包拆分：`frontend/lib` 库包 + `frontend` 薄入口，消除blackbox测试警告
- backend CLI白盒测试（18个用例），覆盖所有子命令函数
- frontend/lib TEA架构测试补充（16个用例），覆盖所有Msg变体与视图页面
- 性能基准测试模块 `shared/benchmark.mbt`：10项基准测试 + `bench` CLI子命令

### 修复
- MoonBit API适配：`@json.to_json(value)` → `value.to_json()`，`Repr` → 字符串插值
- frontend main package blackbox测试警告消除
- `persistence/fileio.c` C FFI文件I/O（fopen/fread/fwrite/fclose）

### 变更
- 版本号 0.4.0 → 0.5.0
- 测试数量 200 → 256（native）/ 250（wasm/wasm-gc/js）
- 未覆盖代码行 238 → 150

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