///|
/// TEA架构核心类型定义
///
/// The Elm Architecture: Model/Msg/Update/View分层
/// 纯数据描述UI，不依赖具体渲染框架
/// 后续接入Rabbita时可将View转换为Rabbita组件树

///|
/// 前端应用全局状态(Model)
///
/// 包含仿真配置、运行结果、UI状态
pub(all) struct AppModel {
  // 仿真配置
  sim_params : SimConfig
  // 仿真结果
  sim_result : SimResultState
  // UI状态
  ui_state : UiState
  // 历史记录
  history : Array[HistoryEntry]
  // 错误信息
  error_message : String
} derive(Debug, ToJson, FromJson)

///|
/// 仿真配置
pub(all) struct SimConfig {
  basin_name : String // 流域名称
  area : Double // 流域面积
  dt : Double // 时段
  params : @shared.XinanjiangParams // 新安江参数
  forcings : Array[@shared.ForcingData] // 气象驱动
} derive(Debug, ToJson, FromJson, Default)

///|
/// 仿真结果状态
pub(all) struct SimResultState {
  runoff_series : Array[Double] // 径流过程
  peak_flow : Double // 洪峰
  peak_time : Int // 洪峰时段
  nse : Double // NSE（仿真）
  kge : Double // KGE（仿真）
  pbias : Double // PBIAS（仿真）
  has_result : Bool // 是否有结果
  is_running : Bool // 是否正在运行
  calib_metric : String // 率定目标指标类型("nse"/"kge"等)
  calib_value : Double // 率定最优指标值
  batch_summary : String // 批量仿真结果摘要
  // P3修复：评价结果专用字段，避免与仿真结果混淆
  eval_nse : Double // 评价NSE
  eval_kge : Double // 评价KGE
  eval_pbias : Double // 评价PBIAS
} derive(Debug, ToJson, FromJson, Default)

///|
/// UI状态
pub(all) struct UiState {
  current_page : Page // 当前页面
  selected_basin : String // 选中的流域
  show_params_panel : Bool // 是否显示参数面板
  show_chart : Bool // 是否显示图表
  chart_type : ChartType // 图表类型
  loading : Bool // 加载状态
} derive(Debug, ToJson, FromJson, Default)

///|
/// 页面枚举
pub(all) enum Page {
  HomePage // 首页
  SimPage // 仿真页
  CalibPage // 率定页
  EvalPage // 评价页
  BatchPage // 批量页
  SettingsPage // 设置页
} derive(Debug, ToJson, FromJson, Eq)

///|
/// 图表类型
pub(all) enum ChartType {
  LineChart // 折线图
  BarChart // 柱状图
  HeatMap // 热力图
  ScatterPlot // 散点图
  Hydrograph // 流量过程线
} derive(Debug, ToJson, FromJson, Eq)

///|
/// Page的Default实现
pub impl Default for Page with fn default() {
  HomePage
}

///|
/// ChartType的Default实现
pub impl Default for ChartType with fn default() {
  Hydrograph
}

///|
/// Page的Show实现
pub impl Show for Page with fn to_string(self : Page) -> String {
  match self {
    HomePage => "首页"
    SimPage => "仿真"
    CalibPage => "率定"
    EvalPage => "评价"
    BatchPage => "批量"
    SettingsPage => "设置"
  }
}

///|
/// ChartType的Show实现
pub impl Show for ChartType with fn to_string(self : ChartType) -> String {
  match self {
    LineChart => "折线图"
    BarChart => "柱状图"
    HeatMap => "热力图"
    ScatterPlot => "散点图"
    Hydrograph => "流量过程线"
  }
}

///|
/// 历史记录条目
pub(all) struct HistoryEntry {
  timestamp : String // 时间戳
  action : String // 操作描述
  basin_name : String // 流域
  success : Bool // 是否成功
} derive(Debug, ToJson, FromJson, Default)

///|
/// 构造默认AppModel
pub fn AppModel::default() -> AppModel {
  {
    sim_params: {
      basin_name: "合成基准",
      area: 100.0,
      dt: 1.0,
      params: @shared.XinanjiangParams::default(),
      forcings: [
        { rainfall: 10.0, evaporation: 2.0, datetime: "t0" },
        { rainfall: 20.0, evaporation: 1.0, datetime: "t1" },
        { rainfall: 5.0, evaporation: 3.0, datetime: "t2" },
        { rainfall: 0.0, evaporation: 1.0, datetime: "t3" },
        { rainfall: 30.0, evaporation: 2.0, datetime: "t4" },
      ],
    },
    sim_result: {
      runoff_series: [],
      peak_flow: 0.0,
      peak_time: 0,
      nse: 0.0,
      kge: 0.0,
      pbias: 0.0,
      has_result: false,
      is_running: false,
      calib_metric: "",
      calib_value: 0.0,
      batch_summary: "",
      eval_nse: 0.0,
      eval_kge: 0.0,
      eval_pbias: 0.0,
    },
    ui_state: {
      current_page: HomePage,
      selected_basin: "合成基准",
      show_params_panel: false,
      show_chart: true,
      chart_type: Hydrograph,
      loading: false,
    },
    history: [],
    error_message: "",
  }
}

///|
/// 构造初始Model
/// P3-3：当前与default()相同，V1.0接入持久化后将从存储加载初始状态
pub fn AppModel::initial() -> AppModel {
  AppModel::default()
}
