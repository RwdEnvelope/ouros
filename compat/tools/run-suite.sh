#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TESTSUITS_DIR="$ROOT/testsuits-for-oskernel"
SUITE_RAW="${1:-all}"
ARCH_RAW="${2:-${ARCH:-riscv64}}"

SUPPORTED_SUITES=(
    basic
    busybox
    lua
    libctest
    iozone
    unixbench
    iperf
    libcbench
    lmbench
    cyclictest
    ltp
    netperf
)

normalize_arch() {
    case "$1" in
        riscv64|riscv) echo "riscv64" ;;
        loongarch64|loongarch|la64) echo "loongarch64" ;;
        *)
            echo "unsupported arch: $1" >&2
            exit 1
            ;;
    esac
}

normalize_suite() {
    case "$1" in
        all) echo "all" ;;
        basic|busybox|lua|iozone|unixbench|iperf|libcbench|lmbench|cyclictest|ltp|netperf)
            echo "$1"
            ;;
        libctest|libc-test|libc_test)
            echo "libctest"
            ;;
        *)
            echo "unsupported suite: $1" >&2
            echo "supported suites: ${SUPPORTED_SUITES[*]}" >&2
            exit 1
            ;;
    esac
}

ARCH="$(normalize_arch "$ARCH_RAW")"
SUITE="$(normalize_suite "$SUITE_RAW")"

get_arch_prefix() {
    case "$ARCH" in
        riscv64) echo "riscv" ;;
        loongarch64) echo "loongarch" ;;
    esac
}

get_arch_build_target() {
    case "$ARCH" in
        riscv64) echo "build-rv" ;;
        loongarch64) echo "build-la" ;;
    esac
}

get_glibc_prefix() {
    case "$ARCH" in
        riscv64) echo "riscv64-linux-gnu-" ;;
        loongarch64) echo "loongarch64-linux-gnu-" ;;
    esac
}

get_makefile_sub_target() {
    case "$1" in
        libctest) echo "libc-test" ;;
        lmbench) echo "lmbench_src" ;;
        *) echo "$1" ;;
    esac
}

copy_busybox_suite_assets() {
    local suite_root="$1"
    cp "$TESTSUITS_DIR/scripts/busybox/busybox_testcode.sh" "$suite_root/"
    cp "$TESTSUITS_DIR/scripts/busybox/busybox_cmd.txt" "$suite_root/"
}

get_arch_runner() {
    case "$ARCH" in
        riscv64) echo "qemu-riscv64" ;;
        loongarch64) echo "qemu-loongarch64" ;;
    esac
}

get_arch_ldso_name() {
    case "$ARCH" in
        riscv64) echo "ld-linux-riscv64-lp64d.so.1" ;;
        loongarch64) echo "ld-linux-loongarch-lp64d.so.1" ;;
    esac
}

get_host_sysroot() {
    case "$ARCH" in
        riscv64)
            for candidate in /usr/riscv64-linux-gnu /usr/local/riscv64-linux-gnu; do
                if [[ -d "$candidate/lib" ]]; then
                    echo "$candidate"
                    return 0
                fi
            done
            ;;
        loongarch64)
            for candidate in /usr/loongarch64-linux-gnu /usr/local/loongarch64-linux-gnu /opt/gcc-13.2.0-loongarch64-linux-gnu/sysroot/usr; do
                if [[ -d "$candidate/lib64" || -d "$candidate/lib" ]]; then
                    echo "$candidate"
                    return 0
                fi
            done
            ;;
    esac
    return 1
}

get_suite_root() {
    echo "$TESTSUITS_DIR/sdcard/$(get_arch_prefix)/glibc"
}

suite_entry_exists() {
    local suite_root="$1"
    local suite_name="$2"
    [[ -f "$suite_root/${suite_name}_testcode.sh" ]]
}

build_arch_root_local() {
    local requested_suite="$1"
    local suite_root
    local prefix
    local target

    suite_root="$(get_suite_root)"
    prefix="$(get_glibc_prefix)"

    mkdir -p "$suite_root"
    mkdir -p "$suite_root/lib"

    if [[ "$requested_suite" == "basic" ]]; then
        rm -rf "$TESTSUITS_DIR/basic/user/build/$ARCH/mnt"
    fi
    if [[ "$requested_suite" == "busybox" ]]; then
        echo "preparing busybox suite assets locally ($ARCH host-busybox mode)"
        copy_busybox_suite_assets "$suite_root"
    else
        target="$(get_makefile_sub_target "$requested_suite")"
        echo "building suite artifact locally: $target ($ARCH glibc)"
        make -C "$TESTSUITS_DIR" -f Makefile.sub PREFIX="$prefix" DESTDIR="$suite_root" "$target"
    fi

    case "$ARCH" in
        riscv64)
            cp /usr/riscv64-linux-gnu/lib/libc.so.6 "$suite_root/lib/libc.so"
            cp /usr/riscv64-linux-gnu/lib/libc.so.6 "$suite_root/lib/"
            cp /usr/riscv64-linux-gnu/lib/libm.so.6 "$suite_root/lib/libm.so"
            cp /usr/riscv64-linux-gnu/lib/libm.so.6 "$suite_root/lib/"
            cp /usr/riscv64-linux-gnu/lib/ld-linux-riscv64-lp64d.so.1 "$suite_root/lib/"
            ;;
        loongarch64)
            cp /opt/gcc-13.2.0-loongarch64-linux-gnu/sysroot/usr/lib64/libc.so.6 "$suite_root/lib/"
            cp /opt/gcc-13.2.0-loongarch64-linux-gnu/sysroot/usr/lib64/libm.so.6 "$suite_root/lib/"
            cp /opt/gcc-13.2.0-loongarch64-linux-gnu/sysroot/usr/lib64/ld-linux-loongarch-lp64d.so.1 "$suite_root/lib/"
            ;;
    esac
}

