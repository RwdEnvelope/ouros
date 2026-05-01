use std::fs;
use std::string::{String, ToString};
use std::vec::Vec;

pub fn ensure_dir_all(path: &str) -> Result<(), String> {
    fs::create_dir_all(path).map_err(|err| format!("create dir {path}: {err}"))
}

pub fn write_file(path: &str, data: &[u8]) -> Result<(), String> {
    fs::write(path, data).map_err(|err| format!("write file {path}: {err}"))
}

pub fn list_matching_files(dir: &str, suffix: &str) -> Result<Vec<String>, String> {
    let mut matches = Vec::new();
    let entries = fs::read_dir(dir).map_err(|err| format!("read dir {dir}: {err}"))?;

    for entry in entries {
        let entry = entry.map_err(|err| format!("iterate dir {dir}: {err}"))?;
        let file_type = entry.file_type();
        if !file_type.is_file() {
            continue;
        }

        let name = entry.file_name().to_string();
        if name.ends_with(suffix) {
            matches.push(name);
        }
    }

    matches.sort();
    Ok(matches)
}
