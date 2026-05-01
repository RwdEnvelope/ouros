#![cfg_attr(feature = "axstd", no_std)]
#![cfg_attr(feature = "axstd", no_main)]

#[macro_use]
#[cfg(feature = "axstd")]
extern crate axstd as std;

mod ext4_import;
mod fs;
mod myfs;

use ext4_import::ImportStats;
use std::process;
use std::string::{String, ToString};
use std::vec::Vec;

const IMPORT_ROOT: &str = "/ext4";
const TEST_SCRIPT_SUFFIX: &str = "_testcode.sh";
const EXPECTED_SUITES: &[&str] = &[
    "basic",
    "busybox",
    "lua",
    "libctest",
    "iozone",
    "unixbench",
    "iperf",
    "libcbench",
    "lmbench",
    "cyclictest",
    "ltp",
    "netperf",
];

#[derive(Clone, Debug, Eq, PartialEq)]
struct TestSuite {
    name: String,
    script_name: String,
}

#[cfg_attr(feature = "axstd", unsafe(no_mangle))]
fn main() {
    println!("==== oscomp-runner start ====");
    let exit_code = match bootstrap_ext4() {
        Ok(stats) => {
            println!(
                "ext4 import finished: dirs={}, files={}, symlinks={}",
                stats.directories, stats.files, stats.symlinks
            );
            match run_test_harness() {
                Ok(()) => 0,
                Err(err) => {
                    println!("test harness failed: {err}");
                    1
                }
            }
        }
        Err(err) => {
            println!("ext4 bootstrap failed: {err}");
            1
        }
    };
    println!("==== oscomp-runner end ====");
    process::exit(exit_code);
}

fn bootstrap_ext4() -> Result<ImportStats, String> {
    ext4_import::import_boot_disk(IMPORT_ROOT)
}

fn run_test_harness() -> Result<(), String> {
    let suites = discover_test_suites()?;
    println!(
        "discovered {} test scripts under {IMPORT_ROOT}",
        suites.len()
    );

    if suites.is_empty() {
        println!("warning: no {TEST_SCRIPT_SUFFIX} scripts were found");
        return Ok(());
    }

    for suite in &suites {
        run_suite(suite);
    }

    Ok(())
}

fn discover_test_suites() -> Result<Vec<TestSuite>, String> {
    let script_names = fs::list_matching_files(IMPORT_ROOT, TEST_SCRIPT_SUFFIX)?;
    let mut suites = Vec::new();

    for script_name in script_names {
        let Some(name) = script_name.strip_suffix(TEST_SCRIPT_SUFFIX) else {
            continue;
        };
        suites.push(TestSuite {
            name: normalize_suite_name(name),
            script_name,
        });
    }

    suites.sort_by(|left, right| {
        suite_rank(left.name.as_str())
            .cmp(&suite_rank(right.name.as_str()))
            .then_with(|| left.name.cmp(&right.name))
    });
    Ok(suites)
}

fn normalize_suite_name(raw: &str) -> String {
    match raw {
        "libc-test" | "libc_test" => "libctest".to_string(),
        "libc-bench" | "libc_bench" => "libcbench".to_string(),
        other => other.to_string(),
    }
}

fn suite_rank(name: &str) -> usize {
    EXPECTED_SUITES
        .iter()
        .position(|expected| *expected == name)
        .unwrap_or(EXPECTED_SUITES.len())
}

fn run_suite(suite: &TestSuite) {
    println!("#### OS COMP TEST GROUP START {} ####", suite.name);
    println!(
        "skip: minimal contest harness discovered {} but does not execute shell scripts yet",
        suite.script_name
    );
    println!("#### OS COMP TEST GROUP END {} ####", suite.name);
}
