///|
/// 沐澜水文持久化存储模块
///
/// 提供仿真方案、历史结果、参数库的JSON文件持久化读写。
/// 内存DataStore + JSON序列化（全后端） + C FFI文件I/O（native）。

///|
/// 仿真方案
pub(all) struct SimulationScheme {
  id : String // 方案ID
  name : String // 方案名称
  basin_name : String // 流域名称
  area : Double // 流域面积
  dt : Double // 计算时段
  params : @shared.XinanjiangParams // 新安江参数
  forcings : Array[@shared.ForcingData] // 气象驱动
  created_at : UInt64 // 创建时间戳
  updated_at : UInt64 // 更新时间戳
} derive(Debug, ToJson, FromJson, Default)

///|
/// 仿真结果记录
pub(all) struct ResultRecord {
  id : String // 记录ID
  scheme_id : String // 关联方案ID
  basin_name : String // 流域名称
  peak_flow : Double // 洪峰流量
  peak_time : Int // 洪峰时段
  nse : Double // NSE
  kge : Double // KGE
  pbias : Double // PBIAS
  runoff_series : Array[Double] // 径流过程
  created_at : UInt64 // 创建时间戳
} derive(Debug, ToJson, FromJson, Default)

///|
/// 参数集
pub(all) struct ParameterSet {
  id : String // 参数集ID
  name : String // 参数集名称
  basin_name : String // 流域名称
  params : @shared.XinanjiangParams // 新安江参数
  description : String // 描述
  created_at : UInt64 // 创建时间戳
} derive(Debug, ToJson, FromJson, Default)

///|
/// 数据存储
pub(all) struct DataStore {
  schemes : Map[String, SimulationScheme] // 仿真方案
  results : Array[ResultRecord] // 仿真结果记录
  param_sets : Map[String, ParameterSet] // 参数集
} derive(Debug, ToJson, FromJson)

///|
/// 构造空DataStore
pub fn DataStore::new() -> DataStore {
  { schemes: {}, results: [], param_sets: {} }
}

///|
/// DataStore默认实现
pub impl Default for DataStore with fn default() {
  DataStore::new()
}

///|
/// 保存仿真方案
pub fn DataStore::save_scheme(
  self : DataStore,
  scheme : SimulationScheme,
) -> Unit {
  self.schemes[scheme.id] = scheme
}

///|
/// 加载仿真方案
pub fn DataStore::load_scheme(
  self : DataStore,
  id : String,
) -> SimulationScheme? {
  match self.schemes.get(id) {
    Some(s) => Some(s)
    None => None
  }
}

///|
/// 列出所有方案ID
pub fn DataStore::list_schemes(self : DataStore) -> Array[String] {
  let ids : Array[String] = []
  for id, _ in self.schemes {
    ids.push(id)
  }
  ids
}

///|
/// 删除仿真方案
pub fn DataStore::delete_scheme(self : DataStore, id : String) -> Bool {
  if self.schemes.contains(id) {
    ignore(self.schemes.remove(id))
    true
  } else {
    false
  }
}

///|
/// 保存仿真结果
pub fn DataStore::save_result(self : DataStore, result : ResultRecord) -> Unit {
  self.results.push(result)
}

///|
/// 查询方案的仿真结果
pub fn DataStore::list_results(
  self : DataStore,
  scheme_id : String,
) -> Array[ResultRecord] {
  let found : Array[ResultRecord] = []
  for r in self.results {
    if r.scheme_id == scheme_id {
      found.push(r)
    }
  }
  found
}

///|
/// 列出所有结果
pub fn DataStore::list_all_results(self : DataStore) -> Array[ResultRecord] {
  let found : Array[ResultRecord] = []
  for r in self.results {
    found.push(r)
  }
  found
}

///|
/// 保存参数集
pub fn DataStore::save_param_set(
  self : DataStore,
  param_set : ParameterSet,
) -> Unit {
  self.param_sets[param_set.id] = param_set
}

///|
/// 加载参数集
pub fn DataStore::load_param_set(
  self : DataStore,
  id : String,
) -> ParameterSet? {
  match self.param_sets.get(id) {
    Some(p) => Some(p)
    None => None
  }
}

///|
/// 列出所有参数集ID
pub fn DataStore::list_param_sets(self : DataStore) -> Array[String] {
  let ids : Array[String] = []
  for id, _ in self.param_sets {
    ids.push(id)
  }
  ids
}

///|
/// 删除参数集
pub fn DataStore::delete_param_set(self : DataStore, id : String) -> Bool {
  if self.param_sets.contains(id) {
    ignore(self.param_sets.remove(id))
    true
  } else {
    false
  }
}

///|
/// 统计信息
pub fn DataStore::stats(self : DataStore) -> String {
  "方案数=\{self.schemes.length()}, 结果数=\{self.results.length()}, 参数集数=\{self.param_sets.length()}"
}

///|
/// 序列化为JSON字符串
pub fn DataStore::to_json_string(self : DataStore) -> String {
  self.to_json().stringify()
}

///|
/// 从JSON字符串反序列化
pub fn DataStore::from_json_string(json_str : String) -> DataStore raise {
  let json = @json.parse(json_str)
  @json.from_json(json)
}

///|
/// 生成方案ID
pub fn generate_id(prefix : String, timestamp : UInt64) -> String {
  "\{prefix}_\{timestamp}"
}
