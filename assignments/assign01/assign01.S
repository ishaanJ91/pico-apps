#include "hardware/regs/addressmap.h"
#include "hardware/regs/io_bank0.h"
#include "hardware/regs/timer.h"
#include "hardware/regs/m0plus.h"

@ Initialize GPIO pin
.syntax unified 
.cpu    cortex-m0plus
.thumb
.global main_asm 
.align  4

@ Constants for default state, button masks, and timer values
.equ    DFLT_STATE_STRT, 1            @ Default state to start flashing
.equ    DFLT_STATE_STOP, 0            @ Default state to stop flashing
.equ    DFLT_ALARM_TIME, 1000000      @ Default alarm timeout in microseconds

.equ    GPIO_BTN_DN_MSK, 0x00040000   @ Mask for the "down" button (GP20)
.equ    GPIO_BTN_EN_MSK, 0x00400000   @ Mask for the "enter" button (GP21)
.equ    GPIO_BTN_UP_MSK, 0x04000000   @ Mask for the "up" button (GP22)

.equ    GPIO_BTN_DN, 20               @ GPIO pin number for the "down" button
.equ    GPIO_BTN_EN, 21               @ GPIO pin number for the "enter" button
.equ    GPIO_BTN_UP, 22               @ GPIO pin number for the "up" button
.equ    GPIO_LED_PIN, 25              @ GPIO pin number for the built-in LED
.equ    GPIO_DIR_IN, 0                @ GPIO direction for input
.equ    GPIO_DIR_OUT, 1               @ GPIO direction for output

.equ    LED_VAL_ON, 1                 @ Value to turn the LED on
.equ    LED_VAL_OFF, 0                @ Value to turn the LED off

.equ    GPIO_ISR_OFFSET, 0x74         @ Offset for GPIO interrupt
.equ    ALRM_ISR_OFFSET, 0x40         @ Offset for alarm interrupt

.equ    MAX_SLEEP_TIME, 4000000       @ Maximum sleep time (slowest blink rate)
.equ    MIN_SLEEP_TIME, 15600         @ Minimum sleep time (fastest blink rate)

@ Entry point
main_asm:
    @ Initialize LED pin first
    movs    r0, #GPIO_LED_PIN          @ Load GPIO pin for LED
    bl      asm_gpio_init              @ Call GPIO init function for LED
    movs    r0, #GPIO_LED_PIN          @ Load GPIO pin again
    movs    r1, #GPIO_DIR_OUT          @ Set pin direction to output
    bl      asm_gpio_set_dir           @ Call GPIO set direction function

    @ Initially turn the LED off
    movs    r0, #GPIO_LED_PIN          @ Load GPIO pin for LED
    movs    r1, #LED_VAL_OFF           @ Set LED to off state
    bl      asm_gpio_put               @ Call GPIO put function to set LED

    @ Initialize interrupt systems
    bl      timer_intrpt_init          @ Call function to initialize timer interrupt
    bl      gpio_intrpt_setup          @ Call function to setup GPIO interrupt
    
    @ Initialize button pins
    bl      button_setup               @ Call function to setup button GPIOs

@ Main loop
central_loop:
    bl      configure_alarm            @ Call function to configure alarm for flashing
    wfi                                @ Wait for interrupt (low-power mode)
    b       central_loop               @ Repeat indefinitely

@ Setup button GPIOs and enable interrupts
button_setup:
    push    {lr}                       @ Save link register to stack

    @ Initialize enter button
    movs    r0, #GPIO_BTN_EN           @ Load GPIO pin for enter button
    bl      asm_gpio_init              @ Call GPIO init function for enter button
    movs    r0, #GPIO_BTN_EN           @ Load GPIO pin again
    movs    r1, #GPIO_DIR_IN           @ Set pin direction to input
    bl      asm_gpio_set_dir           @ Call GPIO set direction function
    movs    r0, #GPIO_BTN_EN           @ Load GPIO pin for enter button
    bl      asm_gpio_set_irq           @ Enable interrupt for enter button

    @ Initialize up button (same as enter button)
    movs    r0, #GPIO_BTN_UP           @ Load GPIO pin for up button
    bl      asm_gpio_init              @ Call GPIO init function for up button
    movs    r0, #GPIO_BTN_UP           @ Load GPIO pin again
    movs    r1, #GPIO_DIR_IN           @ Set pin direction to input
    bl      asm_gpio_set_dir           @ Call GPIO set direction function
    movs    r0, #GPIO_BTN_UP           @ Load GPIO pin for up button
    bl      asm_gpio_set_irq           @ Enable interrupt for up button

    @ Initialize down button (same as up button)
    movs    r0, #GPIO_BTN_DN           @ Load GPIO pin for down button
    bl      asm_gpio_init              @ Call GPIO init function for down button
    movs    r0, #GPIO_BTN_DN           @ Load GPIO pin again
    movs    r1, #GPIO_DIR_IN           @ Set pin direction to input
    bl      asm_gpio_set_dir           @ Call GPIO set direction function
    movs    r0, #GPIO_BTN_DN           @ Load GPIO pin for down button
    bl      asm_gpio_set_irq           @ Enable interrupt for down button

    pop     {pc}                       @ Restore link register and return

