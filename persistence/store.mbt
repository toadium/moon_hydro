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
///
/// T54: 非线程安全——内部使用可变Map/Array，仅限单线程使用。
/// 若需并发访问，请封装为带锁的SyncDataStore或改为不可变值类型+CAS替换。
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
  self.schemes.get(id)
}

///|
/// 列出所有方案ID（排序输出）
pub fn DataStore::list_schemes(self : DataStore) -> Array[String] {
  let ids : Array[String] = []
  for id, _ in self.schemes {
    ids.push(id)
  }
  ids.sort()
  ids
}

///|
/// 删除仿真方案
///
/// T56: 级联删除results中所有scheme_id == id的记录
pub fn DataStore::delete_scheme(self : DataStore, id : String) -> Bool {
  if self.schemes.contains(id) {
    ignore(self.schemes.remove(id))
    // T56: 级联删除关联结果
    self.results.retain(fn(r) { r.scheme_id != id })
    true
  } else {
    false
  }
}

///|
/// 保存仿真结果
///
/// T55: 按id去重（upsert语义）——已存在同id记录则替换，否则追加
pub fn DataStore::save_result(self : DataStore, result : ResultRecord) -> Unit {
  for i in 0..<self.results.length() {
    if self.results[i].id == result.id {
      self.results[i] = result
      return
    }
  }
  self.results.push(result)
}

///|
/// 查询方案的仿真结果
///
/// P3修复：深拷贝runoff_series数组，防止外部修改破坏内部状态
pub fn DataStore::list_results(
  self : DataStore,
  scheme_id : String,
) -> Array[ResultRecord] {
  let found : Array[ResultRecord] = []
  for r in self.results {
    if r.scheme_id == scheme_id {
      found.push({ ..r, runoff_series: r.runoff_series.copy() })
    }
  }
  found
}

///|
/// 列出所有结果
///
/// P3修复：深拷贝runoff_series数组，防止外部修改破坏内部状态
pub fn DataStore::list_all_results(self : DataStore) -> Array[ResultRecord] {
  let copied : Array[ResultRecord] = []
  for r in self.results {
    copied.push({ ..r, runoff_series: r.runoff_series.copy() })
  }
  copied
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
  self.param_sets.get(id)
}

///|
/// 列出所有参数集ID（排序输出）
pub fn DataStore::list_param_sets(self : DataStore) -> Array[String] {
  let ids : Array[String] = []
  for id, _ in self.param_sets {
    ids.push(id)
  }
  ids.sort()
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
///
/// P3修复：包装JSON异常为StoreError::JsonError，与load_from_file策略一致
pub fn DataStore::from_json_string(json_str : String) -> DataStore raise {
  try {
    let json = @json.parse(json_str)
    @json.from_json(json)
  } catch {
    e => raise StoreError::JsonError(e.to_string())
  }
}

///|
/// T57: 存储层错误，包装FileError和JSON错误
///
/// P3修复：FileError载荷保留原始子类型，JsonError载荷为字符串（JSON错误无统一子类型）
pub(all) suberror StoreError {
  FileError(FileError)
  JsonError(String)
} derive(Debug, ToJson, FromJson)

///|
/// T53: ID生成计数器，避免同prefix+timestamp碰撞
///
/// 注意：非线程安全——全局可变Ref计数器，多协程并发调用存在竞争。
/// 测试间存在隐式顺序耦合（计数器值取决于先前调用次数）。
let id_counter : Ref[UInt64] = { val: 0UL }

///|
/// 生成方案ID
pub fn generate_id(prefix : String, timestamp : UInt64) -> String {
  id_counter.val = id_counter.val + 1UL
  "\{prefix}_\{timestamp}_\{id_counter.val}"
}
