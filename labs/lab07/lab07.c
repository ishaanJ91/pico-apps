#include <stdio.h>
#include <stdlib.h>
#include <math.h>
#include <string.h>
#include "pico/stdlib.h"
#include "pico/float.h"
#include "pico/double.h"
#include "pico/multicore.h"
#include "pico/time.h"

/**
 * @brief Check if the XIP cache is currently enabled.
 *
 * @return bool True if the cache is enabled, otherwise false.
 */
bool is_cache_enabled() {
    volatile uint32_t *ctrl = (volatile uint32_t *)XIP_CTRL_BASE;
    return ctrl[0];
}

/**
 * @brief Enable or disable XIP cache.
 *
 * @param enable If true, enables the cache; if false, disables it.
 * @return bool True if the cache is enabled after the operation, otherwise false.
 */
bool toggle_cache(bool enable) {
    uint32_t *ctrl = (uint32_t *)XIP_CTRL_BASE;
    ctrl[0] = enable;
    return is_cache_enabled();
}

/**
 * @brief Compute PI approximation using Wallis product (single-precision).
 *
 * @param iterations The number of iterations to perform in the approximation.
 * @return float The approximated value of PI.
 */
float compute_pi_float(int iterations) {
    absolute_time_t start = get_absolute_time(); // Start timer for float PI computation
    float product = 1.0f;
    for (int i = 1; i <= iterations; i++) {
        float n = 4.0f * i * i;
        product *= (n / (n - 1.0f)) * 2.0f;
    }
    absolute_time_t stop = get_absolute_time(); // End timer for float PI computation
    printf("[FLOAT] Cache: %d | Time: %llu us\n", is_cache_enabled(), absolute_time_diff_us(start, stop));
    return product;
}

/**
 * @brief Compute PI approximation using Wallis product (double-precision).
 *
 * @param iterations The number of iterations to perform in the approximation.
 * @return double The approximated value of PI.
 */
double compute_pi_double(int iterations) {
    absolute_time_t start = get_absolute_time(); // Start timer for double PI computation
    double product = 1.0;
    for (int i = 1; i <= iterations; i++) {
        double n = 4.0 * i * i;
        product *= (n / (n - 1.0)) * 2.0;
    }
    absolute_time_t stop = get_absolute_time(); // End timer for double PI computation
    printf("[DOUBLE] Cache: %d | Time: %llu us\n", is_cache_enabled(), absolute_time_diff_us(start, stop));
    return product;
}

/**
 * @brief Core1 entry: receives function pointer and runs float PI computation.
 *
 * This function runs in a separate core and processes PI computations 
 * based on the function pointer received through the FIFO.
 */
void core1_worker() {
    while (1) {
        uintptr_t ptr = multicore_fifo_pop_blocking();
        int arg = multicore_fifo_pop_blocking();

        float (*func)(int) = (float (*)(int))ptr;
        float result = func(arg);

        int32_t packed;
        memcpy(&packed, &result, sizeof(result));
        multicore_fifo_push_blocking(packed);
    }
}

/**
 * @brief Main function to execute the PI approximation computations.
 *
 * This function initializes the system, manages cache settings, and 
 * executes both sequential and parallel computations for PI.
 *
 * @return int Exit status of the program.
 */
int main() {
    const int MAX_ITER = 100000;

    stdio_init_all();
    // Launch core1 to handle parallel float PI computation
    sleep_ms(2000); // Allow time for USB console

    multicore_launch_core1(core1_worker);

    absolute_time_t start, end;
    float pi_f_seq, pi_f_par;
    double pi_d_seq, pi_d_par;
    uint64_t time_seq, time_par;

    // ---------- No Cache ----------
    toggle_cache(false); // Disable cache for performance measurement
    printf("\n[NO CACHE] Sequential Execution\n");
    start = get_absolute_time();
    pi_f_seq = compute_pi_float(MAX_ITER);
    pi_d_seq = compute_pi_double(MAX_ITER);
    end = get_absolute_time();
    time_seq = absolute_time_diff_us(start, end);
    printf("Total sequential time: %llu us\n\n", time_seq);

    printf("[NO CACHE] Parallel Execution\n");
    start = get_absolute_time();
    // Push function pointer and argument to core1 for parallel execution
    multicore_fifo_push_blocking((uintptr_t)&compute_pi_float); // Send compute_pi_float function pointer to core1
    multicore_fifo_push_blocking(MAX_ITER); // Send argument (MAX_ITER) to core1
    pi_d_par = compute_pi_double(MAX_ITER);
    int32_t packed_result = multicore_fifo_pop_blocking(); // Retrieve packed result from core1
    memcpy(&pi_f_par, &packed_result, sizeof(packed_result)); // Unpack result from core1 into pi_f_par
    end = get_absolute_time();
    time_par = absolute_time_diff_us(start, end);
    printf("Total parallel time: %llu us\n\n", time_par);

    // ---------- With Cache ----------
    toggle_cache(true);
    printf("\n[CACHE ENABLED] Sequential Execution\n");
    start = get_absolute_time();
    pi_f_seq = compute_pi_float(MAX_ITER);
    pi_d_seq = compute_pi_double(MAX_ITER);
    end = get_absolute_time();
    time_seq = absolute_time_diff_us(start, end);
    printf("Total sequential time: %llu us\n\n", time_seq);

    printf("[CACHE ENABLED] Parallel Execution\n");
    start = get_absolute_time();
    // Push function pointer and argument to core1 for parallel execution with cache enabled
    multicore_fifo_push_blocking((uintptr_t)&compute_pi_float); // Send compute_pi_float function pointer to core1
    multicore_fifo_push_blocking(MAX_ITER); // Send argument (MAX_ITER) to core1
    pi_d_par = compute_pi_double(MAX_ITER);
    packed_result = multicore_fifo_pop_blocking(); // Retrieve packed result from core1
    memcpy(&pi_f_par, &packed_result, sizeof(packed_result)); // Unpack result from core1 into pi_f_par
    end = get_absolute_time();
    time_par = absolute_time_diff_us(start, end);
    printf("Total parallel time: %llu us\n\n", time_par);

    return 0;
}