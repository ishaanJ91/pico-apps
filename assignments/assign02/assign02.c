#include "hardware/gpio.h"
#include "pico/stdlib.h"
#include <stdio.h>
// Must declare the main assembly entry point before use.
void main_asm();

/*
 * Main entry point for the code - simply calls the main assembly function.
 */
int main() {
  stdio_init_all(); // Initialise all basic IO
  sleep_ms(2000);
  const char *welcome_msg = "+-------------------------------------------+\n"
                            "|     CSU23021-GR21 Welcome to our game!    |\n"
                            "+-------------------------------------------+\n"
                            "|                                           |\n"
                            "|  #       #######    #    ######  #     #  |\n"
                            "|  #       #         # #   #     # ##    #  |\n"
                            "|  #       #        #   #  #     # # #   #  |\n"
                            "|  #       ######  #     # ######  #  #  #  |\n"
                            "|  #       #       ####### #   #   #   # #  |\n"
                            "|  #       #       #     # #    #  #    ##  |\n"
                            "|  ####### ####### #     # #     # #     #  |\n"
                            "|                                           |\n"
                            "|  #     # ####### ######   #####  #######  |\n"
                            "|  ##   ## #     # #     # #     # #        |\n"
                            "|  # # # # #     # #     # #       #        |\n"
                            "|  #  #  # #     # ######   #####  ######   |\n"
                            "|  #     # #     # #   #         # #        |\n"
                            "|  #     # #     # #    #  #     # #        |\n"
                            "|  #     # ####### #     #  #####  #######  |\n"
                            "|                                           |\n"
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
  printf("%s", welcome_msg);
  main_asm();
  return (0);
}
