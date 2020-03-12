# semihosting-ut

## Tools for running hardware-in-the-loop unit tests on ARM microcontrollers

I like to run unit tests two ways: on the host PC and on the target uC.
Running tests on the host is fast, easy and is independent of hardware availability.
Running tests on target hardware gives me confidence that the code runs correctly with word size, endianness, etc. of the target.

I like to structure my code such that any device-specific code is separate from portable computation.
For example, I may parse bytes that come from a serial port in a serial RX interrupt.
I keep the parsing logic in a separate .c file from the (hardware-specific) interrupt handler.
This allows me to unit-test protocol logic without mocking arcane, non-portable ISR machinery.

ARM architecture includes a facility known as Semihosting.
Semihosting allows code on the microcontroller to access the host's I/O facilities.
UC code can call `stdio.h` functions like `printf(3)` and have the output appear on the host's console.

## Some plumbing is necessary for Semihosting to work

* The uC binary must link against `rdimon` library
    * Relevant linker options: `-specs=rdimon.specs` `-lrdimon`
* uC code must call `initialise_monitor_handles()` before calling any I/O functions
    * Calling `initialise_monitor_handles();` waits for acknowledgment from an attached debugger
    * Making binaries compiled for Semihosting useless in production
* A debugging probe (SWD, JTAG)
* Software on the host must listen for Semihosting calls (OpenOCD)
* Software on the host to report test success or failure (GDB)

The last point needs an explanation.
While Semihosting provides I/O facilities, it offers no standard way to communicate exit status to the host.
UC programs never really exit in the sense that programs on an OS do.
An OS program indicates success or failure with a return code, e.g., a failing `assert()` might call `exit(1)`.
A Semihosting program needs a different way to indicate its outcome.
I use two breakpoints for this an a GDB script that exits with 0 or 1 if it hits the success or failure breakpoint respectively.

## The files in this repository set up all of this plumbing

* `unit_tests,h` is the header that unit-test code must include
    * It defines the macro `assert()` which, unlike the standard definition in `assert.h` works in uC and OS binaries
    * It declares a prototype for `void tests(void)` which unit-test code must implement. If `tests()` returns, the tests pass. If an `assert()` fails during the invocation of `tests()`, the tests fail.
* `arm+posix_unit_tests.c` is the implementation for the above. Unit-test binaries must link against this file.
    * It defines a `main()` that works equally for uC and OS binaries
    * It defines labels for `sucess` and `failure`
    * It calls `tests()` from `main()`
* `tut.gdb` is the script that allows GDB to run non-interactively and report
* `arm+posix.mk` is a GNU Makefile that ties all of this together
    * Include it from your main Makefile if you want to follow our build strategy
    * It defines recipes for compiling and linking on both host and uC
    * It defines recipes for flashing binaries onto target uC
    * It defines recipes for flashing Semihosting binaries and setting up OpenOCD and GDB

## Example unit-test file

```C
#include "liba.h"

#include <unit_tests.h>

void tests()
{
  assert(liba_func(0)==0);
  assert(liba_func(1)==1);
}
```

## Example project Makefile
This makefile targets an STM32F042 target

```Makefile
####################
# GLOBAL FLAGS

CPPFLAGS = -I$(SHUT_PATH)
CFLAGS   = -std=c99 -O3 -Wall -ffunction-sections
#LDLIBS = -lm

####################
# CROSS-COMPILER FLAGS

ARM_FLAGS    = -mcpu=cortex-m0 -mthumb -mfloat-abi=soft
ARM_CPPFLAGS = -Ist/CMSIS/core -Ist/CMSIS/device
ARM_CFLAGS   =
ARM_LDFLAGS  = -Tst/stm32f0xx-32-6.ld -Wl,-Map=$*.map -Wl,--gc-sections
ARM_LDLIBS   = -specs=nano.specs

# startup code from silicone vendor
VENDOR_OBJS=startup_stm32f0xx.ao system_stm32f0xx.ao

# target-specific OpenOCD configuration
OCD_INTERFACE = interface/stlink-v2.cfg
OCD_TARGET    = target/stm32f0x.cfg

SHUT_PATH = semihosting-ut

include $(SHUT_PATH)/arm+posix.mk

VPATH = .:st:$(SHUT_PATH)

####################
# LINKAGE FOR NON-TRIVIAL EXECUTABLES

# main production binary
app.elf: main.ao liba.ao libb.ao

# target unit tests
liba_tests.telf: a.ao        # implicitly depends on liba_tests.ao as well
libb_tests.telf: b.ao

# host unit tests
liba_tests:      a.o arm+posix_unit_tests.o # implicitly depends on liba_tests.o
libb_tests:      b.o arm+posix_unit_tests.o
```

