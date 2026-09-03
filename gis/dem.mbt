///|
/// DEM 处理模块
///
/// 提供数字高程模型的分析功能：
/// - D8流向分析：确定每个网格单元的水流方向
/// - 汇流累积：计算每个单元上游汇水面积
/// - 流域delineation：从出口点追溯流域边界

///|
/// D8流向编码（8方向）
///
/// 4 3 2
/// 5 0 1
/// 6 7 8
/// 0=平坦/无数据, 1-8=流向方向
pub(all) struct FlowDirection {
  nx : Int
  ny : Int
  dirs : Array[Array[Int]] // 流向数组[ny][nx], 值0-8
} derive(Debug, ToJson, FromJson)

///|
/// 汇流累积矩阵
pub(all) struct FlowAccumulation {
  nx : Int
  ny : Int
  accum : Array[Array[Int]] // 汇流累积数[ny][nx]
} derive(Debug, ToJson, FromJson)

///|
/// D8方向的行列偏移量
/// dirs 1-8 对应 (di, dj)
let d8_offsets : Array[(Int, Int)] = [
  (0, 0), // 0: 无流向
  (0, 1), // 1: 东
  (-1, 1), // 2: 东北
  (-1, 0), // 3: 北
  (-1, -1), // 4: 西北
  (0, -1), // 5: 西
  (1, -1), // 6: 西南
  (1, 0), // 7: 南
  (1, 1), // 8: 东南
]

///|
/// D8方向对应的距离权重（对角线为√2）
let d8_distances : Array[Double] = [
  0.0, // 0
  1.0, // 1: 东
  @math.pow(2.0, 0.5), // 2: 东北
  1.0, // 3: 北
  @math.pow(2.0, 0.5), // 4: 西北
  1.0, // 5: 西
  @math.pow(2.0, 0.5), // 6: 西南
  1.0, // 7: 南
  @math.pow(2.0, 0.5), // 8: 东南
]

///|
/// 计算D8流向
///
/// 对每个单元，找出8邻域中高程最低（最大落差）的方向
/// P3-4：平坦区域（无落差）方向设为0，后续汇流累积中作为洼地处理
pub fn compute_flow_direction(dem : DEMGrid) -> FlowDirection {
  let dirs : Array[Array[Int]] = []
  for _ in 0..<dem.ny {
    let row : Array[Int] = []
    for _ in 0..<dem.nx {
      row.push(0)
    }
    dirs.push(row)
  }
  for i in 0..<dem.ny {
    for j in 0..<dem.nx {
      if !dem.has_data(i, j) {
        dirs[i][j] = 0
        continue
      }
      let center = dem.get_elevation(i, j)
      let mut max_drop = 0.0
      let mut best_dir = 0
      for d in 1..<9 {
        let (di, dj) = d8_offsets[d]
        let ni = i + di
        let nj = j + dj
        let neighbor = dem.get_elevation(ni, nj)
        if !dem.has_data(ni, nj) {
          continue
        }
        let drop = (center - neighbor) / d8_distances[d]
        if drop > max_drop {
          max_drop = drop
          best_dir = d
        }
      }
      dirs[i][j] = best_dir
    }
  }
  { nx: dem.nx, ny: dem.ny, dirs, }
}

///|
/// 计算汇流累积
///
/// 每个单元的汇流累积 = 直接流入它的单元数 + 上游递归累积
pub fn compute_flow_accumulation(fd : FlowDirection) -> FlowAccumulation {
  let accum : Array[Array[Int]] = []
  for _ in 0..<fd.ny {
    let row : Array[Int] = []
    for _ in 0..<fd.nx {
      row.push(0)
    }
    accum.push(row)
  }
  // 统计每个单元被多少单元流入
  // 反向计数：对每个单元，沿流向找到下游，下游累积+1
  // 使用迭代方式避免递归栈溢出
  // 先计算每个单元的入流数（有多少上游单元流入它）
  let in_count : Array[Array[Int]] = []
  for _ in 0..<fd.ny {
    let row : Array[Int] = []
    for _ in 0..<fd.nx {
      row.push(0)
    }
    in_count.push(row)
  }
  for i in 0..<fd.ny {
    for j in 0..<fd.nx {
      let d = fd.dirs[i][j]
      if d > 0 {
        let (di, dj) = d8_offsets[d]
        let ni = i + di
        let nj = j + dj
        if ni >= 0 && ni < fd.ny && nj >= 0 && nj < fd.nx {
          in_count[ni][nj] = in_count[ni][nj] + 1
        }
      }
    }
  }
  // 拓扑排序：从入流数为0的单元开始
  let queue : Array[(Int, Int)] = []
  for i in 0..<fd.ny {
    for j in 0..<fd.nx {
      if in_count[i][j] == 0 {
        queue.push((i, j))
        accum[i][j] = 1
      }
    }
  }
  let mut head = 0
  while head < queue.length() {
    let (i, j) = queue[head]
    head = head + 1
    let d = fd.dirs[i][j]
    if d > 0 {
      let (di, dj) = d8_offsets[d]
      let ni = i + di
      let nj = j + dj
      if ni >= 0 && ni < fd.ny && nj >= 0 && nj < fd.nx {
        accum[ni][nj] = accum[ni][nj] + accum[i][j]
        in_count[ni][nj] = in_count[ni][nj] - 1
        if in_count[ni][nj] == 0 {
          accum[ni][nj] = accum[ni][nj] + 1
          queue.push((ni, nj))
        }
      }
    }
  }
  // P2-5修复：处理洼地/循环中的未处理单元
  // 拓扑排序后仍有in_count>0的单元属于循环或洼地，补加自身贡献+1
  for i in 0..<fd.ny {
    for j in 0..<fd.nx {
      if in_count[i][j] > 0 {
        accum[i][j] = accum[i][j] + 1
      }
    }
  }
  { nx: fd.nx, ny: fd.ny, accum, }
}

