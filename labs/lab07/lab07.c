
#include <stdio.h>
#include <stdlib.h>
#include <math.h>
#include "pico/float.h"     // Required for using single-precision variables.
#include "pico/double.h"    // Required for using double-precision variables.
#include "pico/stdlib.h"
#include "pico/multicore.h"
#include "hardware/timer.h"

uint64_t single_core_time = 0;
uint64_t double_core_time = 0;

/**
 * @brief Calculates Pi using single precision (float).
 * 
 * @param iterations Number of iterations to approximate Pi.
 * @return float Approximate value of Pi.
 */

//  Function for Single Precision Calculation of Pi
float single_precision(int iterations, float pi_f_original) {
    float pi = 1.0f;

    // Loop through the number of iterations to approximate Pi
    for (int i = 1; i < iterations; i++) {
        float fraction_one = (2.0f * i) / ((2.0f * i) - 1.0f);
        float fraction_two = (2.0f * i) / ((2.0f * i) + 1.0f); 

        pi *= fraction_one * fraction_two;
    }

    pi *= 2.0f;  // Final multiplication to approximate Pi

    float error = ((pi_f_original - pi) / pi_f_original) * 100.0f; // Calculate the approximation error

    return pi;
}

/**
 * @brief Calculates Pi using double precision (double).
 * 
 * @param iterations Number of iterations to approximate Pi.
 * @return double Approximate value of Pi.
 */

//  Function for Double Precision Calculation of Pi
double double_precision(int iterations, double pi_d_original) {
    double pi = 1.0;

    // Loop through the number of iterations to approximate Pi
    for (int i = 1; i < iterations; i++) {
        double fraction_one = (2.0 * i) / ((2.0 * i) - 1.0);
        double fraction_two = (2.0 * i) / ((2.0 * i) + 1.0); 

        pi *= fraction_one * fraction_two;
    }

    pi *= 2.0;  // Final multiplication to approximate Pi

    // Calculate the approximation error
    double error = ((pi_d_original - pi) / pi_d_original) * 100.0; // Calculate the approximation error

    return pi;
}

int32_t run_single_precision(int32_t iterations) {
    uint64_t start = time_us_64();
    float pi = single_precision(iterations, 3.14159265359f);
    single_core_time = time_us_64() - start;
    return (int32_t)(pi * 1000000); // Return scaled result
}

int32_t run_double_precision(int32_t iterations) {
    uint64_t start = time_us_64();
    double pi = double_precision(iterations, 3.14159265359);
    double_core_time = time_us_64() - start;
    return (int32_t)(pi * 1000000); // Return scaled result
}

void core1_entry() {
    while (1) {
        int32_t (*func)() = (int32_t(*)()) multicore_fifo_pop_blocking();
        int32_t p = multicore_fifo_pop_blocking();
        int32_t result = (*func)(p);
        multicore_fifo_push_blocking(result);
    }
}

/**
 * @brief The main function initializes the system.
 *
 * main() calculates the value of pi using both float and double precision, computes the approximation
 * error, and prints the results.
 *
 * @return int, Returns 0 upon successful execution.
 */

int main() {
    const int ITER_MAX = 100000;
    stdio_init_all();
    sleep_ms(1000);
    multicore_launch_core1(core1_entry);

    // Sequential Run
    uint64_t start_seq = time_us_64();
    float pi_f = single_precision(ITER_MAX, 3.14159265359f);
    double pi_d = double_precision(ITER_MAX, 3.14159265359);
    uint64_t end_seq = time_us_64();
    uint64_t duration_seq = end_seq - start_seq;

    printf("Sequential Run:\n");
    printf("  Single Precision: %.10f\n", pi_f);
    printf("  Double Precision: %.15f\n", pi_d);
    printf("  Total Time: %llu us\n", duration_seq);

    // Parallel Run
    uint64_t start_par = time_us_64();
    multicore_fifo_push_blocking((uintptr_t)run_double_precision);
    multicore_fifo_push_blocking(ITER_MAX);
    int32_t pi_f_scaled = run_single_precision(ITER_MAX);
    int32_t pi_d_scaled = multicore_fifo_pop_blocking();
    uint64_t end_par = time_us_64();
    uint64_t duration_par = end_par - start_par;

    printf("\nParallel Run:\n");
    printf("  Single Precision: %.10f (Time: %llu us)\n", pi_f_scaled / 1000000.0, single_core_time);
    printf("  Double Precision: %.15f (Time: %llu us)\n", pi_d_scaled / 1000000.0, double_core_time);
    printf("  Total Time: %llu us\n", duration_par);

    // Returning zero indicates everything went okay.
    return 0;
}