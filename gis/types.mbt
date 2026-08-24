///|
/// GIS 基础类型模块
///
/// 提供水文GIS所需的矢量与栅格数据类型：
/// - 点/线/多边形（流域边界）
/// - DEM网格（数字高程模型）
/// - 河网拓扑（节点/连接/上下游）

///|
/// 地理坐标点（经纬度）
pub(all) struct GeoPoint {
  lon : Double // 经度
  lat : Double // 纬度
} derive(Debug, ToJson, FromJson, Default)

///|
/// 平面坐标点（投影坐标，如UTM）
pub(all) struct XYPoint {
  x : Double // X坐标(米)
  y : Double // Y坐标(米)
} derive(Debug, ToJson, FromJson, Default)

///|
/// 多段线（河流走向、边界线）
pub(all) struct Polyline {
  points : Array[XYPoint] // 顶点序列
  name : String // 名称
} derive(Debug, ToJson, FromJson, Default)

///|
/// 多边形（流域边界）
pub(all) struct Polygon {
  exterior : Array[XYPoint] // 外边界顶点（首尾相连）
  holes : Array[Array[XYPoint]] // 内部空洞（如岛屿）
  name : String // 流域名称
} derive(Debug, ToJson, FromJson, Default)

///|
/// 流域边界
pub(all) struct BasinBoundary {
  name : String // 流域名称
  polygon : Polygon // 边界多边形
  area : Double // 面积(km²)
  centroid : XYPoint // 形心坐标
} derive(Debug, ToJson, FromJson, Default)

///|
/// DEM网格（数字高程模型）
///
/// 规则网格高程数据，左上角为原点
pub(all) struct DEMGrid {
  nx : Int // 列数(X方向)
  ny : Int // 行数(Y方向)
  dx : Double // X方向分辨率(米)
  dy : Double // Y方向分辨率(米)
  x0 : Double // 左上角X坐标
  y0 : Double // 左上角Y坐标
  elevations : Array[Array[Double]] // 高程数组[ny][nx](米)
  nodata : Double // 无数据值
} derive(Debug, ToJson, FromJson)

///|
/// 河流节点
pub(all) struct RiverNode {
  id : Int // 节点ID
  point : XYPoint // 坐标
  elevation : Double // 高程(米)
  mut node_type : RiverNodeType // 节点类型
} derive(Debug, ToJson, FromJson)

///|
/// 河流节点类型
pub(all) enum RiverNodeType {
  Source // 源头
  Confluence // 汇流点
  Outlet // 流域出口
  Intermediate // 中间点
} derive(Debug, ToJson, FromJson, Eq)

///|
/// Show实现
pub impl Show for RiverNodeType with fn to_string(self : RiverNodeType) -> String {
  match self {
    Source => "源头"
    Confluence => "汇流点"
    Outlet => "出口"
    Intermediate => "中间点"
  }
}

///|
/// 河段（连接两个节点的线段）
pub(all) struct RiverReach {
  id : Int // 河段ID
  from_node : Int // 起始节点ID
  to_node : Int // 终止节点ID
  length : Double // 河段长度(米)
  slope : Double // 河段坡度
  mut order : Int // Strahler河序
} derive(Debug, ToJson, FromJson)

///|
/// 河网
pub(all) struct RiverNetwork {
  nodes : Map[Int, RiverNode] // 节点表
  reaches : Array[RiverReach] // 河段表
  mut outlet_id : Int // 流域出口节点ID
} derive(Debug)

///|
/// 构造空河网
pub fn RiverNetwork::new() -> RiverNetwork {
  { nodes: Map([]), reaches: [], outlet_id: -1 }
}

///|
/// 添加节点
pub fn RiverNetwork::add_node(self : RiverNetwork, node : RiverNode) -> Unit {
  self.nodes[node.id] = node
}

///|
/// 添加河段
pub fn RiverNetwork::add_reach(self : RiverNetwork, reach : RiverReach) -> Unit {
  self.reaches.push(reach)
}

///|
/// 获取节点的上游河段
pub fn RiverNetwork::upstream_reaches(
  self : RiverNetwork,
  node_id : Int,
) -> Array[RiverReach] {
  let result : Array[RiverReach] = []
  for reach in self.reaches {
    if reach.to_node == node_id {
      result.push(reach)
    }
  }
  result
}