@ Initialize timer interrupt
timer_intrpt_init:
    push    {lr}                       @ Save link register to stack

    @ Setup vector table entry for timer interrupt
    ldr     r2, =PPB_BASE + M0PLUS_VTOR_OFFSET
    ldr     r1, [r2]
    movs    r2, #ALRM_ISR_OFFSET
    add     r2, r1
    ldr     r0, =timer_event_handler   
    str     r0, [r2]                  

    @ Clear pending and enable timer interrupt
    movs    r0, #1
    ldr     r2, =PPB_BASE + M0PLUS_NVIC_ICPR_OFFSET
    str     r0, [r2]
    ldr     r2, =PPB_BASE + M0PLUS_NVIC_ISER_OFFSET
    str     r0, [r2]

    pop     {pc}                       @ Restore link register and return

@ Setup GPIO interrupt
gpio_intrpt_setup:
    push    {lr}                       @ Save link register to stack

    @ Setup vector table entry for GPIO interrupt
    ldr     r2, =PPB_BASE + M0PLUS_VTOR_OFFSET
    ldr     r1, [r2]
    movs    r2, #GPIO_ISR_OFFSET
    add     r2, r1
    ldr     r0, =button_event_handler  
    str     r0, [r2]                  

    @ Clear pending GPIO interrupts in NVIC
    ldr     r0, =PPB_BASE + M0PLUS_NVIC_ICPR_OFFSET
    movs    r1, #1
    lsls    r1, r1, #13               
    str     r1, [r0]

    @ Enable GPIO interrupts in NVIC
    ldr     r0, =PPB_BASE + M0PLUS_NVIC_ISER_OFFSET
    movs    r1, #1
    lsls    r1, r1, #13                
    str     r1, [r0]

    pop     {pc}                       @ Restore link register and return

@ Timer event handler
.thumb_func
timer_event_handler:
    push    {lr}                       @ Save link register to stack

    @ Check if LED flashing is enabled
    ldr     r0, =lstate
    ldr     r1, [r0]
    cmp     r1, #DFLT_STATE_STOP       @ Compare if LED is in stop state
    beq     skip_toggle                @ If not flashing, skip toggling

    @ If enabled, print message and toggle LED
    ldr     r0, =toggle_msg
    bl      printf                     @ Print "LED should be toggling"
    bl      toggle_led                 @ Call function to toggle LED
    b       timer_cleanup              @ Proceed to cleanup

skip_toggle:
    @ If disabled, print off message
    ldr     r0, =off_msg
    bl      printf                     @ Print "LED should be off"

timer_cleanup:
    @ Clear the timer interrupt
    ldr     r2, =TIMER_BASE + TIMER_INTR_OFFSET
    movs    r1, #1
    str     r1, [r2]                   @ Clear interrupt flag
    
    pop     {pc}                       @ Restore link register and return

@ Toggle LED state
toggle_led:
    push    {lr}                       @ Save link register to stack
    
    movs    r0, #GPIO_LED_PIN          @ Read current LED state
    bl      asm_gpio_get               @ Get current state of LED

    cmp     r0, #LED_VAL_OFF           @ Toggle based on current state
    beq     turn_on_led                @ If off, turn it on

turn_off_led:
    movs    r1, #LED_VAL_OFF           @ Set LED state to off
    b       update_led                 @ Update LED with new state

turn_on_led:
    movs    r1, #LED_VAL_ON            @ Set LED state to on

update_led:
    movs    r0, #GPIO_LED_PIN          @ Update LED with new state
    bl      asm_gpio_put               @ Call GPIO put to set LED state

    pop     {pc}                       @ Restore link register and return

@ Configure the timer alarm
configure_alarm:
    movs    r1, #1                     @ Set alarm enable bit
    ldr     r2, =TIMER_BASE + TIMER_INTE_OFFSET
    str     r1, [r2]                   @ Enable timer interrupt

    ldr     r2, =TIMER_BASE + TIMER_TIMELR_OFFSET
    ldr     r1, [r2]                   @ Load current timer value

    ldr     r3, =ltimer                @ Add delay from ltimer
    ldr     r0, [r3]                   @ Load delay value from ltimer
    add     r1, r0                     @ Add delay to current time

    ldr     r2, =TIMER_BASE + TIMER_ALARM0_OFFSET
    str     r1, [r2]                   @ Set timer alarm

    bx      lr                         @ Return from function

