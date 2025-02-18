#include "hardware/regs/addressmap.h"
#include "hardware/regs/io_bank0.h"
#include "hardware/regs/timer.h"
#include "hardware/regs/m0plus.h"

.syntax unified
.cpu    cortex-m0plus
.thumb
.global main_asm
.align  4

.equ    DFLT_STATE_STRT, 1            @ Specify the value to start flashing
.equ    DFLT_STATE_STOP, 0            @ Specify the value to stop flashing
.equ    DFLT_ALARM_TIME, 1000000      @ Specify the default alarm timeout

.equ    GPIO_BTN_DN_MSK, 0x00040000   @ Bit-18 for falling-edge event on GP20
.equ    GPIO_BTN_EN_MSK, 0x00400000   @ Bit-22 for falling-edge event on GP21
.equ    GPIO_BTN_UP_MSK, 0x04000000   @ Bit-26 for falling-edge event on GP22

.equ    GPIO_BTN_DN,  20              @ Specify pin for the "down" button
.equ    GPIO_BTN_EN,  21              @ Specify pin for the "enter" button
.equ    GPIO_BTN_UP,  22              @ Specify pin for the "up" button
.equ    GPIO_LED_PIN, 25              @ Specify pin for the built-in LED
.equ    GPIO_DIR_IN,   0              @ Specify input direction for a GPIO pin
.equ    GPIO_DIR_OUT,  1              @ Specify output direction for a GPIO pin

.equ    LED_VAL_ON,    1              @ Specify value that turns the LED "on"
.equ    LED_VAL_OFF,   0              @ Specify value that turns the LED "off"

.equ    GPIO_ISR_OFFSET, 0x74         @ GPIO is int #13 (vector table entry 29)
.equ    ALRM_ISR_OFFSET, 0x40         @ ALARM0 is int #0 (vector table entry 16)

@ Entry point to the ASM portion of the program
main_asm:
    ldr     R4, =LED_VAL_ON 
    ldr     R5, =DFLT_ALARM_TIME

main_loop:
    bl      led_init
    bl      btn_init
    bl      alarm_init
    bl      gpio_init
    bl      alarm_setup
    wfi

    b       main_loop


led_init:
    push    {lr}
    ldr     R0, =GPIO_LED_PIN
    bl      asm_gpio_init
    ldr     R0, =GPIO_LED_PIN
    ldr     R1, =GPIO_DIR_OUT
    bl      gpio_set_dir
    pop     {pc}

btn_init:
    push    {lr}

    // Initialize the "enter" button
    ldr     R0, =GPIO_BTN_EN
    bl      asm_gpio_init
    ldr     R0, =GPIO_BTN_EN
    ldr     R1, =GPIO_DIR_IN
    bl      gpio_set_dir
    ldr     R0, =GPIO_BTN_EN
    bl      asm_gpio_set_irq

    // Initialize the "up" button
    ldr     R0, =GPIO_BTN_UP
    bl      asm_gpio_init
    ldr     R0, =GPIO_BTN_UP
    ldr     R1, =GPIO_DIR_IN
    bl      gpio_set_dir
    ldr     R0, =GPIO_BTN_UP
    bl      asm_gpio_set_irq

    // Initialize the "down" button
    ldr     R0, =GPIO_BTN_DN
    bl      asm_gpio_init
    ldr     R0, =GPIO_BTN_DN
    ldr     R1, =GPIO_DIR_IN
    bl      gpio_set_dir
    ldr     R0, =GPIO_BTN_DN
    bl      asm_gpio_set_irq

    pop     {pc}


alarm_init:
    ldr     r3, =(PPB_BASE + M0PLUS_VTOR_OFFSET)
    ldr     r4, =(PPB_BASE + M0PLUS_NVIC_ISER_OFFSET)
    ldr     r1, [r3]
    ldr     r2, =ALRM_ISR_OFFSET
    adds    r2, r2, r1
    ldr     r0, =LED_ISR_TOGGLE
    

    ldr     r4, =(ALARM_ISR_OFFSET)
    add     r4, r4, r3


gpio_init:
    push   {lr}
    ldr     r3, =(PPB_BASE + M0PLUS_VTOR_OFFSET)
    ldr     r4, =(ALARM_ISR_OFFSET)
    add     r4, r4, r3
    
    

    bx      {lr}

.align 4
msg:    .asciz "Hello World!\n"

.data
lstate: .word   DFLT_STATE_STRT
ltimer: .word   DFLT_ALARM_TIME
