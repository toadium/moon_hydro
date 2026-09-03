# 变更日志

本项目遵循 [Keep a Changelog](https://keepachangelog.com/) 格式。

## [Unreleased]

### 计划中
- 分布式集群仿真调度



## [0.8.1] - 2026-09-03
### 综述
mooncakes.io 发布版本。因 mooncakes.io 早期阶段要求主版本号为 0，将发布版本定为 0.8.1。

### 变更
- 包名从 `toadium/moon_hydro` 改为 `walkzzz/moon_hydro`（匹配 mooncakes.io 账号）
- 6 个 moon.pkg 内部导入同步更新
- 版本号从 1.0.0 改为 0.8.1（mooncakes.io 要求 0.x.y 格式）
- 全部文档版本同步至 V0.8.1
- 历史代码审查引用修正为 V0.9（实际审查版本）

### 验证
- moon publish --dry-run: 202 Accepted ✅
- moon check: 0 错误 0 警告
- 151 测试通过

## [1.0.0] - 2026-09-03
### 综述
沐澜水文 V1.0.0 正式发布。基于 MoonBit 全栈多后端架构的分布式新安江模型 + 浅水方程水动力耦合流域洪水智能预报系统。

### 新增
- V1.0.0 版本号发布，GitHub Release v1.0.0 已触发（4 后端测试门禁 + 构建产物 + SHA256 校验和）
- 全套文档完善（用户手册/API 文档/部署指南/技术文档/品牌故事/项目申报书）
- README 精美化（badge/架构图/性能基准/包结构）

### 变更
- 版本升级 V0.9.3 → V1.0.0
- 接口文件重生成（4 个 pkg.generated.mbti）
- 代码格式化（45 文件）
- 全部文档版本同步至 V1.0.0

### 验证
- moon check: 0 错误 0 警告（wasm-gc/js/native 全后端）
- 415+ 测试通过
- 包结构验证通过
- MoonBit 0.1.20260827 兼容

### 里程碑
V1.0 开源发布里程碑完成：
- 新安江模型 + SWE 耦合 + SCE-UA/DDS 率定
- 批量仿真 + 评价指标 + 流域校验
- 前端 TEA + 持久化 + 任务调度 + 权限框架
- AI 混合预报 (LSTM) + GIS + 洪水淹没推演
- 3 轮代码审查 + 工具链兼容修复

## [0.9.3] - 2026-09-03

### 综述
MoonBit 工具链兼容性修复（0.1.20260819 → 0.1.20260827）。解决全后端编译错误、deprecated 警告、native 链接问题。moon check 0 错误 0 警告，已验证 158+ 测试通过。

### 修复 — 工具链兼容性（3项）
- **wasm-gc/js 编译错误**：persistence/store.mbt 引用 FileError 但该类型定义在 native-only 的 file_io.mbt 中，提取到 error.mbt 使全后端可见
- **deprecated to_string()/to_json() 警告**：auth.mbt、serde_bind.mbt、store.mbt、file_io.mbt、wasm_slim_model.mbt、main.mbt 共 8 处隐式 trait 方法提升，改用 Show::to_string() / ToJson::to_json() 显式调用
- **native 链接错误**：TCC 链接器找不到 libpthread/libc，符号链接系统库到 ~/.moon/lib/

### 变更
- CI 配置 MoonBit 版本升级至 0.1.20260827
- 新增 persistence/error.mbt（FileError 类型定义，全后端可见）

## [0.9.2] - 2026-08-24

### 综述
第三轮深度代码审查与修复。4路并行审查发现 10 严重 + 34 一般 + 20 轻微共 64 项问题，全部修复。43 文件修改，+528 行，-230 行。moon check 0 错误 0 警告，415 测试通过。

### 修复 — 严重问题（10项）
- **xaj_core 蒸散发分支条件错误**：深层蒸散发ED恒为0，干旱期蒸散发低估~83%，破坏水量平衡（C取倒数+下层sufficiency判据错误）
- **xaj_core 产流公式PE重复计入**：compute_evaporation已将PE加入state.w，compute_runoff又显式加PE，等价于W+2PE计算产流，产流偏大~52%
- **xaj_core 不透水产流注入自由水**：R_im应直接成为地表径流，不应经过自由水蓄量三水源划分
- **lstm forecast首步输入重复**：forward_with_state后首步又用history末位x_T，违反自回归语义
- **hybrid prepare_rainfall_runoff缺lookback<=0校验**：负lookback导致负索引崩溃
- **hybrid_forecast测试段数据泄露**：推理阶段用未来观测残差作LSTM输入，NSE偏乐观
- **auth grant_scheme_ownership鉴权绕过**：任意Engineer可夺取方案所有权（角色级→方案级校验）
- **serde_bind JSON端点abort崩溃**：非法输入abort终止服务进程，改用raise+try-catch返回错误响应
- **test_data 季节性降雨相位反转**：北半球流域冬季多雨夏季少雨，修正为夏季峰值
- **batch_sim 蒙特卡洛分位数整数截断**：未同步P2-18线性插值修复，小样本不确定性带系统性高估

### 修复 — 一般问题（34项）
- swe2d最终时刻稳定性检查缺失/不稳定步仍推进（与1D对齐）
- calibration params_to_xaj率定wm时同步缩放wum/wlm/wdm
- coupling couple_step深拷贝入参避免就地修改/couple_run不稳定提前终止
- dem D8流向nodata判定统一容差/汇流累积环路单元补加自身贡献
- inundation终态arrival_time记录/inundation_stats阈值参数化
- risk_map classify_risk阈值改>=/generate_risk_map用终态水深算流速
- river trace_to_outlet多下游选最大Strahler序
- evaluation FloodVolume Qualified阈值/peak_time_error初始化&校验/peak_relative_error长度校验
- extended_metrics log_nse NaN转哨兵/PFC分母用有效点数/RSR样本标准差
- task_scheduler run_task校验area/dt/add_task返回Bool
- auth delete_user清理login_attempts
- batch_sim set_xaj_param未知参数fail-fast
- api CalibrateRequest.config改Option[DDSConfig]
- basin_cases空结果min/max置0
- test_data mock_multi_peak_rainfall半正弦波形闭合
- persistence read_file UTF-8异常包装/load_from_file统一StoreError/StoreError保留子类型/from_json_string包装/list_all_results深拷贝
- frontend 缺BatchFailed/EvaluationFailed消息/RunBatchSim清error/RunSimulation清has_result/view_calibration显示结果/加载案例按钮/评价专用字段
- cli版本号更新

### 修复 — 轻微问题（20项）
- coupling注释修正/sceua标注简化变体/swe2d标注一阶精度
- matrix死代码清理/lstm mse长度不等返回NaN
- types polygon_centroid容差判定
- timeseries moving_average注释/detect_peaks首点判定
- benchmark含偏差评价基准/model CalibConfig移除derive(Default)
- file_io validate_path精确遍历检查/空路径检查/fileio.c fchmod检查
- tea_arch AppModel移除derive(Default)/update_logic清除策略统一/view_batch显示summary
- wasm_slim_model错误消息区分/未知流域注释

## [0.9.1] - 2026-08-24

### 综述
第二轮全面代码审查与修复。4路并行审查发现 17 P1 + 40 P2 + 50 P3 项问题，修复全部 17 项 P1（重要bug/崩溃/错误结果）及关键 P2 项。22 文件修改，+130 行，-57 行。moon check 0 错误 0 警告。

### 修复 — P1 重要bug（17项）
- **P1**: xaj_core compute_evaporation em=0 除零保护（em_safe 用极小值替代 0.0）
- **P1**: xaj_core compute_source_split ex=-1 除零保护（加 ex_safe 守卫）
- **P1**: swe_core apply_boundary nx=1 数组越界保护（nx<2 提前返回）
- **P1**: coupling couple_run xaj_state 未更新修复（状态现在正确累积）
- **P1**: calibration gaussian_perturbation Box-Muller NaN 修复（u1=1.0-next_double()）
- **P1**: hybrid train_residual_lstm 全局搜索用错 input 数组修复（inputs→adjusted_inputs）
- **P1**: risk_map generate_risk_map 动量当流速修复（除以水深得流速 m/s）
- **P1**: hybrid prepare_sequences lookback<=0 崩溃保护
- **P1**: damage estimate_damage 无长度检查修复（加 bounds check）
- **P1**: cli_persistence UTF-8 字节截断修复（用 safe_preview）
- **P1**: frontend main UTF-8 字节截断修复（加 char-safe preview）
- **P1**: file_io validate_path null 字节注入防护
- **P1**: fileio.c hydro_read_file fseek 返回值检查
- **P1**: file_io read_file file_size<0 静默返回空修复
- **P1**: release.yml actions/download-artifacts→download-artifact 修复
- **P1**: 3 个编译警告清理（cli_demo/slim_json_endpoint unused raise, unused variable e）
- **P1**: matrix_test/gis types_test 弱断言修复（用 .abs() 替代单向比较）

### 修复 — P2 改进
- **P2**: README 当前版本 V0.8→V0.9
- **P2**: frontend SimulationFailed 清除旧 has_result
- **P2**: frontend slim_run 使用实际加载的流域参数
- **P2**: fileio.c fsync 返回值检查

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