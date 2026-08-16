///|
/// 河网处理模块
///
/// 提供河网拓扑分析功能：
/// - Strahler河序计算
/// - 汇流顺序（拓扑排序）
/// - 上下游追溯
/// - 从DEM+汇流累积提取河网拓扑

///|
/// 计算Strahler河序
///
/// 规则：源头河段为1级；两条相同级河段汇合则+1级；不同级则取大值
pub fn RiverNetwork::compute_strahler_orders(self : RiverNetwork) -> Unit {
  let in_degree : Map[Int, Int] = Map([])
  for node_id, _ in self.nodes {
    in_degree[node_id] = self.upstream_reaches(node_id).length()
  }
  // 初始化所有河序为0
  for reach in self.reaches {
    reach.order = 0
  }
  // BFS拓扑排序
  let queue : Array[Int] = []
  for node_id, deg in in_degree {
    if deg == 0 {
      queue.push(node_id)
    }
  }
  let mut head = 0
  while head < queue.length() {
    let node_id = queue[head]
    head = head + 1
    // 处理从该节点出发的河段
    for reach in self.downstream_reaches(node_id) {
      // 获取上游河段的最高级
      let upstream = self.upstream_reaches(node_id)
      if upstream.length() == 0 {
        reach.order = 1
      } else {
        let mut max_order = 0
        let mut second_max = 0
        for up_reach in upstream {
          if up_reach.order > max_order {
            second_max = max_order
            max_order = up_reach.order
          } else if up_reach.order > second_max {
            second_max = up_reach.order
          }
        }
        reach.order = if max_order == second_max {
          max_order + 1
        } else {
          max_order
        }
      }
      // 更新下游节点的入度
      let down_deg = in_degree[reach.to_node] - 1
      in_degree[reach.to_node] = down_deg
      if down_deg == 0 {
        queue.push(reach.to_node)
      }
    }
  }
}

///|
/// 获取汇流顺序（拓扑排序）
///
/// 返回河段ID序列，保证上游河段在前
pub fn RiverNetwork::topological_order(self : RiverNetwork) -> Array[Int] {
  let in_degree : Map[Int, Int] = Map([])
  for node_id, _ in self.nodes {
    in_degree[node_id] = self.upstream_reaches(node_id).length()
  }
  let result : Array[Int] = []
  let queue : Array[Int] = []
  for node_id, deg in in_degree {
    if deg == 0 {
      queue.push(node_id)
    }
  }
  let mut head = 0
  while head < queue.length() {
    let node_id = queue[head]
    head = head + 1
    for reach in self.downstream_reaches(node_id) {
      result.push(reach.id)
      let down_deg = in_degree[reach.to_node] - 1
      in_degree[reach.to_node] = down_deg
      if down_deg == 0 {
        queue.push(reach.to_node)
      }
    }
  }
  result
}

///|
/// 从节点追溯到源头
pub fn RiverNetwork::trace_to_sources(
  self : RiverNetwork,
  node_id : Int,
) -> Array[Int] {
  let sources : Array[Int] = []
  let visited : Set[Int] = Set([])
  let stack : Array[Int] = [node_id]
  while stack.length() > 0 {
    let current = stack[stack.length() - 1]
    ignore(stack.pop())
    if visited.contains(current) {
      continue
    }
    visited.add(current)
    let upstream = self.upstream_reaches(current)
    if upstream.length() == 0 {
      sources.push(current)
    } else {
      for reach in upstream {
        if !visited.contains(reach.from_node) {
          stack.push(reach.from_node)
        }
      }
    }
  }
  sources
}

///|
/// 从节点追溯到出口
pub fn RiverNetwork::trace_to_outlet(
  self : RiverNetwork,
  node_id : Int,
) -> Array[Int] {
  let path : Array[Int] = []
  let mut current = node_id
  let visited : Set[Int] = Set([])
  while !visited.contains(current) {
    visited.add(current)
    path.push(current)
    let downstream = self.downstream_reaches(current)
    if downstream.length() == 0 {
      return path
    }
    current = downstream[0].to_node
  }
  path
}

