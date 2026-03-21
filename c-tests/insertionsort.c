#include <stdint.h>
#include <stddef.h>

void insertionsort(int64_t *arr, size_t n) {
    for (size_t i = 1; i < n; i++) {
        int64_t key = arr[i];
        size_t j = i;
        while (j > 0 && arr[j-1] > key) {
            arr[j] = arr[j-1];
            j--;
        }
        arr[j] = key;
    }
}
