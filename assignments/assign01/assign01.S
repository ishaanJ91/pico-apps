#include "hardware/regs/addressmap.h"
#include "hardware/regs/io_bank0.h"
#include "hardware/regs/timer.h"
#include "hardware/regs/m0plus.h"

.syntax unified
.cpu    cortex-m0plus
.thumb
.global main_asm
.align  4

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
    movs    r0, #GPIO_LED_PIN
    bl      asm_gpio_init             @ Initialize GPIO for the LED
    movs    r0, #GPIO_LED_PIN
    movs    r1, #GPIO_DIR_OUT
    bl      asm_gpio_set_dir          @ Set GPIO direction to output
    
    @ Initialize interrupt systems
    bl      timer_intrpt_init
    bl      gpio_intrpt_setup
    
    @ Initialize button pins
    bl      button_setup
    
    @ Initially turn the LED on
    movs    r0, #GPIO_LED_PIN
    movs    r1, #LED_VAL_ON
    bl      asm_gpio_put

@ Main loop
central_loop:
    bl      configure_alarm           @ Configure the alarm for flashing
    wfi                              @ Wait for interrupt
    b       central_loop              @ Repeat indefinitely

@ Setup button GPIOs and enable interrupts
button_setup:
    push    {lr}

    @ Initialize enter button
    movs    r0, #GPIO_BTN_EN
    bl      asm_gpio_init
    movs    r0, #GPIO_BTN_EN
    movs    r1, #GPIO_DIR_IN
    bl      asm_gpio_set_dir
    movs    r0, #GPIO_BTN_EN
    bl      asm_gpio_set_irq

    @ Initialize up button
    movs    r0, #GPIO_BTN_UP
    bl      asm_gpio_init
    movs    r0, #GPIO_BTN_UP
    movs    r1, #GPIO_DIR_IN
    bl      asm_gpio_set_dir
    movs    r0, #GPIO_BTN_UP
    bl      asm_gpio_set_irq

    @ Initialize down button
    movs    r0, #GPIO_BTN_DN
    bl      asm_gpio_init
    movs    r0, #GPIO_BTN_DN
    movs    r1, #GPIO_DIR_IN
    bl      asm_gpio_set_dir
    movs    r0, #GPIO_BTN_DN
    bl      asm_gpio_set_irq

    pop     {pc}

@ Initialize timer interrupt
timer_intrpt_init:
    push    {lr}
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
    
    pop     {pc}

@ Setup GPIO interrupt
gpio_intrpt_setup:
    push    {lr}
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
    lsls    r1, r1, #13                @ Shift 1 to bit 13 for IRQ 13
    str     r1, [r0]

    @ Enable GPIO interrupts in NVIC
    ldr     r0, =PPB_BASE + M0PLUS_NVIC_ISER_OFFSET
    movs    r1, #1
    lsls    r1, r1, #13                @ Shift 1 to bit 13 for IRQ 13
    str     r1, [r0]

    pop     {pc}

@ Timer event handler
.thumb_func
timer_event_handler:
    push    {lr}
    
    @ Check if LED flashing is enabled
    ldr     r0, =lstate
    ldr     r1, [r0]
    cmp     r1, #DFLT_STATE_STOP
    beq     skip_toggle

    @ If enabled, print message and toggle LED
    ldr     r0, =toggle_msg
    bl      printf
    bl      toggle_led
    b       timer_cleanup

skip_toggle:
    @ If disabled, print off message
    ldr     r0, =off_msg
    bl      printf

timer_cleanup:
    @ Clear the timer interrupt
    ldr     r2, =TIMER_BASE + TIMER_INTR_OFFSET
    movs    r1, #1
    str     r1, [r2]
    
    pop     {pc}

@ Toggle LED state
toggle_led:
    push    {lr}
    
    @ Read current LED state
    movs    r0, #GPIO_LED_PIN
    bl      asm_gpio_get
    
    @ Toggle based on current state
    cmp     r0, #LED_VAL_OFF
    beq     turn_on_led

turn_off_led:
    movs    r1, #LED_VAL_OFF
    b       update_led

turn_on_led:
    movs    r1, #LED_VAL_ON

update_led:
    @ Update LED with new state
    movs    r0, #GPIO_LED_PIN
    bl      asm_gpio_put
    
    pop     {pc}

