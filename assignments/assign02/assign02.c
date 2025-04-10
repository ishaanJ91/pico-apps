#include "hardware/clocks.h"
#include "hardware/gpio.h"
#include "hardware/pio.h"
#include "pico/stdlib.h"
#include "ws2812.pio.h"
#include <hardware/timer.h>
#include <hardware/watchdog.h>
#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
// #include <pico/time.h>

#define IS_RGBW true  // Will use RGBW format
#define NUM_PIXELS 1  // There is 1 WS2812 device in the chain
#define WS2812_PIN 28 // The GPIO pin that the WS2812 connected to

// Must declare the assembly entry point before use.
void init_asm();
bool attempt_character_input();

extern bool button_pressed;
extern uint32_t last_gpio_interupt;
extern bool morse_input_active;
extern uint32_t character_input_index;
extern char character_input[4];
extern uint32_t lives;
uint32_t lives = 3;

// Global variable to track the last time any activity was detected
volatile uint32_t last_activity_time = 0;

char *morse_index_array[] = {
    ".-  ", "-...", "-.-.", "-.. ", ".   ", "..-.", "--. ", "....", "..  ",
    ".---", "-.- ", ".-..", "--  ", "-.  ", "--- ", ".--.", "--.-", ".-. ",
    "... ", "-   ", "..- ", "...-", ".-- ", "-..-", "-.--", "--.."};

char *words[] = {"APPLE",  "TABLE",  "CHAIR",  "PENCIL", "GUITAR", "PLANET",
                 "OCEAN",  "FOREST", "WINDOW", "BRIDGE", "ORANGE", "BANANA",
                 "ROCKET", "CAMERA", "CASTLE", "DRAGON", "SILVER", "PIRATE",
                 "TUNNEL", "CANDLE", "SUNSET", "DESERT", "GARDEN", "LAPTOP",
                 "FLAMES", "HELMET", "JUMPER", "MARBLE", "ORCHID", "PUZZLE",
                 "QUIVER", "RABBIT", "SPHERE", "TROPHY", "VELVET", "WALNUT",
                 "YONDER", "ZIPPER", "ANCHOR", "BEACON", "CACTUS", "DANCER",
                 "ENGINE", "FOSSIL", "GLIDER", "HAMMER", "ICICLE", "JIGSAW",
                 "KITTEN", "LADDER"};

// Initialise a GPIO pin – see SDK for detail on gpio_init()
void asm_gpio_init(uint pin) { gpio_init(pin); }
// Set direction of a GPIO pin – see SDK for detail on gpio_set_dir()
void asm_gpio_set_dir(uint pin, bool out) { gpio_set_dir(pin, out); }
// Get the value of a GPIO pin – see SDK for detail on gpio_get()
bool asm_gpio_get(uint pin) { return gpio_get(pin); }
// Set the value of a GPIO pin – see SDK for detail on gpio_put()
void asm_gpio_put(uint pin, bool value) { gpio_put(pin, value); }
// Enable falling-edge interrupt – see SDK for detail on gpio_set_irq_enabled()
// void asm_gpio_set_irq(uint pin)
// {
//   gpio_set_irq_enabled(pin, GPIO_IRQ_EDGE_FALL, true);
//   gpio_set_irq_enabled(pin, GPIO_IRQ_EDGE_RISE, true);
// }
void gpio_callback(uint gpio, uint32_t events) {
  printf("GPIO interrupt detected on pin %d\n", gpio);
  // Update the last activity time whenever a GPIO interrupt occurs
  last_activity_time = time_us_32() / 1000;
  // Update the watchdog whenever there's button activity
  watchdog_update();
}

void asm_gpio_set_irq(uint pin) {
  // Register the callback function
  gpio_set_irq_enabled_with_callback(
      pin, GPIO_IRQ_EDGE_FALL | GPIO_IRQ_EDGE_RISE, true, &gpio_callback);
}
// prints an int
void print_int(uint num) { printf("number: %d\n", num); }

// takes
bool is_morsecode_valid(char letter) {
  char *true_morse = morse_index_array[letter - 'A'];
  // printf("true: %s\n", true_morse);
  // printf("attempt : %s\n", character_input);
  return true_morse[0] == character_input[0] &&
         true_morse[1] == character_input[1] &&
         true_morse[2] == character_input[2] &&
         true_morse[3] == character_input[3];
}

