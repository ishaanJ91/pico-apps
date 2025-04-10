#include "hardware/regs/addressmap.h"
#include "hardware/regs/io_bank0.h"
#include "hardware/regs/timer.h"
#include "hardware/regs/m0plus.h"

.syntax unified
.cpu    cortex-m0plus
.thumb

.global init_asm
.global attempt_character_input

.global button_pressed
.global last_gpio_interupt
.global morse_input_active
.global character_input_index
.global character_sequence_finished
.global character_input

.align  4

.equ DFLT_STATE_STRT, 1 @ Specify the value to start flashing
.equ DFLT_STATE_STOP, 0 @ Specify the value to stop flashing
.equ ONE_SECOND, 1000000 @ Specify the default alarm timeout

.equ GPIO_BTN_FALLING_MSK, 0x00400000 @ Bit-22 for falling-edge event on GP21
.equ GPIO_BTN_RISING_MSK, 0x00800000 @ Bit-23 for rising-edge event on GP21

.equ GPIO_BTN, 21 @ Specify pin for the "enter" button
.equ GPIO_LED, 25 @ Specify pin for the built-in LED

.equ GPIO_DIR_IN, 0 @ Specify input direction for a GPIO pin
.equ GPIO_DIR_OUT, 1 @ Specify output direction for a GPIO pin

.equ LED_VAL_ON, 1 @ Specify value that turns the LED "on"
.equ LED_VAL_OFF, 0 @ Specify value that turns the LED "off"

.equ BTN_VAL_PRESSED, 1 @ Specify value that the BTN is "pressed"
.equ BTN_VAL_NOT_PRESSED, 0 @ Specify value that the BTN is "not pressed"

.equ GPIO_ISR_OFFSET, 0x74 @ GPIO is int =13 (vector table entry 29)
.equ ALRM_ISR_OFFSET, 0x40 @ ALARM0 is int =0 (vector table entry 16)

.equ DFLT_MORSE_INPUT_ACTIVE, 0 @ set to false at start
.equ DFLT_LAST_GPIO_INTERUPT, 0 @ needs to be initialised

init_asm:
	push {lr}

	bl initialise_buttons
	bl initialise_alrm_isr
	bl initialise_gpio_isr
	@ cpsid i
	
	pop {pc}


