# 沐澜水文基础设施审查报告

> 审查人：infra-reviewer ｜ 审查时间：2026-08-22 ｜ 审查范围：persistence/ + CI/CD + 文档 + 项目配置
> MoonBit 工具链：0.1.20260819 ｜ 项目版本：V0.8.0 ｜ wasm-gc 测试：368 通过

---

## 一、模块概览

### 1.1 persistence/ 持久化存储层

| 文件 | 行数 | 职责 | 后端 |
|------|------|------|------|
| `store.mbt` | 205 | DataStore 内存 CRUD + JSON 序列化 | 全后端 |
| `file_io.mbt` | 117 | C FFI 文件 I/O 封装 | native 专用 |
| `fileio.c` | 40 | C 实现文件读写 | native 专用 |
| `store_test.mbt` | 217 | DataStore 内存操作与 JSON 序列化测试 | 全后端 |
| `file_io_test.mbt` | 132 | 文件 I/O 与持久化测试 | native 专用 |
| `moon.pkg` | 9 | 包配置（native-stub + target 限制） | — |
| `pkg.generated.mbti` | 91 | 接口声明文件 | — |

**架构评价**：persistence 层设计清晰，内存 DataStore（全后端）与 C FFI 文件 I/O（native 专用）分离合理。`moon.pkg` 中通过 `targets` 选项正确限制 `file_io.mbt` 和 `file_io_test.mbt` 仅在 native 后端编译。数据结构均派生 `ToJson, FromJson, Default`，序列化能力完备。

### 1.2 CI/CD 工作流

| 文件 | 触发条件 | 核心内容 |
|------|----------|----------|
| `ci.yml` | push/PR → main/master | 编译检查 + 四后端测试矩阵 + 格式检查 + 后端运行 |
| `pr-check.yml` | PR → main/master | 编译检查 + 格式检查 + wasm-gc 快速测试 |
| `release.yml` | tag `v*` | 四后端构建产物 + GitHub Release |

**架构评价**：三工作流分工合理。四后端测试矩阵覆盖完整，`fail-fast: false` 设计良好。使用 `actions/checkout@v5`、`actions/upload-artifact@v4` 等最新 Action 版本。

### 1.3 文档体系

| 文档 | 版本标注 | 状态 |
|------|----------|------|
| `README.md` | V0.8.0 | ✅ 较新 |
| `CHANGELOG.md` | 0.8.0 | ✅ 最新 |
| `roadmap.md` | V0.8 | ✅ 最新 |
| `CONTRIBUTING.md` | — | ✅ 通用 |
| `docs/API.md` | V0.8 | ✅ 较新 |
| `docs/01-项目申报书.md` | — | ⚠️ 早期版本 |
| `docs/02-技术文档.md` | V1.0 设计基线 | ❌ 过时 |
| `docs/04-README.md` | V0.1-dev | ❌ 严重过时 |
| `docs/用户手册.md` | V0.5 | ❌ 过时 |
| `docs/部署指南.md` | V0.5 | ❌ 过时 |
| `docs/review/` + `docs/verify/` | 2026-08-13 | ⚠️ 仅覆盖初始4文档 |

### 1.4 项目配置

| 文件 | 用途 | 状态 |
|------|------|------|
| `moon.mod` | 模块元信息 | ✅ 正确 |
| `.gitignore` | 忽略规则 | ⚠️ 不完整 |
| 8 × `moon.pkg` | 各包配置 | ✅ 合理 |
| 8 × `pkg.generated.mbti` | 接口声明 | ⚠️ 管理策略待定 |

---

## 二、问题清单

### P0 级问题（阻断性）

无。

### P1 级问题（严重）

**P1-1 | persistence | `fileio.c` L32 | C FFI 整数溢出导致缓冲区溢出**

`moonbit_make_bytes_raw((int32_t)size)` 将 `long size` 强转为 `int32_t`。当文件大于 2GB 时，`size` 超过 INT32_MAX，强转截断后分配的缓冲区远小于实际文件大小，随后 `fread(result, 1, (size_t)size, f)` 按原始 `size` 读取，造成**堆缓冲区溢出**。这是可利用的安全漏洞。

修复建议：在分配前检查 `size > INT32_MAX`，超限则返回空 bytes 或错误码。

**P1-2 | CI/CD | `release.yml` 全文 | Release 前无测试验证**

`release.yml` 由 `v*` tag 触发，仅执行 `moon build` 构建四后端产物并发布 GitHub Release，但**不运行任何测试**。一个存在失败测试的 tag 仍可成功发布。应在 `build` job 前添加测试步骤作为发布门禁。

修复建议：在 `build` job 中 `moon build` 之前添加 `moon test --target wasm-gc` 步骤，或新增 `test` job 作为 `build` 的前置依赖。