// Fix the watchdog timer initialization function
void init_watchdog() {
  // Initialize the watchdog timer with a timeout of 9 seconds (in ms)
  watchdog_enable(9000, 1);
  printf("Watchdog timer initialized with 9 seconds timeout.\n");
  // Add a delay to give the user time to read the message
  sleep_ms(1000);
  
  // Initialize the last activity time
  last_activity_time = time_us_32() / 1000;
}

// Fix the watchdog timer update function
void update_watchdog() {
  // Update the watchdog timer to prevent it from resetting the system
  watchdog_update();
  // Update the last activity time
  last_activity_time = time_us_32() / 1000;
}

static inline void put_pixel(uint32_t pixel_grb) {
  pio_sm_put_blocking(pio0, 0, pixel_grb << 8u);
}

static inline uint32_t urgb_u32(uint8_t r, uint8_t g, uint8_t b) {
  return ((uint32_t)(r) << 8) | ((uint32_t)(g) << 16) | (uint32_t)(b);
}

void led() {
  // Initialise the PIO interface with the WS2812 code
  PIO pio = pio0;
  uint offset = pio_add_program(pio, &ws2812_program);
  ws2812_program_init(pio, 0, offset, WS2812_PIN, 800000, IS_RGBW);

  while (true) {
    if (lives == 0) {
      // Set the color to red at half intensity
      put_pixel(urgb_u32(0x7F, 0x00, 0x00));
      sleep_ms(500);
    } else if (lives == 1) {
      // Set the color to orange at half intensity
      put_pixel(urgb_u32(0xFF, 0x5A, 0x00));
      sleep_ms(500);
    } else if (lives == 2) {
      // Set the color to yellow at half intensity
      put_pixel(urgb_u32(0x7F, 0x7F, 0x00));
      sleep_ms(500);
    } else {
      // Set the color to green at half intensity
      put_pixel(urgb_u32(0x00, 0x7F, 0x00));
      sleep_ms(500);
    }
  }
}

void welcome_banner() {
  // Display the banner in sections with delays between them
  const char *welcome_header = 
    "+-------------------------------------------+\n"
    "|     CSU23021-GR13 Welcome to our game!    |\n"
    "+-------------------------------------------+\n";
  
  const char *learn_section = 
    "|                                           |\n"
    "|  #       #######    #    ######  #     #  |\n"
    "|  #       #         # #   #     # ##    #  |\n"
    "|  #       #        #   #  #     # # #   #  |\n"
    "|  #       ######  #     # ######  #  #  #  |\n"
    "|  #       #       ####### #   #   #   # #  |\n"
    "|  #       #       #     # #    #  #    ##  |\n"
    "|  ####### ####### #     # #     # #     #  |\n"
    "|                                           |\n";
  
  const char *morse_section = 
    "|  #     # ####### ######   #####  #######  |\n"
    "|  ##   ## #     # #     # #     # #        |\n"
    "|  # # # # #     # #     # #       #        |\n"
    "|  #  #  # #     # ######   #####  ######   |\n"
    "|  #     # #     # #   #         # #        |\n"
    "|  #     # #     # #    #  #     # #        |\n"
    "|  #     # ####### #     #  #####  #######  |\n"
    "|                                           |\n";
  
  const char *code_section = 
    "|   #####  ####### #####   ####### #        |\n"
    "|  #     # #     # #    #  #       #        |\n"
    "|  #       #     # #     # #       #        |\n"
    "|  #       #     # #     # ######  #        |\n"
    "|  #       #     # #     # #       #        |\n"
    "|  #     # #     # #    #  #                |\n"
    "|   #####  ####### #####   ####### #        |\n"
    "|                                           |\n"
    "+-------------------------------------------+\n"
    "\n";

  // Display each section with a delay
  printf("%s", welcome_header);
  sleep_ms(800);  // Wait for 800ms
  
  printf("%s", learn_section);
  sleep_ms(600);  // Wait for 600ms
  
  printf("%s", morse_section);
  sleep_ms(600);  // Wait for 600ms
  
  printf("%s", code_section);
  sleep_ms(1000);  // Wait for 1 second after the full banner
}