///|
/// 流域delineation：从出口点追溯流域
///
/// 返回属于该流域的所有网格单元坐标
pub fn delineate_watershed(
  fd : FlowDirection,
  outlet_i~ : Int,
  outlet_j~ : Int,
) -> Array[(Int, Int)] {
  if outlet_i < 0 || outlet_i >= fd.ny || outlet_j < 0 || outlet_j >= fd.nx {
    return []
  }
  // 反向追溯：找到所有流向最终到达出口的单元
  let watershed : Array[(Int, Int)] = []
  // 标记数组
  let visited : Array[Array[Bool]] = []
  for _ in 0..<fd.ny {
    let row : Array[Bool] = []
    for _ in 0..<fd.nx {
      row.push(false)
    }
    visited.push(row)
  }
  // BFS从出口反向追溯
  let queue : Array[(Int, Int)] = [(outlet_i, outlet_j)]
  visited[outlet_i][outlet_j] = true
  let mut head = 0
  while head < queue.length() {
    let (i, j) = queue[head]
    head = head + 1
    watershed.push((i, j))
    // 检查8邻域是否有单元流向(i,j)
    for d in 1..<9 {
      let (di, dj) = d8_offsets[d]
      let ni = i + di
      let nj = j + dj
      if ni >= 0 && ni < fd.ny && nj >= 0 && nj < fd.nx && !visited[ni][nj] {
        // 检查(ni,nj)的流向是否指向(i,j)
        let nd = fd.dirs[ni][nj]
        if nd > 0 {
          let (ndi, ndj) = d8_offsets[nd]
          if ni + ndi == i && nj + ndj == j {
            visited[ni][nj] = true
            queue.push((ni, nj))
          }
        }
      }
    }
  }
  watershed
}

///|
/// 计算流域面积（单元数 × 单元面积）
pub fn watershed_area(dem : DEMGrid, cells : Array[(Int, Int)]) -> Double {
  let cell_area = dem.dx * dem.dy
  cells.length().to_double() * cell_area / 1000000.0 // km²
}

///|
/// 提取河网：汇流累积超过阈值的单元
///
/// threshold: 汇流累积阈值，超过则视为河道
pub fn extract_river_network(
  fa : FlowAccumulation,
  threshold~ : Int,
) -> Array[(Int, Int)] {
  let rivers : Array[(Int, Int)] = []
  for i in 0..<fa.ny {
    for j in 0..<fa.nx {
      if fa.accum[i][j] >= threshold {
        rivers.push((i, j))
      }
    }
  }
  rivers
}

///|
/// 计算DEM统计信息
/// P3-5：使用首个有效高程初始化min/max，避免999999.0哨兵值问题
pub fn dem_stats(dem : DEMGrid) -> (Double, Double, Double, Double) {
  let mut min_val = 0.0
  let mut max_val = 0.0
  let mut sum = 0.0
  let mut count = 0
  let mut initialized = false
  for i in 0..<dem.ny {
    for j in 0..<dem.nx {
      if dem.has_data(i, j) {
        let h = dem.elevations[i][j]
        if !initialized {
          min_val = h
          max_val = h
          initialized = true
        } else {
          if h < min_val {
            min_val = h
          }
          if h > max_val {
            max_val = h
          }
        }
        sum = sum + h
        count = count + 1
      }
    }
  }
  if count == 0 {
    return (0.0, 0.0, 0.0, 0.0)
  }
  let mean = sum / count.to_double()
  (min_val, max_val, mean, count.to_double())
}

///|
/// 生成合成DEM（带坡度的地形）
///
/// 用于测试和演示
pub fn synthetic_dem(
  nx~ : Int,
  ny~ : Int,
  dx? : Double = 100.0,
  dy? : Double = 100.0,
) -> DEMGrid {
  let dem = DEMGrid::uniform(nx~, ny~, dx~, dy~, h0=0.0)
  // 生成从西北向东南倾斜的地形 + 隆起
  for i in 0..<ny {
    for j in 0..<nx {
      let base = 1000.0 - i.to_double() * 5.0 - j.to_double() * 3.0
      let ridge = 50.0 *
        @math.sin(j.to_double() * 0.2) *
        @math.cos(i.to_double() * 0.15)
      dem.set_elevation(i, j, base + ridge)
    }
  }
  dem
}
