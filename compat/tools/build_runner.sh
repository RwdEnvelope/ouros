#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
ARCEOS_DIR="$ROOT/arceos"
APP_DIR="$ROOT/compat/oscomp-runner"
ARCH="${1:-riscv64}"
TARGET="${2:-build}"
FEATURES="alloc,fs,myfs,paging,irq,multitask"
OUT_CONFIG="$ROOT/.axconfig-${ARCH}.toml"

find_cargo() {
    local candidate
    for candidate in "${CARGO:-}" cargo /home/reden/.cargo/bin/cargo /usr/bin/cargo /usr/local/bin/cargo; do
        if [[ -n "$candidate" ]] && command -v "$candidate" >/dev/null 2>&1; then
            command -v "$candidate"
            return 0
        fi
        if [[ -n "$candidate" && -x "$candidate" ]]; then
            printf '%s\n' "$candidate"
            return 0
        fi
    done
    return 1
}

if [[ -f "$HOME/.cargo/env" ]]; then
    # Load rustup-managed tools like cargo and cargo-axplat.
    # shellcheck disable=SC1090
    source "$HOME/.cargo/env"
fi

CARGO_BIN="$(find_cargo)" || {
    echo "cargo is required to build oscomp-runner, but no cargo executable was found" >&2
    echo "install rustup/cargo or export CARGO=/path/to/cargo" >&2
    exit 127
}

case "$ARCH" in
    riscv64)
        PLAT_PACKAGE="axplat-riscv64-qemu-virt"
        ;;
    loongarch64)
        PLAT_PACKAGE="axplat-loongarch64-qemu-virt"
        ;;
    *)
        echo "unsupported arch: $ARCH" >&2
        exit 1
        ;;
esac

PLAT_CONFIG="$(cd "$ARCEOS_DIR" && "$CARGO_BIN" axplat info -C examples/helloworld -c "$PLAT_PACKAGE")"

make -C "$ARCEOS_DIR" \
    A="$APP_DIR" \
    ARCH="$ARCH" \
    BUS=mmio \
    OUT_CONFIG="$OUT_CONFIG" \
    PLAT_CONFIG="$PLAT_CONFIG" \
    FEATURES="$FEATURES" \
    "$TARGET"