@ Button event handler
.thumb_func
button_event_handler:
    push    {lr}                       @ Save link register to stack

    
    ldr     r0, =IO_BANK0_BASE         @ Read and clear the interrupt status
    ldr     r1, =IO_BANK0_INTR2_OFFSET
    ldr     r2, [r0, r1]               @ Load interrupt status
    str     r2, [r0, r1]               @ Clear interrupt status

    ldr     r3, =GPIO_BTN_DN_MSK
    tst     r3, r2                     @ Check if down button was pressed
    bne     down_button_handler

    ldr     r3, =GPIO_BTN_EN_MSK
    tst     r3, r2                     @ Check if enter button was pressed
    bne     enter_button_handler

    ldr     r3, =GPIO_BTN_UP_MSK
    tst     r3, r2                     @ Check if up button was pressed
    bne     up_button_handler

    b       button_handler_exit

@ Down button handler - slows down blinking or resets timer
down_button_handler:
    ldr     r0, =down_pressed
    bl      printf                     @ Print message for down button press

    ldr     r1, =lstate
    ldr     r0, [r1]                   @ Load current LED state
    cmp     r0, #DFLT_STATE_STRT       @ Check if LED is flashing
    beq     slow_down                  @ If flashing, slow down the rate
    b       reset_handler              @ If not flashing, reset timer

slow_down:
    ldr     r0, =double_msg
    bl      printf                     @ Print message for slower rate
    
    ldr     r1, =ltimer
    ldr     r0, [r1]                   @ Load current timer value
    lsls    r0, r0, #1                 @ Double the timer value (slower blink)
    
    ldr     r2, =MAX_SLEEP_TIME
    cmp     r0, r2                     @ Compare with maximum sleep time
    bls     down_store                 @ If within range, store the value
    
    ldr     r0, =MAX_SLEEP_TIME        @ Cap at maximum value
    
down_store:
    str     r0, [r1]                   @ Store new value to ltimer
    b       button_handler_exit

@ Up button handler - speeds up blinking or resets timer
up_button_handler:
    ldr     r0, =up_pressed
    bl      printf                     @ Print message for up button press

    ldr     r1, =lstate
    ldr     r0, [r1]                   @ Load current LED state
    cmp     r0, #DFLT_STATE_STRT       @ Check if LED is flashing
    beq     speed_up                   @ If flashing, speed up the rate
    b       reset_handler              @ If not flashing, reset timer

speed_up:
    ldr     r0, =halve_msg
    bl      printf                     @ Print message for faster rate
    
    ldr     r1, =ltimer
    ldr     r0, [r1]                   @ Load current timer value
    lsrs    r0, r0, #1                 @ Halve the timer value (faster blink)
    
    ldr     r2, =MIN_SLEEP_TIME
    cmp     r0, r2                     @ Compare with minimum sleep time
    bhs     up_store                   @ If within range, store the value
    
    ldr     r0, =MIN_SLEEP_TIME        @ Cap at minimum value
    
up_store:
    str     r0, [r1]                   @ Store new value to ltimer
    b       button_handler_exit

@ Enter button handler - toggles LED state
enter_button_handler:
    ldr     r0, =enter_pressed
    bl      printf                     @ Print message for enter button press

    ldr     r1, =lstate
    ldr     r0, [r1]                   @ Load current LED state
    movs    r2, #1
    eors    r0, r0, r2                 @ Toggle LED state (XOR)
    str     r0, [r1]                   @ Store new state

    
    cmp     r0, #0                     @ If turning off, ensure LED is off
    bne     button_handler_exit
    
    movs    r0, #GPIO_LED_PIN
    movs    r1, #LED_VAL_OFF           @ Set LED to off state
    bl      asm_gpio_put               @ Call GPIO put to turn LED off

    b       button_handler_exit


@ Reset timer to default value
reset_handler:
    ldr     r0, =reset_msg
    bl      printf                     @ Print reset message

    ldr     r1, =ltimer                @ Load ltimer address directly into r1
    ldr     r0, =DFLT_ALARM_TIME       @ Load default time into r0
    str     r0, [r1]                   @ Store default time to ltimer

    b       button_handler_exit

button_handler_exit:
    pop     {pc}                       @ Restore link register and return

.align 4
msg:            .asciz "Hello World!\n"
down_pressed:   .asciz "GPIO20 button was pressed\n"
up_pressed:     .asciz "GPIO22 button was pressed\n"
enter_pressed:  .asciz "GPIO21 button was pressed\n"

halve_msg:      .asciz "Flashing rate doubled\n"
double_msg:     .asciz "Flashing rate halved\n"
reset_msg:      .asciz "Flashing rate was reset\n"

toggle_msg:     .asciz "LED should be on\n"
off_msg:        .asciz "LED should be off\n"

.data 
lstate: .word   DFLT_STATE_STOP         @ Initialize LED state to stop
ltimer: .word   DFLT_ALARM_TIME         @ Initialize timer to default value
