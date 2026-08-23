# moon_hydro 迭代计划 V0.9.1 — 全面审查修复

> 审查日期：2026-08-24 | 基于4路并行代码审查 | 17 P1 + 40 P2 + 50 P3

## P1 修复（17项 — 重要bug/崩溃/错误结果）

### shared/ 核心算法（5项）
| # | 文件:行 | 问题 | 修复 |
|---|---------|------|------|
| P1-1 | xaj_core.mbt:44 | em=0时除零 | em_safe用epsilon替代0.0 |
| P1-2 | xaj_core.mbt:168-174 | ex=-1时除零 | 加ex_safe守卫(同b_safe模式) |
| P1-3 | swe_core.mbt:135 | nx=1时数组越界 | nx<2提前返回 |
| P1-4 | coupling.mbt:232 | xaj_state未更新(状态不累积) | 改mut并更新 |
| P1-5 | calibration.mbt:85-88 | u1近1.0时NaN | Box-Muller用1.0-next_double() |

### ml/ gis/ flood/（4项）
| # | 文件:行 | 问题 | 修复 |
|---|---------|------|------|
| P1-6 | hybrid.mbt:170 | 全局搜索用错input数组(崩溃) | inputs→adjusted_inputs |
| P1-7 | risk_map.mbt:108 | 用动量当流速(风险分级错误) | 除以水深得流速 |
| P1-8 | hybrid.mbt:41 | lookback<=0崩溃 | 加守卫 |
| P1-9 | damage.mbt:187 | 无长度检查(崩溃) | 加bounds check |

### backend/ frontend/ persistence/（5项）
| # | 文件:行 | 问题 | 修复 |
|---|---------|------|------|
| P1-10 | cli.mbt:623 | UTF-8字节截断 | 用safe_preview |
| P1-11 | frontend/main.mbt:51,67 | UTF-8字节截断 | 加char-safe preview |
| P1-12 | file_io.mbt:44 | null字节注入 | 拒绝含\x00路径 |
| P1-13 | fileio.c:37,56 | fseek返回未检查 | 检查返回值 |
| P1-14 | file_io.mbt:88 | file_size<0静默返回空 | 加错误检查 |

### config/CI/docs（3项）
| # | 文件:行 | 问题 | 修复 |
|---|---------|------|------|
| P1-15 | release.yml:94 | 不存在的action | download-artifacts→download-artifact |
| P1-16 | cli.mbt:522,wasm_slim_model.mbt:98,106 | 3个编译警告 | 移除unused raise/variable |
| P1-17 | matrix_test.mbt:74,85,93 | 弱断言(负值也通过) | 用.abs() |

## P2 修复（关键项）
- README.md:260 V0.8→V0.9
- roadmap.md 测试数一致性
- gis/types_test.mbt 弱断言→.abs()
- fileio.c:26 fsync返回检查
- frontend/main.mbt:31 slim run用实际params
- update_logic.mbt:65 SimulationFailed清除has_result
- 文档版本/测试数同步

## 验证
- moon check: 0错误 0警告
- moon test --target native: 全通过
- moon test --target wasm-gc: 全通过
