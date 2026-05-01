ROOT := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))
BUILD_RUNNER := $(ROOT)/compat/tools/build_runner.sh
RUN_SUITE := $(ROOT)/compat/tools/run-suite.sh
MAKE_DISK := $(ROOT)/compat/tools/make_suite_disk.sh
RUN_SYSTEM := $(ROOT)/compat/tools/run-system-qemu.sh

arch ?= riscv64
file ?=

SUPPORTED_ARCHES := riscv64 loongarch64
SUPPORTED_SUITES := basic busybox lua libctest iozone unixbench iperf libcbench lmbench cyclictest ltp netperf

.DEFAULT_GOAL := all

all: kernel-rv kernel-la

kernel-rv:
	@$(MAKE) build-kernel arch=riscv64 output=kernel-rv

kernel-la:
	@$(MAKE) build-kernel arch=loongarch64 output=kernel-la

build-kernel:
	@if [ -z "$(output)" ]; then echo "missing output=<path>"; exit 1; fi
	@if ! printf '%s\n' $(SUPPORTED_ARCHES) | grep -qx "$(arch)"; then \
		echo "unsupported arch: $(arch)"; \
		echo "supported arches: $(SUPPORTED_ARCHES)"; \
		exit 1; \
	fi
	@rm -f "$(ROOT)"/compat/oscomp-runner/oscomp-runner_*.elf "$(ROOT)"/compat/oscomp-runner/oscomp-runner_*.bin "$(ROOT)/$(output)"
	@"$(BUILD_RUNNER)" "$(arch)" build
	@src="$$(ls -t "$(ROOT)"/compat/oscomp-runner/oscomp-runner_*.elf 2>/dev/null | head -n 1)"; \
	if [ -z "$$src" ]; then \
		echo "unable to locate built elf image under compat/oscomp-runner/"; \
		exit 1; \
	fi; \
	cp "$$src" "$(ROOT)/$(output)"; \
	chmod +x "$(ROOT)/$(output)"; \
	echo "generated $(output) from $$src"

build-suites-rv:
	@$(MAKE) -C "$(ROOT)/testsuits-for-oskernel" build-rv

build-suites-la:
	@$(MAKE) -C "$(ROOT)/testsuits-for-oskernel" build-la

disk-rv:
	@"$(MAKE_DISK)" riscv64

disk-la:
	@"$(MAKE_DISK)" loongarch64

suite:
	@if [ -z "$(file)" ]; then \
		echo "usage: make suite file=<$(firstword $(SUPPORTED_SUITES))|...> [arch=riscv64|loongarch64]"; \
		echo "supported suites: $(SUPPORTED_SUITES)"; \
		exit 1; \
	fi
	@"$(RUN_SUITE)" "$(file)" "$(arch)"

suite-all:
	@"$(RUN_SUITE)" all "$(arch)"

run-system:
	@"$(RUN_SYSTEM)" "$(arch)"

clean:
	@rm -f "$(ROOT)"/kernel-rv "$(ROOT)"/kernel-la
	@rm -f "$(ROOT)"/disk-rv.img "$(ROOT)"/disk-la.img "$(ROOT)"/disk.img
	@rm -f "$(ROOT)"/compat/oscomp-runner/oscomp-runner_*.elf
	@rm -f "$(ROOT)"/compat/oscomp-runner/oscomp-runner_*.bin
	@rm -f "$(ROOT)"/compat/oscomp-runner/oscomp-runner_*.uimg

.PHONY: all kernel-rv kernel-la build-kernel build-suites-rv build-suites-la disk-rv disk-la suite suite-all run-system clean
