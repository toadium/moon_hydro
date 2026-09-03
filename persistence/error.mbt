///|
/// 持久化层错误类型（全后端可见）
///
/// FileError 原先定义在 file_io.mbt（native-only），
/// 但 store.mbt 的 StoreError 需要在所有后端引用它，
/// 因此提取到此文件使 wasm-gc/js 后端也能编译。

///|
/// 文件操作错误
pub(all) suberror FileError {
  FileNotFound(String)
  WriteFailed(String)
  ReadFailed(String)
  DeleteFailed(String)
  InvalidPath(String)
} derive(Debug, ToJson, FromJson)
