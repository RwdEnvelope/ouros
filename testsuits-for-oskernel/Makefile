DOCKER ?= docker.educg.net/cg/os-contest:20250614
CODE_ROOT ?= $(CURDIR)
RV_MUSL_PREFIX ?= $(shell sh -c 'for p in riscv64-linux-musl- riscv64-buildroot-linux-musl-; do command -v "$${p}gcc" >/dev/null 2>&1 && { printf "%s" "$$p"; exit 0; }; done')
RV_GLIBC_PREFIX ?= riscv64-linux-gnu-
LA_MUSL_PREFIX ?= $(shell sh -c 'for p in loongarch64-linux-musl-; do command -v "$${p}gcc" >/dev/null 2>&1 && { printf "%s" "$$p"; exit 0; }; done')
LA_GLIBC_PREFIX ?= loongarch64-linux-gnu-

all: sdcard

build-all: build-rv build-la

build-rv:
	make -f Makefile.sub clean
	mkdir -p sdcard/riscv/musl
	@if [ -z "$(RV_MUSL_PREFIX)" ]; then \
		echo "no usable riscv64 musl toolchain found; tried riscv64-linux-musl-gcc and riscv64-buildroot-linux-musl-gcc" >&2; \
		exit 1; \
	fi
	make -f Makefile.sub PREFIX=$(RV_MUSL_PREFIX) DESTDIR=$(CODE_ROOT)/sdcard/riscv/musl
	@mkdir -p sdcard/riscv/musl/lib
	@libc_path="$$( $(RV_MUSL_PREFIX)gcc -print-file-name=libc.so )"; \
	if [ "$$libc_path" = "libc.so" ] || [ ! -f "$$libc_path" ]; then \
		libc_path="$$( $(RV_MUSL_PREFIX)gcc -print-file-name=lib/libc.so )"; \
	fi; \
	if [ "$$libc_path" = "lib/libc.so" ] || [ ! -f "$$libc_path" ]; then \
		echo "unable to locate musl libc.so for $(RV_MUSL_PREFIX)" >&2; \
		exit 1; \
	fi; \
	cp "$$libc_path" sdcard/riscv/musl/lib
	sed -E -i 's/#### OS COMP TEST GROUP ([^ ]+) ([^ ]+) ####/#### OS COMP TEST GROUP \1 \2-musl ####/g' sdcard/riscv/musl/*_testcode.sh

	make -f Makefile.sub clean
	mkdir -p sdcard/riscv/glibc
	make -f Makefile.sub PREFIX=$(RV_GLIBC_PREFIX) DESTDIR=$(CODE_ROOT)/sdcard/riscv/glibc
	@mkdir -p sdcard/riscv/glibc/lib
	@libc_path="$$( $(RV_GLIBC_PREFIX)gcc -print-file-name=libc.so.6 )"; \
	libm_path="$$( $(RV_GLIBC_PREFIX)gcc -print-file-name=libm.so.6 )"; \
	ldso_path="$$( $(RV_GLIBC_PREFIX)gcc -print-file-name=ld-linux-riscv64-lp64d.so.1 )"; \
	if [ "$$libc_path" = "libc.so.6" ] || [ ! -f "$$libc_path" ] || \
	   [ "$$libm_path" = "libm.so.6" ] || [ ! -f "$$libm_path" ] || \
	   [ "$$ldso_path" = "ld-linux-riscv64-lp64d.so.1" ] || [ ! -f "$$ldso_path" ]; then \
		echo "unable to locate riscv64 glibc runtime libraries for $(RV_GLIBC_PREFIX)" >&2; \
		exit 1; \
	fi; \
	cp "$$libc_path" sdcard/riscv/glibc/lib/libc.so; \
	cp "$$libc_path" sdcard/riscv/glibc/lib/; \
	cp "$$libm_path" sdcard/riscv/glibc/lib/libm.so; \
	cp "$$libm_path" sdcard/riscv/glibc/lib/; \
	cp "$$ldso_path" sdcard/riscv/glibc/lib/ld-linux-riscv64-lp64d.so.1
	sed -E -i 's/#### OS COMP TEST GROUP ([^ ]+) ([^ ]+) ####/#### OS COMP TEST GROUP \1 \2-glibc ####/g' sdcard/riscv/glibc/*_testcode.sh

build-la:
	make -f Makefile.sub clean
	mkdir -p sdcard/loongarch/musl
	@if [ -z "$(LA_MUSL_PREFIX)" ]; then \
		echo "no usable loongarch64 musl toolchain found; tried loongarch64-linux-musl-gcc" >&2; \
		exit 1; \
	fi
	make -f Makefile.sub PREFIX=$(LA_MUSL_PREFIX) DESTDIR=$(CODE_ROOT)/sdcard/loongarch/musl
	@mkdir -p sdcard/loongarch/musl/lib
	@libc_path="$$( $(LA_MUSL_PREFIX)gcc -print-file-name=libc.so )"; \
	if [ "$$libc_path" = "libc.so" ] || [ ! -f "$$libc_path" ]; then \
		libc_path="$$( $(LA_MUSL_PREFIX)gcc -print-file-name=lib/libc.so )"; \
	fi; \
	if [ "$$libc_path" = "lib/libc.so" ] || [ ! -f "$$libc_path" ]; then \
		echo "unable to locate musl libc.so for $(LA_MUSL_PREFIX)" >&2; \
		exit 1; \
	fi; \
	cp "$$libc_path" sdcard/loongarch/musl/lib
	sed -E -i 's/#### OS COMP TEST GROUP ([^ ]+) ([^ ]+) ####/#### OS COMP TEST GROUP \1 \2-musl ####/g' sdcard/loongarch/musl/*_testcode.sh

	make -f Makefile.sub clean
	mkdir -p sdcard/loongarch/glibc
	make -f Makefile.sub PREFIX=$(LA_GLIBC_PREFIX) DESTDIR=$(CODE_ROOT)/sdcard/loongarch/glibc
	@mkdir -p sdcard/loongarch/glibc/lib
	@libc_path="$$( $(LA_GLIBC_PREFIX)gcc -print-file-name=libc.so.6 )"; \
	libm_path="$$( $(LA_GLIBC_PREFIX)gcc -print-file-name=libm.so.6 )"; \
	ldso_path="$$( $(LA_GLIBC_PREFIX)gcc -print-file-name=ld-linux-loongarch-lp64d.so.1 )"; \
	if [ "$$libc_path" = "libc.so.6" ] || [ ! -f "$$libc_path" ] || \
	   [ "$$libm_path" = "libm.so.6" ] || [ ! -f "$$libm_path" ] || \
	   [ "$$ldso_path" = "ld-linux-loongarch-lp64d.so.1" ] || [ ! -f "$$ldso_path" ]; then \
		echo "unable to locate loongarch64 glibc runtime libraries for $(LA_GLIBC_PREFIX)" >&2; \
		exit 1; \
	fi; \
	cp "$$libc_path" sdcard/loongarch/glibc/lib; \
	cp "$$libm_path" sdcard/loongarch/glibc/lib; \
	cp "$$ldso_path" sdcard/loongarch/glibc/lib
	sed -E -i 's/#### OS COMP TEST GROUP ([^ ]+) ([^ ]+) ####/#### OS COMP TEST GROUP \1 \2-glibc ####/g' sdcard/loongarch/glibc/*_testcode.sh

sdcard: build-all .PHONY
	dd if=/dev/zero of=sdcard-rv.img count=4096 bs=1M
	mkfs.ext4 sdcard-rv.img
	mkdir -p mnt
	mount sdcard-rv.img mnt
	cp -rL sdcard/riscv/* mnt
	cp mnt/musl/lib/dlopen_dso.so mnt/musl
	cp mnt/musl/lib/tls_get_new-dtv_dso.so mnt/musl
	cp mnt/glibc/lib/dlopen_dso.so mnt/glibc
	cp mnt/glibc/lib/tls_get_new-dtv_dso.so mnt/glibc
	umount mnt
	xz sdcard-rv.img

	dd if=/dev/zero of=sdcard-la.img count=4096 bs=1M
	mkfs.ext4 sdcard-la.img
	mkdir -p mnt
	mount sdcard-la.img mnt
	cp -rL sdcard/loongarch/* mnt
	cp mnt/musl/lib/dlopen_dso.so mnt/musl
	cp mnt/musl/lib/tls_get_new-dtv_dso.so mnt/musl
	cp mnt/glibc/lib/dlopen_dso.so mnt/glibc
	cp mnt/glibc/lib/tls_get_new-dtv_dso.so mnt/glibc
	umount mnt
	xz sdcard-la.img


clean:
	make -f Makefile.sub clean
	rm -rf sdcard/riscv/*
	rm -rf sdcard/loongarch/*
	rm -f sdcard-la.img.xz
	rm -f sdcard-rv.img.xz

docker:
	docker run --rm -it -v .:/code --entrypoint bash -w /code --privileged $(DOCKER)


.PHONY:
