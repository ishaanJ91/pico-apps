#define WOKWI             // Uncomment if running on Wokwi RP2040 emulator.

#include <stdio.h>
#include <stdlib.h>
#include <math.h>
#include "pico/float.h"     // Required for using single-precision variables.
#include "pico/double.h"    // Required for using double-precision variables.

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
    printf("Single Precision: %.10f\n", pi);

    float error = ((pi_f_original - pi) / pi_f_original) * 100.0f; // Calculate the approximation error
    printf("Approximation Error (Single Precision): %.10f\n", error);


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
    printf("Double Precision: %.15f\n", pi);

    // Calculate the approximation error
    double error = ((pi_d_original - pi) / pi_d_original) * 100.0; // Calculate the approximation error
    printf("Approximation Error (Double Precision): %.15f\n", error);

    return pi;
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
    // Constant
    long int iterations = 100000;
    float pi_f_original = 3.14159265359;
    double pi_d_original = 3.14159265359;

#ifndef WOKWI
    // Initialise the IO as we will be using the UART
    // Only required for hardware and not needed for Wokwi
    stdio_init_all();
#endif

    // Perform calculations
    single_precision(iterations, pi_f_original);
    double_precision(iterations, pi_d_original);

    // Print a console message to inform user what's going on.
    printf("Hello, World!\n");

    // Returning zero indicates everything went okay.
    return 0;
}