extern crate alloc;

use alloc::sync::Arc;
use axfs_ramfs::RamFileSystem;
use axfs_vfs::VfsOps;
use std::os::arceos::api::fs::{AxDisk, MyFileSystemIf};
use std::sync::Mutex;

static BOOT_DISK: Mutex<Option<Arc<Mutex<AxDisk>>>> = Mutex::new(None);

struct CompatFs;

pub fn boot_disk() -> Result<Arc<Mutex<AxDisk>>, String> {
    BOOT_DISK
        .lock()
        .unwrap()
        .as_ref()
        .cloned()
        .ok_or_else(|| "boot disk is not available".to_string())
}

#[crate_interface::impl_interface]
impl MyFileSystemIf for CompatFs {
    fn new_myfs(disk: AxDisk) -> Arc<dyn VfsOps> {
        *BOOT_DISK.lock().unwrap() = Some(Arc::new(Mutex::new(disk)));
        Arc::new(RamFileSystem::new())
    }
}