///|
/// 统计河网信息
pub fn RiverNetwork::stats(self : RiverNetwork) -> String {
  let mut source_count = 0
  let mut confluence_count = 0
  let mut max_order = 0
  for _, node in self.nodes {
    match node.node_type {
      Source => source_count = source_count + 1
      Confluence => confluence_count = confluence_count + 1
      _ => ()
    }
  }
  for reach in self.reaches {
    if reach.order > max_order {
      max_order = reach.order
    }
  }
  "节点数=\{self.nodes.length()}, 河段数=\{self.reaches.length()}, 源头=\{source_count}, 汇流点=\{confluence_count}, 最高河序=\{max_order}"
}

///|
/// 从DEM和汇流累积提取河网拓扑
///
/// threshold: 汇流累积阈值
pub fn extract_network_from_dem(
  dem : DEMGrid,
  fa : FlowAccumulation,
  threshold~ : Int,
) -> RiverNetwork {
  let network = RiverNetwork::new()
  // 标记河道单元
  let is_channel : Array[Array[Bool]] = []
  for i in 0..<fa.ny {
    let row : Array[Bool] = []
    for j in 0..<fa.nx {
      row.push(fa.accum[i][j] >= threshold)
    }
    is_channel.push(row)
  }
  // 为河道单元分配节点ID
  let node_ids : Array[Array[Int]] = []
  let mut next_id = 0
  for _ in 0..<fa.ny {
    let row : Array[Int] = []
    for _ in 0..<fa.nx {
      row.push(-1)
    }
    node_ids.push(row)
  }
  for i in 0..<fa.ny {
    for j in 0..<fa.nx {
      if is_channel[i][j] {
        node_ids[i][j] = next_id
        let x = dem.x0 + j.to_double() * dem.dx
        let y = dem.y0 - i.to_double() * dem.dy
        let node : RiverNode = {
          id: next_id,
          point: { x, y },
          elevation: dem.get_elevation(i, j),
          node_type: Intermediate,
        }
        network.add_node(node)
        next_id = next_id + 1
      }
    }
  }
  // 建立河段连接（沿流向）
  let mut reach_id = 0
  for i in 0..<fa.ny {
    for j in 0..<fa.nx {
      if node_ids[i][j] >= 0 {
        let d = compute_downstream_dir(fa, i, j)
        if d > 0 {
          let (di, dj) = d8_offsets[d]
          let ni = i + di
          let nj = j + dj
          if ni >= 0 &&
            ni < fa.ny &&
            nj >= 0 &&
            nj < fa.nx &&
            node_ids[ni][nj] >= 0 {
            let from_id = node_ids[i][j]
            let to_id = node_ids[ni][nj]
            let from_node = network.nodes[from_id]
            let to_node = network.nodes[to_id]
            let length = xy_distance(from_node.point, to_node.point)
            let slope = if length > 0.0 {
              (from_node.elevation - to_node.elevation) / length
            } else {
              0.0
            }
            let reach : RiverReach = {
              id: reach_id,
              from_node: from_id,
              to_node: to_id,
              length,
              slope,
              order: 0,
            }
            network.add_reach(reach)
            reach_id = reach_id + 1
          }
        }
      }
    }
  }
  // 标记源头和出口
  for node_id, _ in network.nodes {
    let upstream = network.upstream_reaches(node_id)
    let downstream = network.downstream_reaches(node_id)
    if upstream.length() == 0 && downstream.length() > 0 {
      network.nodes[node_id].node_type = Source
    } else if upstream.length() > 1 && downstream.length() > 0 {
      network.nodes[node_id].node_type = Confluence
    } else if downstream.length() == 0 && upstream.length() > 0 {
      network.nodes[node_id].node_type = Outlet
      network.outlet_id = node_id
    }
  }
  // 计算Strahler河序
  network.compute_strahler_orders()
  network
}

///|
/// 计算单元的下游方向（基于汇流累积，流向累积值更大的邻居）
fn compute_downstream_dir(fa : FlowAccumulation, i : Int, j : Int) -> Int {
  let mut best_dir = 0
  let mut max_accum = fa.accum[i][j]
  for d in 1..<9 {
    let (di, dj) = d8_offsets[d]
    let ni = i + di
    let nj = j + dj
    if ni >= 0 && ni < fa.ny && nj >= 0 && nj < fa.nx {
      if fa.accum[ni][nj] > max_accum {
        max_accum = fa.accum[ni][nj]
        best_dir = d
      }
    }
  }
  best_dir
}
