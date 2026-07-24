# ################################################################
# LZ4 - Makefile
# Copyright (C) Yann Collet 2011-2023
# All rights reserved.
#
# BSD license
# Redistribution and use in source and binary forms, with or without modification,
# are permitted provided that the following conditions are met:
#
# * Redistributions of source code must retain the above copyright notice, this
#   list of conditions and the following disclaimer.
#
# * Redistributions in binary form must reproduce the above copyright notice, this
#   list of conditions and the following disclaimer in the documentation and/or
#   other materials provided with the distribution.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
# ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
# WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
# DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR
# ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
# (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
# LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON
# ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
# (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
# SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
#
# You can contact the author at :
#  - LZ4 source repository : https://github.com/lz4/lz4
#  - LZ4 forum froup : https://groups.google.com/forum/#!forum/lz4c
# ################################################################

LZ4DIR  = lib
PRGDIR  = programs
TESTDIR = tests
EXDIR   = examples
FUZZDIR = ossfuzz

include build/make/lz4defs.make

MAKE += --no-print-directory

.PHONY: default
default: lib-release lz4-release

# silent mode by default; verbose can be triggered by V=1 or VERBOSE=1
$(V)$(VERBOSE).SILENT:

.PHONY: all
all: allmost examples manuals build_tests

.PHONY: allmost
allmost: lib lz4

.PHONY: lib lib-release liblz4.a
lib lib-release liblz4.a:
	$(MAKE) -C $(LZ4DIR) $@

.PHONY: lz4 lz4-release
lz4 lz4-release :
	$(MAKE) -C $(PRGDIR) $@
	$(LN_SF) $(PRGDIR)/lz4$(EXT) .
	echo lz4 build completed

.PHONY: examples
examples: lib
	$(MAKE) -C $(EXDIR) all

.PHONY: manuals
manuals:
	$(MAKE) -C contrib/gen_manual $@

.PHONY: build_tests
build_tests:
	$(MAKE) -C $(TESTDIR) all

.PHONY: clean
clean: MAKEFLAGS= --no-print-directory
clean:
	$(MAKE) -C $(LZ4DIR) $@ > $(VOID)
	$(MAKE) -C $(PRGDIR) $@ > $(VOID)
	$(MAKE) -C $(TESTDIR) $@ > $(VOID)
	$(MAKE) -C $(EXDIR) $@ > $(VOID)
	$(MAKE) -C $(FUZZDIR) $@ > $(VOID)
	$(MAKE) -C contrib/gen_manual $@ > $(VOID)
	$(RM) lz4$(EXT)
	$(RM) -r $(CMAKE_BUILD_DIR) $(MESON_BUILD_DIR)
	@echo Cleaning completed


#-----------------------------------------------------------------------------
# make install is validated only for Posix environments
#-----------------------------------------------------------------------------
ifeq ($(POSIX_ENV),Yes)
HOST_OS = POSIX

.PHONY: install uninstall
install uninstall:
	$(MAKE) -C $(LZ4DIR) $@
	$(MAKE) -C $(PRGDIR) $@

.PHONY: test-install
test-install:
	$(MAKE) -j1 install DESTDIR=~/install_test_dir

endif   # POSIX_ENV


CMAKE ?= cmake
CMAKE_BUILD_DIR ?= build/cmake/build
ifneq (,$(filter MSYS%,$(shell $(UNAME))))
HOST_OS = MSYS
CMAKE_PARAMS = -G"MSYS Makefiles"
endif

.PHONY: cmakebuild
cmakebuild:
	mkdir -p $(CMAKE_BUILD_DIR)
	cd $(CMAKE_BUILD_DIR); $(CMAKE) $(CMAKE_PARAMS) ..; $(CMAKE) --build .

MESON ?= meson
MESON_BUILD_DIR ?= mesonBuildDir

.PHONY: mesonbuild
mesonbuild:
	$(MESON) setup --fatal-meson-warnings --buildtype=debug -Db_lundef=false -Dauto_features=enabled -Dprograms=true -Dcontrib=true -Dtests=true -Dexamples=true build/meson $(MESON_BUILD_DIR)
	$(MESON) test -C $(MESON_BUILD_DIR)

