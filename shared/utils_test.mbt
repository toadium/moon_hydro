///|
/// 工具函数测试
///
/// 测试评价指标NSE/KGE/PBIAS、单位线卷积、RMSE、R²

///|
test "nse 完美匹配=1" {
  let obs = [1.0, 2.0, 3.0, 4.0, 5.0]
  let sim = [1.0, 2.0, 3.0, 4.0, 5.0]
  inspect(nse(obs, sim), content="1")
}

///|
test "nse 恒定观测=0" {
  let obs = [1.0, 2.0, 3.0, 4.0, 5.0]
  let sim = [3.0, 3.0, 3.0, 3.0, 3.0] // 观测均值
  inspect(nse(obs, sim), content="0")
}

///|
test "nse 空数组=0" {
  let obs : Array[Double] = []
  let sim : Array[Double] = []
  inspect(nse(obs, sim), content="0")
}

///|
test "nse 长度不匹配=0" {
  let obs = [1.0, 2.0, 3.0]
  let sim = [1.0, 2.0]
  inspect(nse(obs, sim), content="0")
}

///|
test "kge 完美匹配≈1" {
  let obs = [1.0, 2.0, 3.0, 4.0, 5.0]
  let sim = [1.0, 2.0, 3.0, 4.0, 5.0]
  let result = kge(obs, sim)
  // 浮点精度容差比较
  assert_true(result.is_close(1.0))
}

///|
test "pbias 无偏差=0" {
  let obs = [1.0, 2.0, 3.0, 4.0, 5.0]
  let sim = [1.0, 2.0, 3.0, 4.0, 5.0]
  inspect(pbias(obs, sim), content="0")
}

///|
test "pbias 高估=正值" {
  let obs = [10.0, 20.0, 30.0]
  let sim = [15.0, 25.0, 35.0]
  let result = pbias(obs, sim)
  assert_true(result > 0.0)
}

///|
test "pbias 低估=负值" {
  let obs = [10.0, 20.0, 30.0]
  let sim = [5.0, 15.0, 25.0]
  let result = pbias(obs, sim)
  assert_true(result < 0.0)
}

///|
test "unit_hydrograph_convolution 基本卷积" {
  let uh = [0.5, 0.3, 0.2] // 单位线
  let p = [10.0, 20.0] // 净雨
  let q = unit_hydrograph_convolution(uh, p)
  // Q(0) = UH(0)*P(0) = 0.5*10 = 5
  // Q(1) = UH(0)*P(1) + UH(1)*P(0) = 0.5*20 + 0.3*10 = 13
  // Q(2) = UH(0)*P(2) + UH(1)*P(1) + UH(2)*P(0) = 0 + 0.3*20 + 0.2*10 = 8
  // Q(3) = UH(1)*P(2) + UH(2)*P(1) = 0 + 0.2*20 = 4
  debug_inspect(q, content="[5, 13, 8, 4]")
}

///|
test "unit_hydrograph_convolution 空数组" {
  let uh : Array[Double] = []
  let p : Array[Double] = [1.0, 2.0]
  let q = unit_hydrograph_convolution(uh, p)
  inspect(q.length(), content="0")
}

///|
test "rmse 完美匹配=0" {
  let obs = [1.0, 2.0, 3.0]
  let sim = [1.0, 2.0, 3.0]
  inspect(rmse(obs, sim), content="0")
}

///|
test "rmse 基本计算" {
  let obs = [1.0, 2.0, 3.0]
  let sim = [2.0, 3.0, 4.0]
  // 每个差1，平方和=3，均值=1，sqrt=1
  inspect(rmse(obs, sim), content="1")
}

///|
test "r_squared 完美线性=1" {
  let obs = [1.0, 2.0, 3.0, 4.0, 5.0]
  let sim = [2.0, 4.0, 6.0, 8.0, 10.0] // y=2x
  inspect(r_squared(obs, sim), content="1")
}
