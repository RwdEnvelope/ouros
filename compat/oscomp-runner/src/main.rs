#![cfg_attr(feature = "axstd", no_std)]
#![cfg_attr(feature = "axstd", no_main)]

#[macro_use]
#[cfg(feature = "axstd")]
extern crate axstd as std;

mod ext4_import;
mod fs;
mod myfs;

use ext4_import::ImportStats;

const IMPORT_ROOT: &str = "/ext4";

#[cfg_attr(feature = "axstd", unsafe(no_mangle))]
fn main() {
    println!("==== oscomp-runner start ====");
    match bootstrap_ext4() {
        Ok(stats) => {
            println!(
                "ext4 import finished: dirs={}, files={}, symlinks={}",
                stats.directories, stats.files, stats.symlinks
            );
            print_root_entries();
        }
        Err(err) => {
            println!("ext4 bootstrap failed: {err}");
        }
    }
    println!("==== oscomp-runner end ====");
}

fn bootstrap_ext4() -> Result<ImportStats, String> {
    ext4_import::import_boot_disk(IMPORT_ROOT)
}

fn print_root_entries() {
    println!("imported tree under {IMPORT_ROOT}:");
    match std::fs::read_dir(IMPORT_ROOT) {
        Ok(entries) => {
            for entry in entries {
                match entry {
                    Ok(entry) => println!("  {}", entry.file_name().to_string_lossy()),
                    Err(err) => println!("  <read dir entry error: {err}>"),
                }
            }
        }
        Err(err) => println!("  <unable to read {IMPORT_ROOT}: {err}>"),
    }
}