// Wrapper for attempt_character_input that updates activity time
bool attempt_character_input_with_watchdog() {
  bool result = attempt_character_input();
  if (result) {
    // If character input was successful, update the last activity time
    last_activity_time = time_us_32() / 1000;
    // Also update the watchdog
    watchdog_update();
  }
  return result;
}

/*
 * Main entry point for the code - simply calls the main assembly function.
 */
void run_main_logic() {
  printf("---LEVEL 1----\n");

  for (int j = 0; j < 5; j++) {
    char random_character = 'A' + (rand() % 27);
    printf("produce the morse code for %c (%s)\n", random_character,
           morse_index_array[random_character - 'A']);
    attempt_character_input_with_watchdog();
    printf("\n");
    if (is_morsecode_valid(random_character)) {
      printf("correct\n\n");
    } else {
      printf("not correct, you lose!!\n");
      return;
    }
  }

  for (int j = 0; j < 5; j++) {
    char random_character = 'A' + (rand() % 27);
    printf("---LEVEL 2----\n");
    printf("produce the morse code for %c\n", random_character);
    attempt_character_input_with_watchdog();
    printf("\n");
    if (is_morsecode_valid(random_character)) {
      printf("correct\n\n");
    } else {
      printf("not correct, you lose!!\n");
      return;
    }
  }

  for (int j = 0; j < 5; j++) {
    char *random_word = words[(rand() % 51)];
    printf("---LEVEL 3----\n");
    printf("produce the morse code for %s (", random_word);
    for (int i = 0; i < strlen(random_word); i++) {
      printf("%s ", morse_index_array[random_word[i] - 'A']);
    }
    printf(")\n");
    for (int i = 0; i < strlen(random_word); i++) {
      attempt_character_input_with_watchdog();
      if (!is_morsecode_valid(random_word[i])) {
        printf("\nnot correct, you lose!!\n");
        return;
      } else {
        printf(" ");
      }
    }
    printf("\ncorrect\n\n");
  }

  for (int j = 0; j < 5; j++) {
    char *random_word = words[(rand() % 51)];
    printf("---LEVEL 4----\n");
    printf("produce the morse code for %s\n", random_word);
    for (int i = 0; i < strlen(random_word); i++) {
      attempt_character_input_with_watchdog();
      if (!is_morsecode_valid(random_word[i])) {
        printf("\nnot correct, you lose!!\n");
        return;
      } else {
        printf(" ");
      }
    }
    printf("\ncorrect\n\n");
  }

  printf("well done! you beat the game :)");
}
/*
 * Main entry point for the code - simply calls the main assembly function.
 */
int main() {
  stdio_init_all(); // Initialize all basic IO
  sleep_ms(2000);   // Wait for serial connection to stabilize
  
  // Check if the system was rebooted by the watchdog
  if (watchdog_caused_reboot()) {
    printf("System restarted due to watchdog timer timeout.\n");
    // Add a delay to give the user time to read the message
    sleep_ms(1500);
  }
  
  // Initialize the watchdog timer
  init_watchdog();
  
  // Display welcome banner
  welcome_banner();
  
  // Initialize assembly code
  init_asm();
  
  // Main game loop
  while (true) {
    // Get current time in milliseconds
    uint32_t current_time = time_us_32() / 1000;
    
    // Check if we're in an active game state
    if (morse_input_active) {
      // If we're in an active game state, check if it's been more than 8 seconds since last activity
      if (current_time - last_activity_time > 8000) {
        // If it's been more than 8 seconds, don't update the watchdog and let it reset the system
        // This is intentional - we want the watchdog to reset if no input for 9 seconds
      } else {
        // Otherwise, update the watchdog
        watchdog_update();
      }
    } else {
      // If we're not in an active game state, always update the watchdog
      watchdog_update();
    }
    
    // Run the main game logic
    run_main_logic();
    
    // Prevent busy looping
    sleep_ms(100);
    
    // Update the watchdog here to prevent resets during normal program execution
    // but only if we're not in an active game state or if there's been recent activity
    if (!morse_input_active || (current_time - last_activity_time <= 8000)) {
      watchdog_update();
    }
  }
  
  return 0;
}