normalize_shell_scripts() {
    local suite_root="$1"

    python3 - "$suite_root" <<'PY'
import pathlib
import stat
import sys

root = pathlib.Path(sys.argv[1])
for path in root.rglob("*.sh"):
    try:
        data = path.read_text()
    except UnicodeDecodeError:
        continue
    if data.startswith("#!/busybox sh\n"):
        data = "#!/usr/bin/env bash\n" + data.split("\n", 1)[1]
        path.write_text(data)
    mode = path.stat().st_mode
    path.chmod(mode | stat.S_IXUSR | stat.S_IXGRP | stat.S_IXOTH)
PY
}

wrap_elf_binaries() {
    local suite_root="$1"
    local runner
    local ldso
    local sysroot

    runner="$(get_arch_runner)"
    ldso="$(get_arch_ldso_name)"
    if [[ -f "$suite_root/lib/$ldso" ]]; then
        sysroot="$suite_root"
    else
        sysroot="$(get_host_sysroot)" || {
            echo "unable to find a usable sysroot for $ARCH" >&2
            exit 1
        }
    fi

    python3 - "$suite_root" "$runner" "$sysroot" <<'PY'
import os
import pathlib
import stat
import sys

root = pathlib.Path(sys.argv[1])
runner = sys.argv[2]
sysroot = sys.argv[3]

def should_skip(path: pathlib.Path) -> bool:
    rel = path.relative_to(root)
    if rel.parts and rel.parts[0] == "lib":
        return True
    name = path.name
    if name.endswith(".elfbin") or name.endswith(".sh"):
        return True
    if ".so" in name or name.startswith("ld-linux"):
        return True
    return False

def is_elf(path: pathlib.Path) -> bool:
    try:
        with path.open("rb") as f:
            return f.read(4) == b"\x7fELF"
    except OSError:
        return False

def write_wrapper(dst: pathlib.Path, target: pathlib.Path) -> None:
    content = (
        "#!/usr/bin/env bash\n"
        "set -euo pipefail\n"
        f'exec "{runner}" -L "{sysroot}" "{target}" "$@"\n'
    )
    dst.write_text(content)
    mode = dst.stat().st_mode
    dst.chmod(mode | stat.S_IXUSR | stat.S_IXGRP | stat.S_IXOTH)

for path in root.rglob("*"):
    if not path.is_file():
        continue
    if should_skip(path):
        continue

    backup = path.with_name(path.name + ".elfbin")
    if backup.exists():
        write_wrapper(path, backup)
        continue

    if not os.access(path, os.X_OK):
        continue
    if not is_elf(path):
        continue

    path.rename(backup)
    write_wrapper(path, backup)
PY
}

prepare_suite_root() {
    local suite_name="$1"
    local suite_root
    suite_root="$(get_suite_root)"
    if ! suite_entry_exists "$suite_root" "$suite_name"; then
        build_arch_root_local "$suite_name" || return 1
    fi
    normalize_shell_scripts "$suite_root" || return 1
    wrap_elf_binaries "$suite_root" || return 1

    if ! suite_entry_exists "$suite_root" "$suite_name"; then
        echo "suite artifacts still missing after preparation: $suite_name" >&2
        return 1
    fi
}

ensure_busybox_helper() {
    local suite_root="$1"
    local busybox_path="$suite_root/busybox"

    if [[ -x "$busybox_path" ]]; then
        return 0
    fi

    if command -v busybox >/dev/null 2>&1; then
        cat >"$busybox_path" <<'EOF'
#!/usr/bin/env bash
exec busybox "$@"
EOF
        chmod +x "$busybox_path"
        return 0
    fi

    echo "warning: ./busybox is missing and host busybox was not found" >&2
}

run_single_suite() {
    local suite_name="$1"
    local suite_root
    suite_root="$(get_suite_root)"
    if ! prepare_suite_root "$suite_name"; then
        echo "==== suite preparation failed: $suite_name (arch=$ARCH) ===="
        return 1
    fi
    ensure_busybox_helper "$suite_root"
    echo "==== running suite: $suite_name (arch=$ARCH) ===="
    (
        cd "$suite_root"
        "./${suite_name}_testcode.sh"
    )
}

run_all_suites() {
    local pass=0
    local fail=0
    local suite_name

    for suite_name in "${SUPPORTED_SUITES[@]}"; do
        if run_single_suite "$suite_name"; then
            pass=$((pass + 1))
        else
            fail=$((fail + 1))
        fi
    done

    echo "==== suite summary: total=$((pass + fail)) passed=$pass failed=$fail ===="
    [[ "$fail" -eq 0 ]]
}

if [[ "$SUITE" == "all" ]]; then
    run_all_suites
else
    run_single_suite "$SUITE"
fi