///|
/// 获取节点的下游河段
pub fn RiverNetwork::downstream_reaches(
  self : RiverNetwork,
  node_id : Int,
) -> Array[RiverReach] {
  let result : Array[RiverReach] = []
  for reach in self.reaches {
    if reach.from_node == node_id {
      result.push(reach)
    }
  }
  result
}

///|
/// 计算多边形面积（Shoelace公式，返回绝对值）
pub fn polygon_area(polygon : Polygon) -> Double {
  let pts = polygon.exterior
  let n = pts.length()
  if n < 3 {
    return 0.0
  }
  let mut sum = 0.0
  for i in 0..<n {
    let j = (i + 1) % n
    sum = sum + pts[i].x * pts[j].y - pts[j].x * pts[i].y
  }
  // 取绝对值，避免顶点顺序（CW/CCW）导致负面积
  if sum < 0.0 {
    -sum / 2.0
  } else {
    sum / 2.0
  }
}

///|
/// 计算多边形形心
pub fn polygon_centroid(polygon : Polygon) -> XYPoint {
  let pts = polygon.exterior
  let n = pts.length()
  if n < 3 {
    return { x: 0.0, y: 0.0 }
  }
  let mut cx = 0.0
  let mut cy = 0.0
  let mut area = 0.0
  for i in 0..<n {
    let j = (i + 1) % n
    let cross = pts[i].x * pts[j].y - pts[j].x * pts[i].y
    area = area + cross
    cx = cx + (pts[i].x + pts[j].x) * cross
    cy = cy + (pts[i].y + pts[j].y) * cross
  }
  area = area / 2.0
  if area.abs() < 0.000000000001 {
    let mut sx = 0.0
    let mut sy = 0.0
    for p in pts {
      sx = sx + p.x
      sy = sy + p.y
    }
    return { x: sx / n.to_double(), y: sy / n.to_double() }
  }
  { x: cx / (6.0 * area), y: cy / (6.0 * area) }
}

///|
/// 构造流域边界
pub fn BasinBoundary::from_polygon(
  name~ : String,
  polygon : Polygon,
) -> BasinBoundary {
  let area = polygon_area(polygon) / 1000000.0
  let centroid = polygon_centroid(polygon)
  { name, polygon, area, centroid }
}

///|
/// DEM网格构造（均匀高程）
pub fn DEMGrid::uniform(
  nx~ : Int,
  ny~ : Int,
  dx~ : Double,
  dy~ : Double,
  x0? : Double = 0.0,
  y0? : Double = 0.0,
  h0? : Double = 0.0,
  nodata? : Double = -9999.0,
) -> DEMGrid {
  let elevations : Array[Array[Double]] = []
  for _ in 0..<ny {
    let row : Array[Double] = []
    for _ in 0..<nx {
      row.push(h0)
    }
    elevations.push(row)
  }
  { nx, ny, dx, dy, x0, y0, elevations, nodata }
}

///|
/// 获取DEM某点高程
pub fn DEMGrid::get_elevation(self : DEMGrid, i : Int, j : Int) -> Double {
  if i < 0 || i >= self.ny || j < 0 || j >= self.nx {
    return self.nodata
  }
  self.elevations[i][j]
}

///|
/// 设置DEM某点高程
pub fn DEMGrid::set_elevation(
  self : DEMGrid,
  i : Int,
  j : Int,
  value : Double,
) -> Unit {
  if i >= 0 && i < self.ny && j >= 0 && j < self.nx {
    self.elevations[i][j] = value
  }
}

///|
/// 判断DEM某点是否有数据
pub fn DEMGrid::has_data(self : DEMGrid, i : Int, j : Int) -> Bool {
  (self.get_elevation(i, j) - self.nodata).abs() > 0.00001
}

///|
/// 计算两点距离
pub fn xy_distance(a : XYPoint, b : XYPoint) -> Double {
  let dx = a.x - b.x
  let dy = a.y - b.y
  @math.pow(dx * dx + dy * dy, 0.5)
}

///|
/// 计算多段线长度
pub fn polyline_length(polyline : Polyline) -> Double {
  let pts = polyline.points
  let n = pts.length()
  if n < 2 {
    return 0.0
  }
  let mut total = 0.0
  for i in 0..<(n - 1) {
    total = total + xy_distance(pts[i], pts[i + 1])
  }
  total
}
