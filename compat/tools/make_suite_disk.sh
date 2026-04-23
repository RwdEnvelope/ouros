#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TESTSUITS_DIR="$ROOT/testsuits-for-oskernel"
ARCH="${1:-riscv64}"

case "$ARCH" in
    riscv64)
        build_target="build-rv"
        suite_root="$TESTSUITS_DIR/sdcard/riscv/glibc"
        image_path="$ROOT/disk-rv.img"
        ;;
    loongarch64)
        build_target="build-la"
        suite_root="$TESTSUITS_DIR/sdcard/loongarch/glibc"
        image_path="$ROOT/disk-la.img"
        ;;
    *)
        echo "unsupported arch: $ARCH" >&2
        exit 1
        ;;
esac

if [[ ! -d "$suite_root" || ! -f "$suite_root/basic_testcode.sh" ]]; then
    echo "building local suite artifacts: $build_target"
    make -C "$TESTSUITS_DIR" "$build_target"
fi

workdir="$(mktemp -d)"
cleanup() {
    if mountpoint -q "$workdir/mnt" 2>/dev/null; then
        sudo umount "$workdir/mnt"
    fi
    rm -rf "$workdir"
}
trap cleanup EXIT

mkdir -p "$workdir/mnt"
rm -f "$image_path"
truncate -s 1024M "$image_path"
mkfs.ext4 -F "$image_path" >/dev/null
sudo mount "$image_path" "$workdir/mnt"
sudo cp -rL "$suite_root"/. "$workdir/mnt"/
sudo umount "$workdir/mnt"

echo "generated $image_path"