#------------------------------------------------------------------------
# make tests validated only for MSYS and Posix environments
#------------------------------------------------------------------------
ifneq (,$(filter $(HOST_OS),MSYS POSIX))

.PHONY: list
list:
	$(MAKE) -pRrq -f $(lastword $(MAKEFILE_LIST)) : 2>/dev/null | awk -v RS= -F: '/^# File/,/^# Finished Make data base/ {if ($$1 !~ "^[#.]") {print $$1}}' | sort | egrep -v -e '^[^[:alnum:]]' -e '^$@$$' | xargs

.PHONY: check
check:
	$(MAKE) -C $(TESTDIR) test-lz4-essentials

.PHONY: test
test:
	$(MAKE) -C $(TESTDIR) $@
	$(MAKE) -C $(EXDIR) $@

.PHONY: usan
usan: CC      = clang
usan: CFLAGS  = -O3 -g -fsanitize=undefined -fno-sanitize-recover=undefined -fsanitize-recover=pointer-overflow
usan: LDFLAGS = $(CFLAGS)
usan: clean
	CC=$(CC) CFLAGS='$(CFLAGS)' LDFLAGS='$(LDFLAGS)' $(MAKE) test FUZZER_TIME="-T30s" NB_LOOPS=-i1

.PHONY: ubsan
ubsan: usan

.PHONY: usan32
usan32: CFLAGS = -m32 -O3 -g -fsanitize=undefined -fno-sanitize-recover=undefined -fsanitize-recover=pointer-overflow
usan32: LDFLAGS = $(CFLAGS)
usan32: clean
	CFLAGS='$(CFLAGS)' LDFLAGS='$(LDFLAGS)' $(MAKE) V=1 test FUZZER_TIME="-T30s" NB_LOOPS=-i1

SCANBUILD ?= scan-build
SCANBUILD_FLAGS += --status-bugs -v --force-analyze-debug-code
.PHONY: staticAnalyze
staticAnalyze: clean
	CPPFLAGS=-DLZ4_DEBUG=1 CFLAGS=-g $(SCANBUILD) $(SCANBUILD_FLAGS) $(MAKE) all V=1 DEBUGLEVEL=1

.PHONY: cppcheck
cppcheck:
	cppcheck . --force --enable=warning,portability,performance,style --error-exitcode=1 > /dev/null

.PHONY: platformTest
platformTest: clean
	@echo "\n ---- test lz4 with $(CC) compiler ----"
	$(CC) -v
	CFLAGS="$(CFLAGS) -O3 -Werror"         $(MAKE) -C $(LZ4DIR) all
	CFLAGS="$(CFLAGS) -O3 -Werror -static" $(MAKE) -C $(PRGDIR) all
	CFLAGS="$(CFLAGS) -O3 -Werror -static" $(MAKE) -C $(TESTDIR) all
	$(MAKE) -C $(TESTDIR) test-platform

.PHONY: versionsTest
versionsTest:
	$(MAKE) -C $(TESTDIR) clean
	$(MAKE) -C $(TESTDIR) $@

.PHONY: test-freestanding
test-freestanding:
	$(MAKE) -C $(TESTDIR) clean
	$(MAKE) -C $(TESTDIR) $@

# test linking C libraries from C++ executables
.PHONY: ctocxxtest
ctocxxtest: LIBCC="$(CC)"
ctocxxtest: EXECC="$(CXX) -Wno-deprecated"
ctocxxtest: CFLAGS=-O0
ctocxxtest:
	CFLAGS="$(CFLAGS)" CC=$(LIBCC) $(MAKE) -C $(LZ4DIR)  all
	CC=$(LIBCC) $(MAKE) -C $(TESTDIR) CFLAGS="$(CFLAGS)" lz4.o lz4hc.o lz4frame.o
	CC=$(EXECC) $(MAKE) -C $(TESTDIR) CFLAGS="$(CFLAGS)" all

.PHONY: cxxtest cxx32test
cxx32test: CFLAGS += -m32
cxxtest cxx32test: CC := "$(CXX) -Wno-deprecated"
cxxtest cxx32test: CFLAGS = -O3 -Wall -Wextra -Wundef -Wshadow -Wcast-align -Werror
cxxtest cxx32test:
	$(CXX) -v
	CC=$(CC) CFLAGS="$(CFLAGS)" $(MAKE) -C $(LZ4DIR)  all
	CC=$(CC) CFLAGS="$(CFLAGS)" $(MAKE) -C $(PRGDIR)  all
	CC=$(CC) CFLAGS="$(CFLAGS)" $(MAKE) -C $(TESTDIR) all

