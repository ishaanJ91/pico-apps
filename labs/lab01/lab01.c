#include "pico/stdlib.h"

/**
 * @brief EXAMPLE - BLINK_C
 *        Simple example to initialise the built-in LED on
 *        the Raspberry Pi Pico and then flash it forever. 
 * 
 * @return int  Application return code (zero for success).
 */


// Added toggle_led function to simplify the code
void toggle_led(uint LED_PIN, uint LED_DELAY) {

    // Toggle the LED on and then sleep for delay period
    gpio_put(LED_PIN, 1);
    sleep_ms(LED_DELAY);

    // Toggle the LED off and then sleep for delay period
    gpio_put(LED_PIN, 0);
    sleep_ms(LED_DELAY);
}

int main() {

    // Specify the PIN number and sleep delay
    const uint LED_PIN   =  25;
    const uint LED_DELAY = 100;

    // Setup the LED pin as an output.
    gpio_init(LED_PIN);
    gpio_set_dir(LED_PIN, GPIO_OUT);

    // Do forever...
    while (true) {
        toggle_led(LED_PIN, LED_DELAY);
    }

    // Should never get here due to infinite while-loop.
    return 0;

}