attempt_character_input:
	push {lr}

	ldr r1, =1
	ldr r0, =morse_input_active
	str r1, [r0]

	ldr r1, =0
	ldr r0, =character_input_index
	str r1, [r0]
	ldr r0, =character_sequence_finished
	str r1, [r0]

	ldr r0, =character_input
	ldr r1, =' '
	strb r1, [r0, #0]
	strb r1, [r0, #1]
	strb r1, [r0, #2]
	strb r1, [r0, #3]
character_input_loop:
	wfi
	ldr r0, =character_sequence_finished
	ldr r0, [r0]
	cmp r0, #1
	bne character_input_loop

	bl disable_alarm

	@ ldr r0, =next_line
	@ bl printf

	ldr r1, =0
	ldr r0, =morse_input_active
	str r1, [r0]

	pop {pc}


set_alrm:
	push {lr}

	@ ldr r0, =set_alrm_p
	@ bl printf

	movs r1, #1
	ldr  r2, =(TIMER_BASE + TIMER_INTE_OFFSET)
	str  r1, [r2]

	ldr r2, =(TIMER_BASE + TIMER_TIMELR_OFFSET)
	ldr r1, [r2]

	ldr  r0, =ONE_SECOND
	adds r0, r1

	ldr r2, =(TIMER_BASE + TIMER_ALARM0_OFFSET)
	str r0, [r2]

	pop {pc}


disable_alarm:
    push {lr}

    ldr r1, =(TIMER_BASE + TIMER_INTE_OFFSET)  @ Load interrupt enable register
    movs r0, #0                                @ Clear the bit to disable
    str  r0, [r1]                              @ Disable the alarm interrupt

    pop {pc}


initialise_buttons:
	push {lr}

	ldr r0, =GPIO_BTN               @ This value is the GPIO BTN pin on the PI PICO board
	bl  asm_gpio_init               @ Call the subroutine to initialise the GPIO pin specified by r0
	ldr r0, =GPIO_BTN               @ This value is the GPIO BTN pin on the PI PICO board
	ldr r1, =GPIO_DIR_IN            @ We want this GPIO pin to be setup as an input pin
	bl  asm_gpio_set_dir            @ Call the subroutine to set the GPIO pin specified by r0 to state specified by r1
	ldr r0, =GPIO_BTN               @ This value is the GPIO BTN pin on the PI PICO board
	bl  asm_gpio_set_irq            @ Set the GPIO BTN pin to inturup

	pop {pc}


set_time_to_now:
	push {lr}

  bl  time_us_64                 @ get the current time
  ldr r2, =last_gpio_interupt    @ get last_gpio_interupt address
  str r0, [r2]                   @ set last_gpio_interupt to the current time

	pop {pc}


initialise_alrm_isr:
	push {lr}

	ldr  r0, =(PPB_BASE + M0PLUS_VTOR_OFFSET) @ Load r0 with the correct address (PPB_BASE + M0PLUS_VTOR_OFFSET) to find the start of the vector table
	ldr  r1, [r0]                             @ Load r1 with the value of the address of the start of the vector table
	movs r0, #ALRM_ISR_OFFSET                 @ Moving the value of ALRM_ISR_OFFSET into r0
	adds r1, r0                               @ Add the ALRM_ISR_OFFSET value to to address in order to find the alarm isr offset value in the vector table
	ldr  r0, =alrm_isr                        @ Load r0 with the address of the alrm_isr function, so it knows where to jump to on alarm interupt
	str  r0, [r1]                             @ Set the address of alrm_isr in r0 to the address in the vector table stored in r1

	movs r1, #1                                   @ Loading r1 with the correct value 1 so we can set it in memory
	ldr  r0, =(PPB_BASE + M0PLUS_NVIC_ICPR_OFFSET) @ Load r0 with the correct address (PPB_BASE + M0PLUS_NVIC_ICPR_OFFSET) to find the start of the vector table
	str  r1, [r0]                                  @ Set the value of NVIC ICPR to 1

	ldr r0, =(PPB_BASE + M0PLUS_NVIC_ISER_OFFSET) @ Load r0 with the correct address (PPB_BASE + M0PLUS_NVIC_ISER_OFFSET) to find the start of the vector table
	str r1, [r0]                                  @ Set the value of NVIC ISER to 1

	pop {pc}


initialise_gpio_isr:
	push {lr}

	ldr  r0, =(PPB_BASE + M0PLUS_VTOR_OFFSET) @ Load r0 with the correct address (PPB_BASE + M0PLUS_VTOR_OFFSET) to find the start of the vector table
	ldr  r1, [r0]                             @ Load r1 with the value of the address of the start of the vector table
	movs r0, #GPIO_ISR_OFFSET                 @ Moving the value of GPIO_ISR_OFFSET into r0
	adds  r1, r0                              @ Add the GPIO_ISR_OFFSET value to to address in order to find the alarm isr offset value in the vector table
	ldr  r0, =gpio_isr                        @ Load r0 with the address of the alrm_isr function, so it knows where to jump to on alarm interupt
	str  r0, [r1]                             @ Set the address of alrm_isr in r0 to the address in the vector table stored in r1

	ldr r1, =0x2000                               @ Loading r1 with the correct value 0x2000 so we can set it in memory
	ldr r0, =(PPB_BASE + M0PLUS_NVIC_ICPR_OFFSET) @ Load r0 with the correct address (PPB_BASE + M0PLUS_NVIC_ICPR_OFFSET) to find the start of the vector table
	str r1, [r0]                                  @ Set the value of NVIC ICPR to 0x2000

	ldr r0, =(PPB_BASE + M0PLUS_NVIC_ISER_OFFSET) @ Load r0 with the correct address (PPB_BASE + M0PLUS_NVIC_ISER_OFFSET) to find the start of the vector table
	str r1, [r0]                                  @ Set the value of NVIC ISER to 0x2000

	pop {pc}


.thumb_func
alrm_isr:
	push {lr}

	@ ldr r0, =alrm_isr_p
	@ bl printf

	ldr r0, =(TIMER_BASE + TIMER_INTR_OFFSET)
	ldr r1, =1
	str r1, [r0]

	ldr r0, =button_pressed
	ldr r0, [r0]
	cmp r0, BTN_VAL_PRESSED
	beq button_pressed_alrm
	ldr r0, =character_sequence_finished
	ldr r1, =1
	str r1, [r0]

button_pressed_alrm:

	bl set_alrm

	pop {pc}


.thumb_func
gpio_isr:
	push {r4, lr}

	ldr  r0, =(IO_BANK0_BASE + IO_BANK0_PROC0_INTS2_OFFSET)
	ldr  r3, [r0]

	movs r0, r3
	ldr  r1, =GPIO_BTN_RISING_MSK
	ands r0, r1
	cmp  r0, #0
	bne  rising_edge_interupt

	movs r0, r3
	ldr  r1, =GPIO_BTN_FALLING_MSK
	ands r0, r1
	cmp  r0, #0
	bne  falling_edge_interupt

rising_edge_interupt:
	@ ldr r0, =gpio_isr_rising
	@ bl printf

  ldr r1, =GPIO_BTN_RISING_MSK
	ldr r0, =(IO_BANK0_BASE + IO_BANK0_INTR2_OFFSET)
	str r1, [r0]

	ldr r3, =morse_input_active
	ldr r3, [r3]
	cmp r3, #0
	beq end_gpio

	ldr r3, =button_pressed
	ldr r2, =BTN_VAL_NOT_PRESSED
	str r2, [r3]

	ldr r0, =character_input

	ldr r4, =last_gpio_interupt
	ldr r4, [r4]

	bl set_time_to_now

	ldr r2, =last_gpio_interupt
	ldr r2, [r2]

	subs r3, r2, r4

	ldr r2, =ONE_SECOND
	cmp r3, r2
	blt dot_input
	@ dash
	
	movs r4, '-'
	ldr r0, =dash_str
	bl printf
	b   dash_input
dot_input:
	movs r4, '.'
	ldr r0, =dot_str
	bl printf

dash_input:
	ldr r0, =character_input_index
	ldr r1, [r0]
	adds r2, r1, #1
	str r2, [r0]
	ldr r0, =character_input
	@ lsls r3, r1, #2
	mov r3, r1
	strb r4, [r0, r3]

	cmp r2, 4
	bne end_gpio

seq_finished:
  ldr r0, =character_sequence_finished
  ldr r1, =1
  str r1, [r0]
	b end_gpio

falling_edge_interupt:
	@ ldr r0, =gpio_isr_falling
	@ bl printf

  ldr r1, =GPIO_BTN_FALLING_MSK
	ldr r0, =(IO_BANK0_BASE + IO_BANK0_INTR2_OFFSET)
	str r1, [r0]

	ldr r3, =morse_input_active
	ldr r3, [r3]
	cmp r3, #0
	beq end_gpio

	ldr r3, =button_pressed
	ldr r2, =BTN_VAL_PRESSED
	str r2, [r3]

	bl set_time_to_now

end_gpio:
	bl set_alrm

	pop {r4, pc}


.align 4

.data

button_pressed: .word BTN_VAL_NOT_PRESSED
last_gpio_interupt: .word DFLT_LAST_GPIO_INTERUPT
morse_input_active: .word DFLT_MORSE_INPUT_ACTIVE
character_input_index: .word 0
character_sequence_finished: .word 0
character_input: .byte ' ', ' ', ' ', ' ', 0

dot_str: .asciz "."
dash_str: .asciz "-"
next_line: .asciz "\n"

set_alrm_p: .asciz "set_alrm\n"
gpio_isr_falling: .asciz "gpio_isr falling\n"
gpio_isr_rising: .asciz "gpio_isr rising\n"
alrm_isr_p: .asciz "alrm_isr\n"
out_of_loop: .asciz "out_of_loop\n"
