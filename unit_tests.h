/* unit_tests.h: unit test runner for host and target */

/* This header defines a version of the `assert()' macro, and declares
   the function prototype for `tests()' which client code must
   implement. This hedader itself is portable C, although some files
   that include it may be specific to STM32 or other ARM
   environments. */

#include <stdio.h>

#ifdef NDEBUG
#define assert(epression) ((void)0)
#else
#define assert(expression) if (!(expression)) \
    assertion_failure(__FILE__, __LINE__, __FUNCTION__, #expression);
#endif

/* Client code must implement this function. Typically, the
   implementation is a list of `assert()' tests, or a list of
   functions that group such tests together. arm+posix_unit_tests.c
   invokes `tests()' from its `main()'. */
void tests(void);

/* Implementation of `assert()'. Client code need never invoke this
   function directly. It is in this header since the expansion of
   `assert()' may include a call to it. */
void assertion_failure(const char *file,
                       int line,
                       const char *function,
                       const char *expression);
