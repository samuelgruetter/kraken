#include <stdint.h>
#include <stddef.h>

void insertionsort(int64_t *arr, size_t n);

int64_t test_array[5] = {1000000000000LL, -5LL, 42LL, 42LL, -1000000000000LL};

static void sys_write(long fd, const void *buf, long len) {
    __asm__ volatile (
        "syscall"
        :
        : "a"(1L), "D"(fd), "S"(buf), "d"(len)
        : "memory", "rcx", "r11"
    );
}

static __attribute__((noreturn)) void sys_exit(long code) {
    __asm__ volatile (
        "syscall"
        :
        : "a"(60L), "D"(code)
        :
    );
    __builtin_unreachable();
}

void _start(void) {
    insertionsort(test_array, 5);
    sys_write(1, test_array, 5 * (long)sizeof(int64_t));
    sys_exit(0);
}
