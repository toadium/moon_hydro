///|
/// 洪水损失评估模块
///
/// 基于水深-损失率曲线和土地利用类型，估算洪水经济损失：
/// - 土地利用分类（住宅/商业/工业/农业/林地）
/// - 水深-损失率曲线（JRC曲线）
/// - 损失统计

///|
/// 土地利用类型
pub(all) enum LandUseType {
  Residential // 住宅
  Commercial // 商业
  Industrial // 工业
  Agricultural // 农业
  Forest // 林地
  Water // 水体
} derive(Debug, ToJson, FromJson, Eq)

///|
/// Show实现
pub impl Show for LandUseType with fn to_string(self : LandUseType) -> String {
  match self {
    Residential => "住宅"
    Commercial => "商业"
    Industrial => "工业"
    Agricultural => "农业"
    Forest => "林地"
    Water => "水体"
  }
}

///|
/// 土地利用图
pub(all) struct LandUseMap {
  nx : Int
  ny : Int
  types : Array[LandUseType] // [nx*ny]
  unit_value : Array[Double] // 各单元资产价值(万元)
} derive(Debug, ToJson, FromJson)

///|
/// 构造均匀土地利用图
pub fn LandUseMap::uniform(
  nx~ : Int,
  ny~ : Int,
  land_type~ : LandUseType,
  unit_value? : Double = 100.0,
) -> LandUseMap {
  let n_total = nx * ny
  {
    nx,
    ny,
    types: Array::make(n_total, land_type),
    unit_value: Array::make(n_total, unit_value),
  }
}

///|
/// 设置局部土地利用类型
pub fn LandUseMap::set_region(
  self : LandUseMap,
  i0~ : Int,
  i1~ : Int,
  j0~ : Int,
  j1~ : Int,
  land_type~ : LandUseType,
  unit_value~ : Double,
) -> Unit {
  for i in i0..<i1 {
    for j in j0..<j1 {
      if i >= 0 && i < self.nx && j >= 0 && j < self.ny {
        let k = i * self.ny + j
        self.types[k] = land_type
        self.unit_value[k] = unit_value
      }
    }
  }
}

///|
/// 水深-损失率曲线（JRC标准曲线）
///
/// 返回损失率(0~1)，基于水深和土地利用类型
/// 参考：Joint Research Centre 洪水损失函数
pub fn damage_ratio(depth : Double, land_type : LandUseType) -> Double {
  if depth <= 0.0 {
    return 0.0
  }
  match land_type {
    Residential =>
      // 住宅：水深0~3m，损失率0~70%
      if depth < 0.5 {
        depth * 0.2
      } else if depth < 1.0 {
        0.1 + (depth - 0.5) * 0.3
      } else if depth < 2.0 {
        0.25 + (depth - 1.0) * 0.2
      } else if depth < 3.0 {
        0.45 + (depth - 2.0) * 0.25
      } else {
        0.7
      }
    Commercial =>
      // 商业：水深0~3m，损失率0~85%
      if depth < 0.5 {
        depth * 0.3
      } else if depth < 1.0 {
        0.15 + (depth - 0.5) * 0.4
      } else if depth < 2.0 {
        0.35 + (depth - 1.0) * 0.25
      } else if depth < 3.0 {
        0.6 + (depth - 2.0) * 0.25
      } else {
        0.85
      }
    Industrial =>
      // 工业：水深0~3m，损失率0~80%
      if depth < 0.5 {
        depth * 0.25
      } else if depth < 1.0 {
        0.125 + (depth - 0.5) * 0.35
      } else if depth < 2.0 {
        0.3 + (depth - 1.0) * 0.22
      } else if depth < 3.0 {
        0.52 + (depth - 2.0) * 0.28
      } else {
        0.8
      }
    Agricultural =>
      // 农业：水深0~2m，损失率0~100%
      // P2-8修复：调整斜率使曲线在depth=2.0处连续（0.5+1.0*0.5=1.0）
      if depth < 0.5 {
        depth * 0.4
      } else if depth < 1.0 {
        0.2 + (depth - 0.5) * 0.6
      } else if depth < 2.0 {
        0.5 + (depth - 1.0) * 0.5
      } else {
        1.0
      }
    Forest =>
      // 林地：损失较小
      if depth < 1.0 {
        depth * 0.05
      } else {
        0.1
      }
    Water =>
      // 水体：无损失
      0.0
  }
}

