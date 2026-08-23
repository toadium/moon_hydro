///|
/// 矩阵与向量运算模块
///
/// 提供LSTM所需的矩阵/向量基础运算。
/// 矩阵用 Array[Array[Double]] 表示（行主序），向量用 Array[Double] 表示。

///|
/// 构造零向量
pub fn vec_zeros(n : Int) -> Array[Double] {
  let v : Array[Double] = []
  for _ in 0..<n {
    v.push(0.0)
  }
  v
}

///|
/// 构造零矩阵
pub fn mat_zeros(rows : Int, cols : Int) -> Array[Array[Double]] {
  let m : Array[Array[Double]] = []
  for _ in 0..<rows {
    m.push(vec_zeros(cols))
  }
  m
}

///|
/// 向量加法（维度安全：取较短向量长度避免越界）
pub fn vec_add(a : Array[Double], b : Array[Double]) -> Array[Double] {
  if a.length() != b.length() {
    abort("vec_add: dimension mismatch")
  }
  let n = if a.length() < b.length() { a.length() } else { b.length() }
  let result = vec_zeros(n)
  for i in 0..<n {
    result[i] = a[i] + b[i]
  }
  result
}

///|
/// 向量逐元素乘法（维度安全：取较短向量长度避免越界）
pub fn vec_mul(a : Array[Double], b : Array[Double]) -> Array[Double] {
  if a.length() != b.length() {
    abort("vec_mul: dimension mismatch")
  }
  let n = if a.length() < b.length() { a.length() } else { b.length() }
  let result = vec_zeros(n)
  for i in 0..<n {
    result[i] = a[i] * b[i]
  }
  result
}

///|
/// 向量逐元素加标量
pub fn vec_add_scalar(a : Array[Double], s : Double) -> Array[Double] {
  let n = a.length()
  let result = vec_zeros(n)
  for i in 0..<n {
    result[i] = a[i] + s
  }
  result
}

///|
/// 向量拼接
pub fn vec_concat(a : Array[Double], b : Array[Double]) -> Array[Double] {
  let result : Array[Double] = []
  for v in a {
    result.push(v)
  }
  for v in b {
    result.push(v)
  }
  result
}

///|
/// 矩阵乘向量: M * v（维度安全：取min(row_len, v_len)避免越界）
pub fn mat_vec_mul(
  m : Array[Array[Double]],
  v : Array[Double],
) -> Array[Double] {
  let rows = m.length()
  let result = vec_zeros(rows)
  let v_len = v.length()
  for i in 0..<rows {
    let mut sum = 0.0
    let row = m[i]
    if row.length() != v_len {
      abort("mat_vec_mul: row length != vector length")
    }
    let cols = if row.length() < v_len { row.length() } else { v_len }
    for j in 0..<cols {
      sum = sum + row[j] * v[j]
    }
    result[i] = sum
  }
  result
}

///|
/// 矩阵转置（处理非均匀行长度：使用每行实际长度）
pub fn mat_transpose(m : Array[Array[Double]]) -> Array[Array[Double]] {
  let rows = m.length()
  if rows == 0 {
    return []
  }
  // 找出最大列数以处理非均匀行
  let mut max_cols = 0
  for row in m {
    if row.length() > max_cols {
      max_cols = row.length()
    }
  }
  let result = mat_zeros(max_cols, rows)
  for i in 0..<rows {
    let row_len = m[i].length()
    for j in 0..<row_len {
      result[j][i] = m[i][j]
    }
  }
  result
}

///|
/// Sigmoid激活函数（数值稳定版）
///
/// 对大正数x避免exp(-x)下溢，对大负数x避免exp(-x)上溢
pub fn sigmoid(x : Double) -> Double {
  if x >= 0.0 {
    // 正数: 1/(1+exp(-x)), exp(-x)∈(0,1], 无溢出风险
    1.0 / (1.0 + @math.exp(-x))
  } else {
    // 负数: exp(x)/(1+exp(x)), exp(x)∈(0,1], 无溢出风险
    let ex = @math.exp(x)
    ex / (1.0 + ex)
  }
}

///|
/// Tanh激活函数
pub fn tanh_fn(x : Double) -> Double {
  @math.tanh(x)
}

