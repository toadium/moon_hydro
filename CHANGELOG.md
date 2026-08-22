# 变更日志

本项目遵循 [Keep a Changelog](https://keepachangelog.com/) 格式。

## [Unreleased]

### 计划中
- mooncakes.io 包正式发布
- 分布式集群仿真调度

## [0.9.0] - 2026-08-22

### 综述
全面代码审查与修复版本。4路并行审查发现 105 项问题（1P0+19P1+43P2+42P3），修复 102 项（3项P3合理跳过）。49 文件修改，+856 行，-351 行。测试 368→373（新增 5 回归测试），moon check 0 错误 0 警告，CI/CD 全绿。

### 修复 — shared/ 核心算法（27项，7P1+12P2+8P3）
- **P1**: step 函数路由状态丢失修复（xaj_core.mbt prev_qs/qi/qg 状态传递）
- **P1**: DDS 率定 target_metric 配置生效（calibration.mbt 支持 NSE/KGE 选择）
- **P1**: run_couple 返回 runoff_series（serde_bind.mbt API 层补全径流输出）
- **P1**: mock_flood_rainfall duration=1 除零修复（test_data.mbt）
- **P1**: HydroModel trait 泛化（状态类型参数化，支持 LSTM/SWE 等模型）
- **P1**: 密码哈希安全性增强（auth.mbt 改用更强哈希策略）
- **P1**: apply_boundary 不可变修复（swe_core.mbt 返回新网格而非就地修改）
- **P2/P3**: 12 项 P2 + 8 项 P3 修复（数值稳定性、代码简化、测试补充等）

### 修复 — frontend/ + backend/（24项，5P1+10P2+9P3）
- **P1**: CLI argv 解析实现（20 个子命令可通过命令行调用）
- **P1**: View 函数纯函数式修复（view_layout.mbt 移除 push 副作用）
- **P1**: AddHistory 函数式修复（update_logic.mbt）
- **P1**: RunEvaluation/EvaluationCompleted 评价功能实现
- **P1**: CalibrationCompleted 率定结果存入状态
- **P2/P3**: 10 项 P2 + 9 项 P3 修复（UI 改进、测试补充等）

### 修复 — ml/ + gis/ + flood/（23项，1P0+3P1+10P2+9P3）
- **P0**: dem_to_swe_grid 索引顺序修正（row*nx+col → i*ny+j，非方阵网格不再错位）
- **P1**: train_residual_lstm 整合 SCE-UA 优化
- **P1**: hybrid_forecast 时序上下文正确传递
- **P1**: lookback/input_dim 隐式耦合修复
- **P2/P3**: 10 项 P2 + 9 项 P3 修复（数值稳定性、测试补充等）

### 修复 — persistence/ + CI/CD + 文档 + 配置（31项，4P1+11P2+16P3）
- **P1**: C FFI 缓冲区溢出修复（fileio.c 添加 INT32_MAX 检查 + 1GB 大小上限）
- **P1**: Release 测试门禁（release.yml 新增 test job，测试通过后才构建发布）
- **P1**: README 测试数徽章修正（374→373）+ MoonBit 版本徽章更新
- **P1**: docs/04-README.md 完全替换（从 V0.1-dev 更新至 V0.9）
- **P2**: 空文件语义修复（新增 hydro_file_exists C FFI，区分空文件与文件不存在）
- **P2**: 测试文件清理（新增 hydro_delete_file C FFI + delete_file 封装）
- **P2**: CI/CD 工具链缓存（ci.yml/pr-check.yml/release.yml 添加 actions/cache）
- **P2**: release.yml 移除 `|| true` 静默吞错
- **P2**: .gitignore 补全（target/、.moon/、test_hydro_*.json 等）
- **P2**: 3 份文档版本更新（技术文档/用户手册/部署指南）
- **P3**: fclose 返回值检查、负值防御、冗余模式匹配简化、generate_id 验证
- **P3**: 4 个边界测试（空文件/大内容/delete_file）
- **P3**: CI 产物上传、PR native 检查、Release SHA256 校验和
- **P3**: 3 项跳过（list_all_results 优化/CI 覆盖率/moon.mod 包名变更）

### 变更
- 版本号 0.8.0 → 0.9.0
- 测试数量 368 → 373（wasm-gc），新增 5 回归测试
- MoonBit 工具链版本 0.1.20260819
- CI/CD 全绿，moon check 0 错误 0 警告

## [0.8.0] - 2026-08-16

### 新增
- 洪水淹没推演模块 `flood/`：2D SWE淹没仿真 + 风险图 + 损失评估
  - `flood/inundation.mbt`：淹没推演核心
    - 从DEM构造SWE网格 `dem_to_swe_grid`、设置入流 `set_inflow`
    - 淹没仿真 `simulate_inundation`（记录最大水深/到达时间/淹没持续时间）
    - 淹没范围提取 `extract_inundation_extent`、淹没统计 `inundation_stats`
    - 合成洪水场景 `synthetic_flood_scenario`
  - `flood/risk_map.mbt`：风险图生成
    - 风险分类 `classify_risk`（水深×流速危险度指数，5级：安全/低/中/高/极高）
    - 风险图生成 `generate_risk_map`、ASCII艺术渲染 `to_ascii_map`
    - 风险统计 `risk_statistics`
  - `flood/damage.mbt`：损失评估
    - 土地利用类型（住宅/商业/工业/农业/林地/水体）
    - JRC水深-损失率曲线 `damage_ratio`
    - 损失评估 `estimate_damage`、合成土地利用图 `synthetic_land_use`
  - `flood` CLI子命令演示
  - 35个测试用例（淹没推演8+风险图13+损失评估14）

### 变更
- 测试数量 339 → 374（native）
- CLI子命令 19 → 20（新增 flood）
- 新增 flood 包依赖到 backend

## [0.7.0] - 2026-08-16

### 新增
- GIS接口模块 `gis/`：DEM分析 + 河网提取 + 流域delineation
  - `gis/types.mbt`：基础类型（GeoPoint/XYPoint/Polyline/Polygon/BasinBoundary/DEMGrid/RiverNode/RiverReach/RiverNetwork）
    - 多边形面积（Shoelace公式）、形心计算、距离/长度计算
  - `gis/dem.mbt`：DEM处理
    - D8流向分析 `compute_flow_direction`
    - 汇流累积 `compute_flow_accumulation`（BFS拓扑排序）
    - 流域delineation `delineate_watershed`（反向BFS追溯）
    - 河网提取 `extract_river_network`、DEM统计、合成DEM生成
  - `gis/river.mbt`：河网处理
    - Strahler河序计算 `compute_strahler_orders`
    - 拓扑排序 `topological_order`
    - 源头追溯 `trace_to_sources`、出口追溯 `trace_to_outlet`
    - 从DEM+汇流累积提取河网拓扑 `extract_network_from_dem`
  - `gis` CLI子命令演示
  - 24个测试用例（类型8+DEM9+河网7）

### 变更
- 测试数量 315 → 339（native）/ 309（wasm-gc/wasm/js）
- CLI子命令 18 → 19（新增 gis）
- 新增 gis 包依赖到 backend
- 消除全部编译警告（0 warnings）

## [0.6.0] - 2026-08-16

### 新增
- AI机器学习模块 `ml/`：LSTM洪水预报 + 物理模型+AI混合预报
  - `ml/matrix.mbt`：矩阵/向量运算（乘法/转置/sigmoid/tanh/归一化/Xavier初始化）
  - `ml/lstm.mbt`：LSTM模型（前向传播/多步预报/权重展平/MSE目标函数）
  - `ml/hybrid.mbt`：混合预报（物理模型残差学习+随机搜索训练+NSE改进评价）
  - `ai_forecast` CLI子命令演示
  - 33个测试用例（矩阵15+LSTM10+混合预报8）

### 变更
- 测试数量 282 → 315（native）/ 309（wasm-gc/wasm/js）
- CLI子命令 17 → 18（新增 ai_forecast）
- 新增 ml 包依赖到 backend

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