.PHONY: cxx17build
cxx17build : CC = "$(CXX) -Wno-deprecated"
cxx17build : CFLAGS = -std=c++17 -Wall -Wextra -Wundef -Wshadow -Wcast-align -Werror -Wpedantic
cxx17build : clean
	$(CXX) -v
	CC=$(CC) $(MAKE) -C $(LZ4DIR)  all CFLAGS="$(CFLAGS)"
	CC=$(CC) $(MAKE) -C $(PRGDIR)  all CFLAGS="$(CFLAGS)"
	CC=$(CC) $(MAKE) -C $(TESTDIR) all CFLAGS="$(CFLAGS)"

.PHONY: c_standards
c_standards: clean c_standards_c11 c_standards_c99 c_standards_c90

.PHONY: c_standards_c90
c_standards_c90: clean
	$(MAKE) clean; CFLAGS="-std=c90   -Werror -Wpedantic -Wno-long-long -Wno-variadic-macros" $(MAKE) allmost
	$(MAKE) clean; CFLAGS="-std=gnu90 -Werror -Wpedantic -Wno-long-long -Wno-variadic-macros" $(MAKE) allmost

.PHONY: c_standards_c99
c_standards_c99: clean
	$(MAKE) clean; CFLAGS="-std=c99   -Werror -Wpedantic" $(MAKE) all
	$(MAKE) clean; CFLAGS="-std=gnu99 -Werror -Wpedantic" $(MAKE) all

.PHONY: c_standards_c11
c_standards_c11: clean
	$(MAKE) clean; CFLAGS="-std=c11 -Werror" $(MAKE) all

# The following test ensures that standard Makefile variables set through environment
# are correctly transmitted at compilation stage.
# This test is meant to detect issues like https://github.com/lz4/lz4/issues/958
.PHONY: test_stdvars
test_stdvars:  ## CI helper – verifies CC/CFLAGS/CPPFLAGS/LDFLAGS/LDLIBS propagation
	@echo '--- standard-variable propagation test ---'
	@$(RM) .stdvars.log

	@$(MAKE) -rn V=1 \
	    CC='cc -DCC_TEST' \
	    CFLAGS='-DCFLAGS_TEST' \
	    CPPFLAGS='-DCPPFLAGS_TEST' \
	    LDFLAGS='-DLDFLAGS_TEST' \
	    LDLIBS='-DLDLIBS_TEST' \
	  | tee .stdvars.log >/dev/null

	@tests/check_stdvars.sh .stdvars.log
	@$(RM) .stdvars.log

endif   # MSYS POSIX

#-----------------------------------------------------------------------------
# RISC-V cross-compilation (SpacemiT X60)
#-----------------------------------------------------------------------------
# Required environment variables (set before running):
#   CC_RISCV  : cross-compiler path    (e.g. export CC_RISCV=~/x-tools/.../riscv64-unknown-linux-gnu-gcc)
#   STRIP_RISCV : cross-strip path     (default: $(dir $(CC_RISCV))riscv64-unknown-linux-gnu-strip)
#   BOARD     : ssh target             (e.g. export BOARD=root@192.168.1.x)
#   BOARD_LD  : board dynamic linker   (e.g. export BOARD_LD=~/glibcrv/lib/ld-linux-riscv64-lp64d.so.1)
#   BOARD_LIBPATH : board library path (e.g. export BOARD_LIBPATH=~/glibcrv/lib)
#   SSHPASS   : sshpass password flag  (e.g. export SSHPASS=-p mypassword)
# Optional:
#   PGO_DIR   : profile data directory (default: /tmp/pgo_v2)

CC_RISCV      ?=
STRIP_RISCV   ?= $(dir $(CC_RISCV))riscv64-unknown-linux-gnu-strip
BOARD         ?=
BOARD_LD      ?=
BOARD_LIBPATH ?=
PGO_DIR       ?= /tmp/pgo_v2
SSHPASS       ?=