**P1-3 | 文档 | `README.md` L9 徽章 | 测试数量徽章不准确**

徽章显示 `tests-374 × 4 backends`，暗示 374 个测试在全部 4 个后端通过。实际 wasm-gc 后端仅 368 个测试通过（`file_io_test.mbt` 的 5 个测试为 native 专用，另有 1 个差异）。应改为 `tests-368+ (per backend)` 或分别标注各后端测试数。

**P1-4 | 文档 | `docs/04-README.md` 全文 | docs/04-README.md 严重过时**

该文档仍标注 `version-V0.1--dev`，描述的项目结构与实际严重不符——提及不存在的文件（`api_routes.mbt`、`db_sqlite.mbt`、`chart_render.mbt`），引用未使用的依赖（Proton/Rabbita/moonNum/sqlite3/async/Rui），声称 `MIT + Apache-2.0` 双协议（实际为 MIT），缺少 `persistence/`、`ml/`、`gis/`、`flood/` 等实际存在的目录。此文档与根 `README.md` 完全脱节，会严重误导新开发者。

修复建议：将 `docs/04-README.md` 替换为根 `README.md` 的副本，或直接删除并更新文档间引用。

### P2 级问题（中等）

**P2-1 | persistence | `fileio.c` L24-38 | 无文件大小上限检查**

`fseek/ftell` 获取文件大小后直接分配缓冲区，无大小上限校验。恶意或误操作传入超大文件路径可导致 OOM。建议添加 `MAX_FILE_SIZE` 保护（如 256MB）。

**P2-2 | persistence | `file_io.mbt` L53-55 | 空文件被误报为 FileNotFound**

`read_file` 通过 `content_bytes.length() == 0` 判断文件不存在，但 `hydro_read_file` 对空文件也返回空 bytes。读取一个存在的空文件会抛出 `FileNotFound` 错误，语义不正确。应通过 C FFI 单独提供 `file_exists` 原语（如 `access()`/`stat()`）。

**P2-3 | persistence | `file_io.mbt` L61-65 | file_exists 对空文件返回 false**

`file_exists` 内部调用 `hydro_read_file` 并检查 `length > 0`。空文件（存在但大小为 0）会返回 `false`，语义错误。与 P2-2 同源。

**P2-4 | persistence | `file_io_test.mbt` 全文 | 测试文件未清理**

测试创建 `test_hydro_basic.json`、`test_hydro_exists.json`、`test_hydro_store.json`、`test_hydro_scheme.json`、`test_hydro_param.json` 等文件到当前工作目录，但测试结束后不清理。这会污染工作目录，在 CI 中可能影响后续步骤。应在测试末尾删除临时文件。

**P2-5 | CI/CD | `ci.yml` 全文 | 无 MoonBit 工具链缓存**

每个 job 都通过 `curl` 重新安装 MoonBit 工具链，4 个 job 累积约 2min 额外开销。应使用 `actions/cache@v4` 缓存 `~/.moon` 目录。

**P2-6 | CI/CD | `release.yml` L30 | 打包步骤静默吞错**

`cp -r target/.../release/* dist/ 2>/dev/null || true` 中 `|| true` 会吞掉所有错误。若构建产物路径不存在，将生成空 tarball 并上传。应移除 `|| true` 或在 `cp` 后验证 `dist/` 非空。

**P2-7 | 文档 | `docs/02-技术文档.md` 全文 | 技术文档严重过时**

标注"V1.0 设计基线"但内容停留在 V0.4 时代。项目结构缺少 `persistence/`、`ml/`、`gis/`、`flood/` 目录；CLI 子命令列 15 个（实际 20 个）；测试数写"194个"（实际 368+）；开发计划 V0.5-V0.8 已完成但文档仍标为"待开发"；引用未使用的生态库作为当前依赖。

**P2-8 | 文档 | `docs/用户手册.md` 全文 | 用户手册过时**

标注"版本 V0.5"，CLI 命令表列 16 个（实际 20 个，缺少 `auth`、`ai_forecast`、`gis`、`flood`），测试数写"256个"（实际 368+），缺少 ml/gis/flood 模块使用说明。

**P2-9 | 文档 | `docs/部署指南.md` 全文 | 部署指南过时**

标注"版本 V0.5"，`moon.mod` 示例显示 `version = "0.5.0"`（实际 0.8.0），包结构表缺少 `ml`、`gis`、`flood` 三个包。

**P2-10 | 配置 | `.gitignore` 全文 | .gitignore 不完整**

缺少 `target/` 目录（`moon build` 产物）、`.moon/` 目录（MoonBit 安装目录）、测试输出文件（`test_hydro_*.json`）。这些文件可能被误提交。