///|
/// 损失评估结果
pub(all) struct DamageResult {
  total_damage : Double // 总损失(万元)
  residential_damage : Double // 住宅损失
  commercial_damage : Double // 商业损失
  industrial_damage : Double // 工业损失
  agricultural_damage : Double // 农业损失
  forest_damage : Double // 林地损失
  damaged_cells : Int // 受损单元数
  max_damage_cell : Int // 最大损失单元索引
  max_damage_value : Double // 最大单单元损失(万元)
} derive(Debug, ToJson, FromJson)

///|
/// 估算洪水经济损失
///
/// 基于最大水深场 + 土地利用图，计算各类型损失
pub fn estimate_damage(
  max_depth : Array[Double],
  land_use : LandUseMap,
) -> DamageResult {
  let n_total = land_use.nx * land_use.ny
  let mut total = 0.0
  let mut res_damage = 0.0
  let mut com_damage = 0.0
  let mut ind_damage = 0.0
  let mut agr_damage = 0.0
  let mut forest_damage = 0.0
  let mut damaged = 0
  let mut max_dmg = 0.0
  let mut max_dmg_cell = -1
  for k in 0..<n_total {
    let h = max_depth[k]
    if h <= 0.0 {
      continue
    }
    let ratio = damage_ratio(h, land_use.types[k])
    let dmg = ratio * land_use.unit_value[k]
    if dmg > 0.0 {
      total = total + dmg
      damaged = damaged + 1
      if dmg > max_dmg {
        max_dmg = dmg
        max_dmg_cell = k
      }
      match land_use.types[k] {
        Residential => res_damage = res_damage + dmg
        Commercial => com_damage = com_damage + dmg
        Industrial => ind_damage = ind_damage + dmg
        Agricultural => agr_damage = agr_damage + dmg
        Forest => forest_damage = forest_damage + dmg
        Water => ()
      }
    }
  }
  {
    total_damage: total,
    residential_damage: res_damage,
    commercial_damage: com_damage,
    industrial_damage: ind_damage,
    agricultural_damage: agr_damage,
    forest_damage,
    damaged_cells: damaged,
    max_damage_cell: max_dmg_cell,
    max_damage_value: max_dmg,
  }
}

///|
/// 生成合成土地利用图（演示用）
///
/// 上游为林地，中游为农业+住宅，下游为商业+工业
pub fn synthetic_land_use(nx~ : Int, ny~ : Int) -> LandUseMap {
  let map = LandUseMap::uniform(nx~, ny~, land_type=Forest, unit_value=10.0)
  // 上游：林地（保持默认）
  // 中游：农业 + 住宅
  map.set_region(
    i0=nx / 3,
    i1=nx * 2 / 3,
    j0=0,
    j1=ny,
    land_type=Agricultural,
    unit_value=20.0,
  )
  map.set_region(
    i0=nx / 3,
    i1=nx * 2 / 3,
    j0=ny / 4,
    j1=ny * 3 / 4,
    land_type=Residential,
    unit_value=200.0,
  )
  // 下游：商业 + 工业
  map.set_region(
    i0=nx * 2 / 3,
    i1=nx,
    j0=0,
    j1=ny / 2,
    land_type=Commercial,
    unit_value=500.0,
  )
  map.set_region(
    i0=nx * 2 / 3,
    i1=nx,
    j0=ny / 2,
    j1=ny,
    land_type=Industrial,
    unit_value=300.0,
  )
  map
}

///|
/// 损失统计摘要
pub fn DamageResult::to_summary(self : DamageResult) -> String {
  "总损失: \{self.total_damage}万元, 受损单元: \{self.damaged_cells}, 住宅: \{self.residential_damage}万, 商业: \{self.commercial_damage}万, 工业: \{self.industrial_damage}万, 农业: \{self.agricultural_damage}万, 林地: \{self.forest_damage}万, 最大单单元损失: \{self.max_damage_value}万"
}