@ Configure the timer alarm
configure_alarm:
    @ Enable timer interrupt
    movs    r1, #1
    ldr     r2, =TIMER_BASE + TIMER_INTE_OFFSET
    str     r1, [r2]

    @ Get current time
    ldr     r2, =TIMER_BASE + TIMER_TIMELR_OFFSET
    ldr     r1, [r2]

    @ Add delay from ltimer
    ldr     r3, =ltimer
    ldr     r0, [r3]
    add     r1, r0

    @ Set alarm
    ldr     r2, =TIMER_BASE + TIMER_ALARM0_OFFSET
    str     r1, [r2]

    bx      lr

@ Button event handler
.thumb_func
button_event_handler:
    push    {lr}

    @ Read and clear the interrupt status
    ldr     r0, =IO_BANK0_BASE
    ldr     r1, =IO_BANK0_INTR2_OFFSET
    ldr     r2, [r0, r1]
    str     r2, [r0, r1]

    @ Check which button was pressed
    ldr     r3, =GPIO_BTN_DN_MSK
    tst     r3, r2
    bne     down_button_handler

    ldr     r3, =GPIO_BTN_EN_MSK
    tst     r3, r2
    bne     enter_button_handler

    ldr     r3, =GPIO_BTN_UP_MSK
    tst     r3, r2
    bne     up_button_handler

    b       button_handler_exit

@ Down button handler - slows down blinking (increases timer)
down_button_handler:
    ldr     r0, =down_pressed
    bl      printf

    @ Only change speed if LED is in flashing state
    ldr     r1, =lstate
    ldr     r0, [r1]
    cmp     r0, #1
    bne     reset_handler

    @ Get current timer value and double it
    ldr     r0, =double_msg
    bl      printf
    
    ldr     r1, =ltimer
    ldr     r0, [r1]
    movs    r2, #1
    lsls    r0, r0, r2                @ Double the timer value (slower blink)
    
    @ Check if over maximum
    ldr     r2, =MAX_SLEEP_TIME
    cmp     r0, r2
    str     r0, [r1]                  @ Store new value
    bls     button_handler_exit
    
    @ Cap at maximum value
    ldr     r0, =MAX_SLEEP_TIME
    str     r0, [r1]
    b       button_handler_exit

@ Enter button handler - toggles LED state
enter_button_handler:
    ldr     r0, =enter_pressed
    bl      printf

    @ Toggle LED state using XOR
    ldr     r1, =lstate
    ldr     r0, [r1]
    movs    r2, #1
    eors    r0, r0, r2
    str     r0, [r1]
    
    @ If turning off, ensure LED is off
    cmp     r0, #0
    bne     button_handler_exit
    
    movs    r0, #GPIO_LED_PIN
    movs    r1, #LED_VAL_OFF
    bl      asm_gpio_put

    b       button_handler_exit

@ Up button handler - speeds up blinking (decreases timer)
up_button_handler:
    ldr     r0, =up_pressed
    bl      printf

    @ Only change speed if LED is in flashing state
    ldr     r1, =lstate
    ldr     r0, [r1]
    cmp     r0, #1
    bne     reset_handler

    @ Get current timer value and halve it
    ldr     r0, =halve_msg
    bl      printf
    
    ldr     r1, =ltimer
    ldr     r0, [r1]
    movs    r2, #1
    lsrs    r0, r0, r2                @ Halve the timer value (faster blink)
    
    @ Check if under minimum
    ldr     r2, =MIN_SLEEP_TIME
    cmp     r0, r2
    str     r0, [r1]                  @ Store new value
    bhs     button_handler_exit
    
    @ Cap at minimum value
    ldr     r0, =MIN_SLEEP_TIME
    str     r0, [r1]
    b       button_handler_exit

@ Reset timer to default value
reset_handler:
    ldr     r0, =reset_msg
    bl      printf

    ldr     r0, =ltimer
    ldr     r1, =DFLT_ALARM_TIME
    str     r1, [r0]

    b       button_handler_exit

button_handler_exit:
    pop     {pc}

.align 4
down_pressed:   .asciz "GPIO20 button was pressed\n"
up_pressed:     .asciz "GPIO22 button was pressed\n"
enter_pressed:  .asciz "GPIO21 button was pressed\n"

halve_msg:      .asciz "Flashing rate doubled\n"
double_msg:     .asciz "Flashing rate cut in half\n"
reset_msg:      .asciz "Flashing rate was reset\n"

toggle_msg:     .asciz "LED should be toggling\n"
off_msg:        .asciz "LED should be off\n"

.section .data
lstate: .word   DFLT_STATE_STRT
ltimer: .word   DFLT_ALARM_TIME