**P2-11 | 文档 | `README.md` L8 徽章 | MoonBit 版本徽章过时**

徽章显示 `MoonBit-0.1.20260713`，实际安装版本为 `0.1.20260819`。CONTRIBUTING.md 中">= 0.1.20260713"作为最低版本要求合理，但 README 徽章应反映当前开发版本。

### P3 级问题（建议）

| 编号 | 模块 | 位置 | 描述 |
|------|------|------|------|
| P3-1 | persistence | `fileio.c` L14 | fwrite 后未检查 fclose 返回值，建议用 ferror(f) 综合判断 |
| P3-2 | persistence | `fileio.c` L10 | content_len 缺少负值防御，C FFI 层应做防御性检查 |
| P3-3 | persistence | `store.mbt` L78-86 | load_scheme/load_param_set 冗余模式匹配，等价于直接 .get(id) |
| P3-4 | persistence | `file_io.mbt` L61-65 | file_exists 实现低效，读取整个文件判断存在性，应改用 access()/stat() |
| P3-5 | persistence | `store.mbt` L132-138 | list_all_results 可简化为数组克隆 |
| P3-6 | persistence | `store.mbt` L203-205 | generate_id 无输入校验，不检查 prefix 空值或特殊字符 |
| P3-7 | persistence | `file_io_test.mbt` | 缺少边界测试：空文件、二进制内容、写入失败、大文件 |
| P3-8 | CI/CD | `ci.yml` | 无测试失败产物上传，可添加 if: failure() 步骤 |
| P3-9 | CI/CD | `ci.yml` | 无覆盖率报告，可添加 moon coverage analyze |
| P3-10 | CI/CD | `pr-check.yml` | PR 检查不含 native 编译检查，C FFI 问题不会被拦截 |
| P3-11 | CI/CD | `release.yml` | 无发布产物 SHA256 校验和 |
| P3-12 | 文档 | `docs/API.md` L1 vs L511 | 函数数量不一致：开头"150+"，结尾"230+" |
| P3-13 | 文档 | `CHANGELOG.md` L32 | V0.8 变更缺少非 native 测试数，与 V0.7 格式不一致 |
| P3-14 | 文档 | `docs/review/` + `docs/verify/` | 审查/验证报告过时，仅覆盖初始 4 文档 |
| P3-15 | 配置 | `moon.mod` L7 | 仓库 URL org(toadium) 与包名 org(walkzzz) 不一致，阻塞 mooncakes 发布 |
| P3-16 | 配置 | 全部 mbti 文件 | pkg.generated.mbti 管理策略未定，存在变陈旧风险 |

### Deprecation Warnings 检查

运行 `moon check` 输出 "Finished. moon: no work to do"，**未检测到 deprecation warnings**。任务中提到的 `to_json` 隐式提升警告已在 V0.5.0 修复（CHANGELOG 记录："MoonBit API适配：`@json.to_json(value)` → `value.to_json()`"）。当前代码中 `self.to_json().stringify()` 模式在 MoonBit 0.1.20260819 下无警告。

---

## 三、改进建议

### 3.1 优先修复（P1）

1. **fileio.c 安全加固**：在 `hydro_read_file` 中添加文件大小检查：
   ```c
   if (size > 0x7FFFFFFF) {  // INT32_MAX
       fclose(f);
       return moonbit_make_bytes(0, 0);
   }
   ```
   同时建议添加 `MAX_FILE_SIZE`（如 256MB）上限防止 OOM。

2. **release.yml 添加测试门禁**：在 `build` job 的 `moon build` 之前添加：
   ```yaml
   - name: 测试验证
     run: moon test --target wasm-gc
   ```

3. **README 徽章修正**：将测试徽章改为 `tests-368+-374 (per backend)` 或移除具体数字使用动态徽章。

4. **docs/04-README.md 处理**：用根 README.md 内容替换或删除此文件并更新引用。

### 3.2 中期改进（P2）

5. **persistence 空文件语义修复**：在 `fileio.c` 中新增 `hydro_file_exists` 函数使用 `access(path, F_OK)`，MoonBit 侧 `file_exists` 改为调用此原语。`read_file` 对空文件返回空字符串而非抛出 FileNotFound。

6. **测试文件清理**：在 `file_io_test.mbt` 每个测试末尾添加文件删除，或使用唯一临时文件名。

7. **CI 缓存优化**：在 ci.yml 和 pr-check.yml 中添加 MoonBit 工具链缓存：
   ```yaml
   - uses: actions/cache@v4
     with:
       path: ~/.moon
       key: moonbit-${{ runner.os }}
   ```

8. **文档同步更新**：系统性更新 `docs/02-技术文档.md`、`docs/用户手册.md`、`docs/部署指南.md` 至 V0.8 基线，补充 ml/gis/flood 模块描述，修正 CLI 命令数和测试数。

