# arm+posix.mk: an includable Makefile fragment to build firmware for
# ARM microcontrollers and unit tests for uC targets and hosts

# Recipes in this file allow the same code to cross-compile for a
# target microcontroller as well as run locally on the build host. For
# local compilation, this makefile uses default, implicit make rules
# for compiling and linking C programs. For cross-compilation, it
# defines new ones using the ARM GCC toolchain. These recipes honor
# standard make variables `$(CPPFLAGS)`, `$(CFLAGS)` ,`$(LDFLAGS)`,
# `$(LDLIBS)`. Additionally, `$(ARM_*)` versions of these variables
# allow controlling the cross-compiling toolchain without affecting
# native compilation. To differentiate corss-compiling object file
# from ones for the local architecture, the cross-compiling recipes
# use the `.ao` file suffix (for ARM object). Regular, standalone
# binaries link to `.elf` files. Binaries that use semihosting and
# unit-test facilities in this package compile to `.telf` files (for
# Testing ELF). This file defines a number of "phony" recipes for
# running these binaries: `.upload`, `.tut` and `.run`.

# This file contains only generic ARM recipes. The caller must
# supply the configuration for relevant target system.

# This file expects the caller to define the following variables:
#
# $(SHUT_PATH): the directory where this file resides. Caller must
#         define it so that recipes in this file can reference
#         dependencies relative to its path. Additionally, caller may
#         want to add this to `VPATH`, `-I` flags in`$(CPP_FLAGS)`,
#         etc.
#
# $(CPPFLAGS) $(CFLAGS) $(LDFLAGS) $(LDLIBS) affect both native and
#         cross-comiling toolchains
# $(ARM_CPPFLAGS) $(ARM_CFLAGS) $(ARM_LDFLAGS) $(ARM_LDLIBS) affect
#         only the cross-comiling toolchain
# $(ARM_FLAGS) affect every component in cross-comiling toolchain
#
# $(VENDOR_OBJS) is a list of `.ao` objects necessary for linking uC
#         binaries, e.g., startup code from the silicon vendor
#
# $(OCD_INTERFACE), $(OCD_TARGET) are paths to OpenOCD configuration
#         files for the probe and target uC respectively

####################
# DEPENDENCIES
ARM_CC      = arm-none-eabi-gcc
ARM_OBJCOPY = arm-none-eabi-objcopy
ARM_GDB     = gdb-multiarch
OPENOCD     = openocd

####################
# CROSS-COMPILER GENERAL-CASE RECIPES

%.ao: %.S                      # assembly with pre-processing
	$(ARM_CC) $(ARM_FLAGS) $(CPPFLAGS) $(ARM_CPPFLAGS) $(CFLAGS) $(ARM_CFLAGS) -c -o $@ $<

%.ao: %.s                      # assembly without pre-processing
	$(ARM_CC) $(ARM_FLAGS) $(CPPFLAGS) $(ARM_CPPFLAGS) $(CFLAGS) $(ARM_CFLAGS) -c -o $@ $<

%.ao: %.c                      # regular compilation
	$(ARM_CC) $(ARM_FLAGS) $(CPPFLAGS) $(ARM_CPPFLAGS) $(CFLAGS) $(ARM_CFLAGS) -c -o $@ $<

%.elf: %.ao $(VENDOR_OBJS)     # linkage for standalone binaries
	$(ARM_CC) $(ARM_FLAGS) $(LDFLAGS) $(ARM_LDFLAGS) $(LDLIBS) $(ARM_LDLIBS) -o $@ $^
	arm-none-eabi-size $@

%.telf: %.ao $(VENDOR_OBJS) arm+posix_unit_tests.ao # linkage for semi-hosting unit-test binaries
	$(ARM_CC) $(ARM_FLAGS) $(LDFLAGS) $(ARM_LDFLAGS) $(LDLIBS) $(ARM_LDLIBS) -specs=rdimon.specs -lrdimon -o $@ $^
	arm-none-eabi-size $@

%.bin: %.elf                   # raw binary for DFU upload
	$(ARM_OBJCOPY) -O binary $< $@


####################
# SPECIAL-CASE COMPILER SWITCHES

# disable optimization for target unit test driver to avoid optimizing
# away functions that serve as breakpoint labels
arm+posix_unit_tests.ao: CFLAGS += -O0 -g


####################
# FLASH AND RUN BINARIES

# flash and run through OpenOCD
%.upload: %.elf
	$(OPENOCD) -f $(OCD_INTERFACE) -f $(OCD_TARGET) -c "program $< verify reset exit" -l$*-ocd.log

# run target unit test binaries through gdb and OpenOCD; this target relies
# on semihosting and breakpoints to communicate success or failure
# back to make; this recipe starts an openocd server explicitly and
# gdb stops it before exiting
%.tut: %.telf
	$(OPENOCD) -f $(OCD_INTERFACE) -f $(OCD_TARGET) -l$*-ocd.log &
	$(ARM_GDB) -batch-silent -x $(SHUT_PATH)/tut.gdb $< 2> $*-gdb.log

# run host binary
%.run: %
	./$*
