# 审查进度跟踪

## 项目信息

- 项目：moon_hydro v0.9.0
- 项目根目录：/workspace/moon_hydro
- 审查范围：全量审查所有模块
- 开始时间：2026-08-23 14:52

## 审查轮次

## R1: 全量审查所有模块（5 个并行子审查） — 严重 12 / 一般 59 / 轻微 40 — 新安江算法缺陷+安全+数值稳定性等多维度问题 → review_v1a.md ~ review_v1e.md

### R1a: shared/ 核心算法 — 严重 2 / 一般 8 / 轻微 7
- [严重] 三水源划分公式错误，默认参数下壤中流/地下径流恒为零 (xaj_core.mbt:159)
- [严重] 蓄量重复计入净雨，水量平衡错误 (xaj_core.mbt:65,119)
- → review_v1a.md

### R1b: shared/ 率定评价时序 — 严重 1 / 一般 7 / 轻微 10
- [严重] DDS 扰动随机索引 Int::min 溢出导致负下标崩溃 (calibration.mbt:120)
- → review_v1b.md

### R1c: shared/ 基础设施 — 严重 5 / 一般 15 / 轻微 5
- [严重] Session TTL 时间单位不匹配，会话在约 86ms 后过期 (auth.mbt:241)
- [严重] benchmark/task_scheduler 时间单位标注错误（纳秒标记为毫秒）(benchmark.mbt:35-37)
- [严重] benchmark 计时因 UInt64→Double 提前转换丢失精度 (benchmark.mbt:35-37)
- [严重] bench 在 n_iters=0 时产生 NaN (benchmark.mbt:32-53)
- [严重] 用户删除后 register 产生 user_id 碰撞，覆盖现有用户 (auth.mbt:201)
- → review_v1c.md

### R1d: ml/ + gis/ + flood/ — 严重 2 / 一般 8 / 轻微 6
- [严重] train_residual_lstm 输入维度不匹配导致训练崩溃 (hybrid.mbt:132,150)
- [严重] Forest 水深-损失率曲线在 depth=1.0 处不连续 (damage.mbt:142-148)
- → review_v1d.md

### R1e: persistence/ + backend/ + frontend/ — 严重 2 / 一般 21 / 轻微 12
- [严重] C FFI 路径 Bytes 未保证 null 终止，fopen/remove 缓冲区过读风险 (fileio.c:20,32,75,84)
- [严重] read_file 静默吞掉读取错误，返回空字符串 (file_io.mbt:69-73)
- → review_v1e.md

### 汇总统计

| 严重程度 | 数量 |
|---------|------|
| 严重 | 12 |
| 一般 | 59 |
| 轻微 | 40 |
| **合计** | **111** |