9. **.gitignore 补全**：添加 `target/`、`.moon/`、`test_hydro_*.json` 条件。

### 3.3 长期优化（P3）

10. **mbti 管理策略**：在 CI 中添加 `moon info` + `git diff --exit-code` 检查，确保 mbti 文件与代码同步；或将其加入 .gitignore 由 CI 自动生成。

11. **C FFI 防御性编程**：全面加固 fileio.c 的输入校验（负值、空指针、路径长度）。

12. **CI 覆盖率与产物**：添加覆盖率报告上传、测试失败产物保留、发布校验和生成。

---

## 四、亮点肯定

### 4.1 persistence 层设计亮点

- **后端隔离精准**：`moon.pkg` 通过 `targets` 选项将 C FFI 代码精确限制在 native 后端，`native-stub` 配置正确，全后端 DataStore 与 native 专用文件 I/O 分离干净利落。
- **序列化设计完备**：所有数据结构统一派生 `ToJson, FromJson, Default`，JSON 往返测试覆盖充分，`to_json_string`/`from_json_string` 接口简洁一致。
- **CRUD 接口完整**：DataStore 提供方案/结果/参数集的完整 CRUD 操作，`list_results` 支持按方案 ID 过滤，`stats` 提供统计摘要，API 设计符合直觉。
- **错误处理规范**：`FileError` 使用 `suberror` 定义三个明确变体，`raise` 语义清晰，测试中正确使用 `try...catch` 验证错误场景。

### 4.2 CI/CD 设计亮点

- **四后端测试矩阵**：`ci.yml` 使用 `matrix.target: [wasm-gc, wasm, js, native]` 完整覆盖四后端，`fail-fast: false` 确保一个后端失败不阻断其他后端结果展示。
- **PR 快速反馈**：`pr-check.yml` 仅运行 wasm-gc 快速测试，为 PR 提供快速反馈通道，与全量 CI 形成快慢互补。
- **Release 自动化**：`release.yml` 由 `v*` tag 自动触发，四后端并行构建，`softprops/action-gh-release@v2` 自动生成 Release Notes，流程成熟。
- **格式检查集成**：CI 中集成 `moon fmt` + `git diff --exit-code` 格式检查，确保代码风格一致性。
- **Action 版本最新**：全量使用 `actions/checkout@v5`、`actions/upload-artifact@v4`、`actions/download-artifacts@v4`，无弃用 Action 版本。

### 4.3 文档与配置亮点

- **CHANGELOG 规范**：遵循 Keep a Changelog 格式，版本记录详尽，每个版本的新增/变更/修复分类清晰，是项目文档的标杆。
- **roadmap 详尽**：开发路线图完整记录 V0.1-V0.8 交付内容，技术债务清单透明，里程碑统计清晰。
- **API.md 全面**：API 文档覆盖全部 16 个模块的公开函数，签名和说明完整，是 MoonBit 项目中少见的详尽 API 文档。
- **moon.pkg 配置合理**：各包依赖关系清晰——shared 无内部依赖、persistence 依赖 shared、backend 依赖全部模块、flood 依赖 shared+gis，层次分明无循环依赖。
- **CONTRIBUTING.md 实用**：包含 MoonBit 特定注意事项（科学计数法、Ref::new 废弃、derive(Show) 废弃等），对新贡献者友好。

### 4.4 Deprecation Warnings 治理

- **已清零**：`moon check` 无任何警告输出。V0.5.0 的 CHANGELOG 记录了 `@json.to_json(value)` → `value.to_json()` 的 API 适配，V0.7.0 记录"消除全部编译警告（0 warnings）"。项目在 deprecation 治理方面表现优秀。

---

## 五、问题统计

| 级别 | 数量 | 分布 |
|------|------|------|
| P0 | 0 | — |
| P1 | 4 | persistence(1) + CI/CD(1) + 文档(2) |
| P2 | 11 | persistence(4) + CI/CD(2) + 文档(4) + 配置(1) |
| P3 | 16 | persistence(7) + CI/CD(4) + 文档(3) + 配置(2) |
| **合计** | **31** | persistence(12) + CI/CD(7) + 文档(9) + 配置(3) |

**重点关注**：P1-1（C FFI 缓冲区溢出）是唯一安全漏洞，需优先修复。P1-2（Release 无测试门禁）是发布流程缺陷。P1-3/P1-4 为文档准确性问题。文档过时（P2-7/8/9）是最大系统性问题——3 份 docs/ 文档停留在 V0.4-V0.5 时代，与 V0.8 实际状态严重脱节。

---

*审查完成。报告路径：.team/jiuwen_team_sess_1a025ec5d81_1f2f8c/review-infra.md*
