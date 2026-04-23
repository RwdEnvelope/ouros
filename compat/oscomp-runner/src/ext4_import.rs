use crate::fs;
use crate::myfs;
use ext4_view::{Ext4, Ext4Read};
use std::boxed::Box;
use std::error::Error;
use std::fmt;
use std::string::{String, ToString};
use std::sync::{Arc, Mutex};

#[derive(Default, Debug, Clone, Copy)]
pub struct ImportStats {
    pub directories: usize,
    pub files: usize,
    pub symlinks: usize,
}

#[derive(Debug)]
struct DiskReadError(String);

impl fmt::Display for DiskReadError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        f.write_str(&self.0)
    }
}

impl Error for DiskReadError {}

struct DiskReader {
    disk: Arc<Mutex<std::os::arceos::api::fs::AxDisk>>,
}

impl Ext4Read for DiskReader {
    fn read(
        &mut self,
        start_byte: u64,
        dst: &mut [u8],
    ) -> Result<(), Box<dyn Error + Send + Sync + 'static>> {
        let mut disk = self.disk.lock().unwrap();
        disk.set_position(start_byte);

        let mut filled = 0;
        while filled < dst.len() {
            let read = disk.read_one(&mut dst[filled..]).map_err(|err| {
                Box::new(DiskReadError(format!(
                    "read disk at byte {start_byte}: {err:?}"
                ))) as Box<dyn Error + Send + Sync + 'static>
            })?;
            if read == 0 {
                return Err(Box::new(DiskReadError(format!(
                    "unexpected end of disk while reading at byte {}",
                    start_byte + filled as u64
                ))));
            }
            filled += read;
        }

        Ok(())
    }
}

pub fn import_boot_disk(dest_root: &str) -> Result<ImportStats, String> {
    let reader = DiskReader {
        disk: myfs::boot_disk()?,
    };
    let fs = Ext4::load(Box::new(reader)).map_err(|err| format!("load ext4: {err}"))?;

    fs::ensure_dir_all(dest_root)?;

    let mut stats = ImportStats::default();
    import_dir(&fs, "/", dest_root, &mut stats)?;
    Ok(stats)
}

fn import_dir(
    ext4: &Ext4,
    src_dir: &str,
    dest_dir: &str,
    stats: &mut ImportStats,
) -> Result<(), String> {
    stats.directories += 1;
    for entry in ext4
        .read_dir(src_dir)
        .map_err(|err| format!("read ext4 dir {src_dir}: {err}"))?
    {
        let entry = entry.map_err(|err| format!("iterate ext4 dir {src_dir}: {err}"))?;
        let path = format!("{}", entry.path().display());
        let meta = entry
            .metadata()
            .map_err(|err| format!("metadata for {path}: {err}"))?;
        let name = format!("{}", entry.file_name().display());
        let target = join_path(dest_dir, &name);

        if meta.is_dir() {
            fs::ensure_dir_all(&target)?;
            import_dir(ext4, &path, &target, stats)?;
        } else if meta.is_symlink() {
            let link = ext4
                .read_link(path.as_str())
                .map_err(|err| format!("read symlink {path}: {err}"))?;
            let link_target = format!("{}", link.display());
            // RamFS in the current runner path does not expose a symlink creation
            // API, so preserve the link target in a sidecar file for now.
            fs::write_file(&format!("{target}.symlink"), link_target.as_bytes())?;
            stats.symlinks += 1;
        } else if meta.file_type().is_regular_file() {
            let data = ext4
                .read(path.as_str())
                .map_err(|err| format!("read file {path}: {err}"))?;
            fs::write_file(&target, &data)?;
            stats.files += 1;
        }
    }

    Ok(())
}

fn join_path(dir: &str, name: &str) -> String {
    if dir == "/" {
        format!("/{name}")
    } else {
        format!("{dir}/{name}")
    }
}