.PHONY: riscv-check-env
riscv-check-env:
	@if test -z "$(CC_RISCV)" -o -z "$(BOARD)" -o -z "$(BOARD_LD)" -o -z "$(BOARD_LIBPATH)"; then \
	  echo "ERROR: Set CC_RISCV, BOARD, BOARD_LD, BOARD_LIBPATH first. See BUILD_RISCV.md."; \
	  exit 1; \
	fi

.PHONY: riscv
riscv: riscv-check-env riscv-generate riscv-train riscv-use riscv-deploy

.PHONY: riscv-lib
riscv-lib: riscv-check-env
	$(MAKE) -C $(LZ4DIR) CC="$(CC_RISCV)"

.PHONY: riscv-lz4
riscv-lz4: riscv-check-env
	$(MAKE) -C $(PRGDIR) CC="$(CC_RISCV)"

.PHONY: riscv-pgo-clean
riscv-pgo-clean:
	$(RM) -r $(PGO_DIR)
	mkdir -p $(PGO_DIR)

.PHONY: riscv-generate
riscv-generate: riscv-check-env riscv-pgo-clean
	$(MAKE) -C $(PRGDIR) clean  > $(VOID)
	$(MAKE) -C $(PRGDIR)        CC="$(CC_RISCV)" PGO_FLAGS="-fprofile-generate=$(PGO_DIR) -fprofile-correction"

.PHONY: riscv-deploy
riscv-deploy: riscv-check-env
	test -f $(PRGDIR)/lz4 || { echo "Build $(PRGDIR)/lz4 first (make riscv-lz4 or riscv-generate/use)"; exit 1; }
	$(STRIP_RISCV) $(PRGDIR)/lz4
	sshpass $(SSHPASS) scp $(PRGDIR)/lz4 $(BOARD):/tmp/lz4

.PHONY: riscv-train
riscv-train: riscv-check-env
	sshpass $(SSHPASS) ssh $(BOARD) ' \
	  set -e; \
	  mkdir -p $(PGO_DIR); \
	  LD=$(BOARD_LD); \
	  LP="--library-path $(BOARD_LIBPATH)"; \
	  LZ4=/tmp/lz4; \
	  BIN=/usr/bin; \
	  for f in true false sh env dir ls tar cat; do \
	    test -f "$$BIN/$$f" || continue; \
	    $$LD $$LP $$LZ4 -1 "$$BIN/$$f" -c > /dev/null 2>/dev/null || true; \
	    $$LD $$LP $$LZ4 -3 "$$BIN/$$f" -c > /dev/null 2>/dev/null || true; \
	    $$LD $$LP $$LZ4 -9 "$$BIN/$$f" -c > /dev/null 2>/dev/null || true; \
	  done; \
	  for lvl in 1 3 9; do \
	    $$LD $$LP $$LZ4 -$$lvl "$$BIN/true" -c > /tmp/t$$lvl.lz4 2>/dev/null; \
	    $$LD $$LP $$LZ4 -d /tmp/t$$lvl.lz4 -c > /dev/null 2>/dev/null || true; \
	    rm -f /tmp/t$$lvl.lz4; \
	  done; \
	  echo "Training done, profile files: $$(ls $(PGO_DIR)/*.gcda 2>/dev/null | wc -l)"; \
	'

.PHONY: riscv-collect
riscv-collect: riscv-check-env
	sshpass $(SSHPASS) rsync -a $(BOARD):$(PGO_DIR)/ $(PGO_DIR)/

.PHONY: riscv-use
riscv-use: riscv-check-env
	$(MAKE) -C $(PRGDIR) clean  > $(VOID)
	$(MAKE) -C $(PRGDIR)        CC="$(CC_RISCV)" PGO_FLAGS="-fprofile-use=$(PGO_DIR) -fprofile-correction"

.PHONY: riscv-run
riscv-run: riscv-check-env
	sshpass $(SSHPASS) ssh $(BOARD) '$(BOARD_LD) --library-path $(BOARD_LIBPATH) -- /tmp/lz4 $(ARGS)'

.PHONY: riscv-version
riscv-version: riscv-check-env riscv-deploy
	sshpass $(SSHPASS) ssh $(BOARD) '$(BOARD_LD) --library-path $(BOARD_LIBPATH) -- /tmp/lz4 --version'