///|
/// 向量逐元素sigmoid
pub fn vec_sigmoid(v : Array[Double]) -> Array[Double] {
  let n = v.length()
  let result = vec_zeros(n)
  for i in 0..<n {
    result[i] = sigmoid(v[i])
  }
  result
}

///|
/// 向量逐元素tanh
pub fn vec_tanh(v : Array[Double]) -> Array[Double] {
  let n = v.length()
  let result = vec_zeros(n)
  for i in 0..<n {
    result[i] = tanh_fn(v[i])
  }
  result
}

///|
/// 向量点积（维度安全：取较短向量长度避免越界）
pub fn vec_dot(a : Array[Double], b : Array[Double]) -> Double {
  if a.length() != b.length() {
    abort("vec_dot: dimension mismatch")
  }
  let n = if a.length() < b.length() { a.length() } else { b.length() }
  let mut sum = 0.0
  for i in 0..<n {
    sum = sum + a[i] * b[i]
  }
  sum
}

///|
/// 向量L2范数（P3-1：使用sqrt替代pow提升精度和性能）
pub fn vec_norm(a : Array[Double]) -> Double {
  @math.pow(vec_dot(a, a), 0.5)
}

///|
/// 向量均值
pub fn vec_mean(a : Array[Double]) -> Double {
  let n = a.length()
  if n == 0 {
    return 0.0
  }
  let mut sum = 0.0
  for v in a {
    sum = sum + v
  }
  sum / n.to_double()
}

///|
/// 向量标准差（P3-2：使用样本标准差n-1而非总体标准差n）
pub fn vec_std(a : Array[Double]) -> Double {
  let n = a.length()
  if n <= 1 {
    return 0.0
  }
  let mean = vec_mean(a)
  let mut variance = 0.0
  for v in a {
    let diff = v - mean
    variance = variance + diff * diff
  }
  @math.pow(variance / (n - 1).to_double(), 0.5)
}

///|
/// 向量归一化（Z-score）
pub fn vec_normalize(a : Array[Double]) -> (Array[Double], Double, Double) {
  let mean = vec_mean(a)
  let std = vec_std(a)
  let n = a.length()
  let result = vec_zeros(n)
  for i in 0..<n {
    result[i] = if std > 0.0 { (a[i] - mean) / std } else { 0.0 }
  }
  (result, mean, std)
}

///|
/// 向量反归一化
pub fn vec_denormalize(
  a : Array[Double],
  mean : Double,
  std : Double,
) -> Array[Double] {
  let n = a.length()
  let result = vec_zeros(n)
  for i in 0..<n {
    result[i] = a[i] * std + mean
  }
  result
}

///|
/// 矩阵展平为向量（行主序）
pub fn mat_flatten(m : Array[Array[Double]]) -> Array[Double] {
  let result : Array[Double] = []
  for row in m {
    for v in row {
      result.push(v)
    }
  }
  result
}

///|
/// 向量重塑为矩阵（行主序）
pub fn vec_reshape(
  v : Array[Double],
  rows : Int,
  cols : Int,
) -> Array[Array[Double]] {
  let m = mat_zeros(rows, cols)
  let mut idx = 0
  for i in 0..<rows {
    for j in 0..<cols {
      if idx < v.length() {
        m[i][j] = v[idx]
        idx = idx + 1
      }
    }
  }
  m
}

///|
/// 随机初始化矩阵（Xavier初始化）
pub fn mat_random(
  rows : Int,
  cols : Int,
  rng : @splitmix.RandomState,
) -> Array[Array[Double]] {
  let m = mat_zeros(rows, cols)
  let scale = @math.pow(6.0 / (rows + cols).to_double(), 0.5)
  for i in 0..<rows {
    for j in 0..<cols {
      let r = rng.next_double() * 2.0 - 1.0
      m[i][j] = r * scale
    }
  }
  m
}

///|
/// 随机初始化向量
pub fn vec_random(n : Int, rng : @splitmix.RandomState) -> Array[Double] {
  let v = vec_zeros(n)
  for i in 0..<n {
    v[i] = (rng.next_double() * 2.0 - 1.0) * 0.1
  }
  v
}
