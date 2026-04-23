use std::fs;

pub fn ensure_dir_all(path: &str) -> Result<(), String> {
    fs::create_dir_all(path).map_err(|err| format!("create dir {path}: {err}"))
}

pub fn write_file(path: &str, data: &[u8]) -> Result<(), String> {
    fs::write(path, data).map_err(|err| format!("write file {path}: {err}"))
}
