#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
ARCH="${1:-riscv64}"
MEM="${MEM:-512M}"
SMP="${SMP:-1}"

case "$ARCH" in
    riscv64)
        kernel="$ROOT/kernel-rv"
        fs_img="${FS_IMG:-$ROOT/disk-rv.img}"
        aux_img="${AUX_IMG:-$ROOT/disk.img}"
        exec_cmd=(
            qemu-system-riscv64
            -machine virt
            -kernel "$kernel"
            -m "$MEM"
            -nographic
            -smp "$SMP"
            -bios default
            -drive "file=$fs_img,if=none,format=raw,id=x0"
            -device virtio-blk-device,drive=x0,bus=virtio-mmio-bus.0
            -no-reboot
            -device virtio-net-device,netdev=net
            -netdev user,id=net
            -rtc base=utc
        )
        if [[ -f "$aux_img" ]]; then
            exec_cmd+=(
                -drive "file=$aux_img,if=none,format=raw,id=x1"
                -device virtio-blk-device,drive=x1,bus=virtio-mmio-bus.1
            )
        fi
        ;;
    loongarch64)
        kernel="$ROOT/kernel-la"
        fs_img="${FS_IMG:-$ROOT/disk-la.img}"
        aux_img="${AUX_IMG:-$ROOT/disk-la-extra.img}"
        exec_cmd=(
            qemu-system-loongarch64
            -kernel "$kernel"
            -m "$MEM"
            -nographic
            -smp "$SMP"
            -drive "file=$fs_img,if=none,format=raw,id=x0"
            -device virtio-blk-pci,drive=x0,bus=virtio-mmio-bus.0
            -no-reboot
            -device virtio-net-pci,netdev=net0
            -netdev user,id=net0,hostfwd=tcp::5555-:5555,hostfwd=udp::5555-:5555
            -rtc base=utc
        )
        if [[ -f "$aux_img" ]]; then
            exec_cmd+=(
                -drive "file=$aux_img,if=none,format=raw,id=x1"
                -device virtio-blk-pci,drive=x1,bus=virtio-mmio-bus.1
            )
        fi
        ;;
    *)
        echo "unsupported arch: $ARCH" >&2
        exit 1
        ;;
esac

if [[ ! -f "$kernel" ]]; then
    echo "kernel image is missing: $kernel" >&2
    exit 1
fi

if [[ ! -f "$fs_img" ]]; then
    echo "testsuite ext4 image is missing: $fs_img" >&2
    exit 1
fi

printf 'running system qemu:'
printf ' %q' "${exec_cmd[@]}"
printf '\n'
exec "${exec_cmd[@]}"
