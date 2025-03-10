#include "hardware/regs/addressmap.h"
#include "hardware/regs/m0plus.h"

.syntax unified                 @ Specify unified assembly syntax
.cpu    cortex-m0plus           @ Specify CPU type is Cortex M0+
.thumb                          @ Specify thumb assembly for RP2040
.global main_asm                @ Provide program starting address to the linker
.align 4                        @ Specify code alignment

.equ    SLEEP_TIME, 500         @ Specify the sleep time (in ms)
.equ    LED_GPIO_PIN, 25        @ Specify the pin that the LED is connected to
.equ    LED_GPIO_OUT, 1         @ Specify the direction of the GPIO pin
.equ    LED_VALUE_ON, 1         @ Specify the value that turns the LED "on"
.equ    LED_VALUE_OFF, 0        @ Specify the value that turns the LED "off"
.equ    SVC_ISR_OFFSET, 0x2C    @ The SVC is entry 11 in the vector table
.equ    SVC_MAX_INSTRS, 0x01    @ Maximum allowed SVC subroutines

@ Entry point to the ASM portion of the program
main_asm:
    bl      install_svc_isr     @ Install the SVC interrupt service routine
    bl      init_gpio_led       @ Initialise the GPIO LED pin

loop:
    svc     #0                  @ Call the SVC ISR with value 0 (turns on LED)
    nop                         @ Add a no-op instruction for alignment after SVC
    bl      do_sleep            @ Short pause before proceeding
    svc     #1                  @ Call the SVC ISR with value 1 (turns off LED)
    nop                         @ Add a no-op instruction for alignment after SVC
    bl      do_sleep            @ Add a short pause before proceeding
    b       loop                @ Always jump back to the start of the loop

@ Subroutine used to introduce a short delay in the application
do_sleep:
    push    {lr}                 @ Save the link register
    ldr     r0, =SLEEP_TIME      @ Load the sleep time into register r0
    bl      sleep_ms             @ Call the sleep_ms function
    pop     {pc}                 @ Return from subroutine

@ Subroutine used to initialise the PI Pico built-in LED
init_gpio_led:
    push    {lr}                       @ Save the link register
    movs    r0, #LED_GPIO_PIN          @ Load GPIO pin for LED
    bl      asm_gpio_init              @ Call GPIO init function for LED
    movs    r0, #LED_GPIO_PIN          @ Load GPIO pin again
    movs    r1, #LED_GPIO_OUT          @ Set pin direction to output
    bl      asm_gpio_set_dir           @ Call GPIO set direction function
    pop     {pc}                       @ Return from subroutine

@ Subroutine used to install the SVC interrupt service handler
install_svc_isr:
    ldr     r2, =(PPB_BASE + M0PLUS_VTOR_OFFSET)    @ Load the address of the vector table
    ldr     r1, [r2]                                @ Load the current value of the vector table
    movs    r2, #SVC_ISR_OFFSET                     @ Calculate the offset for the SVC interrupt
    add     r2, r1                                  @ Add the offset to the vector table address
    ldr     r0, =svc_isr                            @ Load the address of the SVC interrupt service routine
    str     r0, [r2]                                @ Store the address of the SVC interrupt service routine in the vector table
    bx      lr                                      @ Return from subroutine

 
@ SVC interrupt service handler routine
.thumb_func                     @ Required for all interrupt service routines
svc_isr:
    push    {lr}                @ Save the link register
    ldr     r0, [sp, #0x1C]     @ Load the value of the stacked PC
    subs    r0, #0x2            @ Adjust the PC to the instruction that caused the SVC
    ldr     r0, [r0]            @ Load the instruction that caused the SVC
    ldr     r1, =#0xFF          @ Mask to extract the SVC number
    ands    r0, r1              @ Extract the SVC number
    cmp     r0, #SVC_MAX_INSTRS @ Check if the SVC number is within the allowed range
    bgt     svc_done            @ If not, return from the SVC
    adr     r1, svc_jmptbl      @ Load the address of the jump table
    lsls    r0, #2              @ Multiply the SVC number by 4 to get the offset
    ldr     r1, [r1, r0]        @ Load the address of the SVC function
    mov     pc, r1              @ Branch to the SVC function

svc_done:
    pop     {pc}                @ Restore the link register and return

@ First function of SVC subroutine - turn on the LED
svc_num0:
    movs    r1, #LED_VALUE_ON       @ Load the value for LED on into r1
    movs    r0, #LED_GPIO_PIN       @ Load the gpio pin into r0
    bl      asm_gpio_put            @ Call the function to set the LED
    b       svc_done                @ Branch back to the main ISR when done


@ Second function of SVC subroutine - turn off the LED
svc_num1:
    movs    r1, #LED_VALUE_OFF      @ Load the value for LED off into r1
    movs    r0, #LED_GPIO_PIN       @ Load the gpio pin into r0
    bl      asm_gpio_put            @ Call the function to set the LED
    b       svc_done                @ Branch back to the main ISR when done

@ SVC function entry jump table.
.align 2

svc_jmptbl:
    .word svc_num0              @ Entry zero goes to SVC function #0.
    .word svc_num1              @ Entry one goes to SVC function #1.
    .word 0                     @ Null termination of the jump table.

@ Set data alignment
.data
    .align 4