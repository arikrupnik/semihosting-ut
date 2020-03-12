/* arm+posix_unit_tests.c: entry point into host and target unit tests
   for portable C code. When compiling under POSIX, this file provides
   a conventional main() that returns success or failure status
   code. Compiling for STM32, main() sets up ARM semihosting with the
   expectation that the caller attach a debugger and set breakpoints
   to communicate success or failure to the host process. I expect
   this to run on any ARM, but have only used with STM32 so far. */

#include "unit_tests.h"
#include <stdlib.h>

/* These two functions serve as labels where gdb can place
   breakpoints. Embedded applications never quite return, and even if
   they did the invoker would not know about it. The embedded uint
   test recipe in the Makefile uploads the binary to target through
   gdb, and sets these two breakpoints. Gdb exists with success or
   failure code depending on which of the breakpoints hits.

   It is imperative to compile this file without optimizations, e.g.,
   with `-O0` (preferably with `-O0 -g`). With default optimization
   levels, the compiler and linker can be surprisingly aggressive in
   inlining and stripping away these dummy functions. */
void success() {}
void failure() {}

/* This function is necessary for ARM semihosting */
extern void initialise_monitor_handles(void);

void assertion_failure(const char *file,
                       int line,
                       const char *function,
                       const char *expression)
{
  printf("assertion failure in %s:%d (%s): `%s'\n",
         file, line, function, expression);
  failure();
  exit(1);
}

int main(int argc, char* argv[])
{
#ifdef __arm__
  initialise_monitor_handles();
#endif

  tests();

  success();

#ifdef __arm__
  printf("execution past breakpoints :=(\n");
  // need at least one call to failure() to prevent linker from
  // stripping it from the binary. if that happens, gdb fails to set
  // relevant breakpoint
  failure();
#endif
  return 0;
}
