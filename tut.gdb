# tut.gdb: gdb commands for running unit tests on target hardware

# This file assumes that an OpenOCD server is running on localhost. It
# also assumes that the binary defines two functions, `success()' and
# `failure()'. It sets breakpoints on these functions and exits
# successfully or with an error code if it hits one of these
# breakpoints respectively.

target remote localhost:3333

monitor arm semihosting enable
monitor reset halt
load
monitor reset init

break success
commands
monitor shutdown
quit 0
end

break failure
commands
monitor shutdown
quit 1
end

continue
