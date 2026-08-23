///|
/// 洪水风险图生成模块
///
/// 基于淹没推演结果，生成洪水风险图：
/// - 根据水深×流速划分风险等级
/// - 生成ASCII艺术风险图
/// - 统计各风险等级面积

///|
/// 风险等级
pub(all) enum RiskLevel {
  Safe // 安全（未淹没）
  LowRisk // 低风险（可涉水通行）
  ModerateRisk // 中风险（成人困难）
  HighRisk // 高风险（不可通行）
  ExtremeRisk // 极高风险（危及生命）
} derive(Debug, ToJson, FromJson, Eq)

///|
/// Show实现
pub impl Show for RiskLevel with fn to_string(self : RiskLevel) -> String {
  match self {
    Safe => "安全"
    LowRisk => "低风险"
    ModerateRisk => "中风险"
    HighRisk => "高风险"
    ExtremeRisk => "极高风险"
  }
}

///|
/// 风险等级ASCII字符
fn risk_to_char(level : RiskLevel) -> String {
  match level {
    Safe => "."
    LowRisk => "o"
    ModerateRisk => "O"
    HighRisk => "#"
    ExtremeRisk => "@"
  }
}

///|
/// 风险图
pub(all) struct RiskMap {
  nx : Int
  ny : Int
  levels : Array[RiskLevel] // 风险等级数组[nx*ny]
  max_depth : Array[Double] // 最大水深(m)
  final_velocity : Array[Double] // 最终流速(m/s)
} derive(Debug, ToJson, FromJson)

///|
/// 风险分类标准
///
/// 综合水深和流速的危险度指数 D = h × (v + 0.5)
/// 参考：JRBM (Joint River Basin Management) 风险分类标准
pub fn classify_risk(depth : Double, velocity : Double) -> RiskLevel {
  if depth < 0.05 {
    return Safe
  }
  // 危险度指数 D = h × (v + 0.5)
  let danger = depth * (velocity + 0.5)
  // 水深单独判断
  if depth > 1.5 {
    return ExtremeRisk
  }
  if depth > 0.8 {
    if danger > 1.2 {
      return ExtremeRisk
    }
    return HighRisk
  }
  if depth > 0.3 {
    if danger > 0.6 {
      return HighRisk
    }
    return ModerateRisk
  }
  // depth in [0.05, 0.3]
  if danger > 0.3 {
    return ModerateRisk
  }
  LowRisk
}

///|
/// 从淹没推演结果生成风险图
///
/// 需要流速场（从hu/hv计算）
/// 注：P2-7：传入的hu/hv为最终时刻值，非最大流速。
/// 若需最大流速风险评估，应传入仿真过程中记录的max_hu/max_hv。
pub fn generate_risk_map(
  max_depth : Array[Double],
  hu_final : Array[Double],
  hv_final : Array[Double],
  nx~ : Int,
  ny~ : Int,
) -> RiskMap {
  let n_total = nx * ny
  let levels : Array[RiskLevel] = Array::make(n_total, Safe)
  // T41修复：流速从最终时刻动量模长计算，不与max_depth（不同时刻）混用
  let final_velocity = Array::make(n_total, 0.0)
  for k in 0..<n_total {
    let h = max_depth[k]
    let hu = hu_final[k]
    let hv = hv_final[k]
    let v = @math.pow(hu * hu + hv * hv, 0.5)
    final_velocity[k] = v
    levels[k] = classify_risk(h, v)
  }
  { nx, ny, levels, max_depth, final_velocity }
}

///|
/// 从淹没推演结果生成风险图（仅用水深，流速设为0）
pub fn generate_risk_map_depth_only(
  max_depth : Array[Double],
  nx~ : Int,
  ny~ : Int,
) -> RiskMap {
  let n_total = nx * ny
  let levels : Array[RiskLevel] = Array::make(n_total, Safe)
  let final_velocity = Array::make(n_total, 0.0)

  for k in 0..<n_total {
    levels[k] = classify_risk(max_depth[k], 0.0)
  }
  { nx, ny, levels, max_depth, final_velocity }
}

///|
/// 风险统计
/// P3-6：cell_area参数化，不再硬编码为1.0
pub fn risk_statistics(
  risk_map : RiskMap,
  cell_area? : Double = 1.0,
) -> RiskStatistics {
  let mut safe_count = 0
  let mut low_count = 0
  let mut moderate_count = 0
  let mut high_count = 0
  let mut extreme_count = 0
  for level in risk_map.levels {
    match level {
      Safe => safe_count = safe_count + 1
      LowRisk => low_count = low_count + 1
      ModerateRisk => moderate_count = moderate_count + 1
      HighRisk => high_count = high_count + 1
      ExtremeRisk => extreme_count = extreme_count + 1
    }
  }
  let total = risk_map.nx * risk_map.ny
  if total == 0 {
    return {
      total_cells: 0,
      safe_count: 0,
      low_risk_count: 0,
      moderate_risk_count: 0,
      high_risk_count: 0,
      extreme_risk_count: 0,
      safe_ratio: 0.0,
      inundated_ratio: 0.0,
      total_area: 0.0,
    }
  }
  {
    total_cells: total,
    safe_count,
    low_risk_count: low_count,
    moderate_risk_count: moderate_count,
    high_risk_count: high_count,
    extreme_risk_count: extreme_count,
    safe_ratio: safe_count.to_double() / total.to_double(),
    inundated_ratio: (total - safe_count).to_double() / total.to_double(),
    total_area: total.to_double() * cell_area,
  }
}

///|
/// 风险统计结果
pub(all) struct RiskStatistics {
  total_cells : Int
  safe_count : Int
  low_risk_count : Int
  moderate_risk_count : Int
  high_risk_count : Int
  extreme_risk_count : Int
  safe_ratio : Double // 安全占比
  inundated_ratio : Double // 淹没占比
  total_area : Double // 总面积(归一化)
} derive(Debug, ToJson, FromJson)

///|
/// 生成ASCII艺术风险图
///
/// 用字符表示风险等级：. o O # @
/// P3-7：x/y方向使用独立步长，避免非方阵网格变形
pub fn to_ascii_map(risk_map : RiskMap, max_width? : Int = 80) -> String {
  let nx = risk_map.nx
  let ny = risk_map.ny
  let step_x = if nx > max_width { (nx + max_width - 1) / max_width } else { 1 }
  let step_y = if ny > max_width { (ny + max_width - 1) / max_width } else { 1 }
  let mut result = ""
  result = result +
    "图例: .=安全 o=低风险 O=中风险 #=高风险 @=极高风险\n"
  result = result + "     (上游) N\n"
  // T42修复：外层迭代y轴(南北)，内层迭代x轴(东西)，与方向标注一致
  for j in 0..<ny {
    if j % step_y != 0 {
      continue
    }
    let mut row = ""
    for i in 0..<nx {
      if i % step_x != 0 {
        continue
      }
      let k = i * ny + j
      row = row + risk_to_char(risk_map.levels[k])
    }
    result = result + row + "\n"
  }
  result
}

///|
/// 统计信息字符串
pub fn RiskStatistics::to_summary(self : RiskStatistics) -> String {
  "总单元: \{self.total_cells}, 安全: \{self.safe_count}(\{self.safe_ratio * 100.0}%), 低风险: \{self.low_risk_count}, 中风险: \{self.moderate_risk_count}, 高风险: \{self.high_risk_count}, 极高风险: \{self.extreme_risk_count}, 淹没比: \{self.inundated_ratio * 100.0}%"
}
