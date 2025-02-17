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

.equ    GPIO_BTN_DN,  20              @ Specify pin for the "downButton" button
.equ    GPIO_BTN_EN,  21              @ Specify pin for the "enter" button
.equ    GPIO_BTN_UP,  22              @ Specify pin for the "upButton" button
.equ    GPIO_LED_PIN, 25              @ Specify pin for the built-in LED
.equ    GPIO_DIR_IN,   0              @ Specify input direction for a GPIO pin
.equ    GPIO_DIR_OUT,  1              @ Specify output direction for a GPIO pin


.equ    LED_VAL_ON,    1              @ Specify value that turns the LED "on"
.equ    LED_VAL_OFF,   0              @ Specify value that turns the LED "off"

.equ    GPIO_ISR_OFFSET, 0x74         @ GPIO is int #13 (vector table entry 29)
.equ    ALRM_ISR_OFFSET, 0x40         @ ALARM0 is int #0 (vector table entry 16)


@ Entry point to the ASM portion of the program
main_asm:
    
    bl    init_leds                                 @ initialize the LEDs
    bl    install_alrm_isr                          @ initialize the alarm isr
    bl    install_gpio_isr                          @ initialize the GPIO isr
    movs    r0, #GPIO_BTN_EN                        @ initialize en button 
    bl      init_btn                                @
    movs    r0, #GPIO_BTN_DN                        @ initialize downButton button 
    bl      init_btn                                @ 
    movs    r0, #GPIO_BTN_UP                        @ initialize upButton button 
    bl      init_btn                                @   
    ldr   r4, =DFLT_ALARM_TIME                      @ set alarm delay
    bl    set_alarm                                 @ new alarm
    ldr   r2, =(TIMER_BASE + TIMER_INTE_OFFSET)     @ active alarm
    movs  r1,#1                                     @ //
    str   r1, [r2]                                  @ //

loop:
    
    wfi                                             @ Wait 
    b     loop                


init_leds:
    
    push    {lr}                                        
    movs    r0, #GPIO_LED_PIN                           @ give base value to initialise GPIO pin
    bl      asm_gpio_init                               @ initialise the GPIO pin 
    movs    r0, #GPIO_LED_PIN                           @ GPIO LED pin again
    movs    r1, #GPIO_DIR_OUT                           @ GPIO pin out
    bl      asm_gpio_set_dir                            @ set the GPIO pin specified by r0 to state specified by r1
    pop     {pc}                                        


init_btn:
    
    push    {r4, lr}
    movs    r4, r0                                      @ intitial gpio pin
    bl      asm_gpio_init                               @ //
    movs    r0, r4                                      @ //
    movs    r1, #GPIO_DIR_IN                            @ gpio pin value on board
    bl      asm_gpio_set_dir                            @ set upButton output in value
    movs    r0, r4                                      @ //
    bl      asm_gpio_set_irq                            @ setup interupt
    pop     {r4, pc}                    

 set_alarm:
    
    
    ldr     r1, =(TIMER_BASE + TIMER_TIMELR_OFFSET)     @ get the current timer value 
    ldr     r2,[r1]                                     @ //
    movs    r1, r4                                      @ Get alarm delay
    add     r1, r1, r2                                  @ Add the desired delay to the current timer
    ldr     r2, =(TIMER_BASE + TIMER_ALARM0_OFFSET)     @ Push the desired delay to the relevant alarm address
    str     r1, [r2]                                    @ store into r1
    bx      lr                                          
   

install_alrm_isr:
    
    ldr     r2, =(PPB_BASE + M0PLUS_VTOR_OFFSET)        @ Get address of the RAM vector table (PPB_BASE + M0PLUS_VTOR_OFFSET) 
    ldr     r1, [r2]                                    @ //
    movs    r2, #ALRM_ISR_OFFSET                        @ Store  alrm_isr address  to the  offset for ALARM0 
    add     r2, r1                                      @ Find the location of this interrupt 
    ldr     r0, =alrm_isr                               @ Load the entry point 
    str     r0, [r2]                                    @ Set the table location 
    ldr     r2, =(PPB_BASE + M0PLUS_NVIC_ICPR_OFFSET)   @ Disable the ALARM0 IRQ 
    movs    r1, #1                                      @ //
    str     r1 ,[r2]                                    @ //
    ldr     r2, =(PPB_BASE + M0PLUS_NVIC_ISER_OFFSET)   @ Enable the ALARM0 IRQ b
    movs    r1, #1                                      @ //
    str     r1 ,[r2]                                    @ //
    bx      lr     

.thumb_func

alrm_isr:
 
    push    {lr}                                      
    ldr     r1, =(TIMER_BASE+TIMER_INTR_OFFSET)         @ get interrupt 
    movs    r0 ,#1                                      @ //
    str     r0,[r1]                                     @ //
    movs    r0, #GPIO_LED_PIN                           @ Get the current value of the LED GPIO pin
    bl      asm_gpio_get                                @ //
    cmp     r0, #LED_VAL_OFF                            @ Check if the LED GPIO pin value is "off" or not 
    beq     led_setto_on                                @ If it is "off" go turn it on 

led_setto_off:
  
    movs    r1, #LED_VAL_OFF                            @ switch ot off 
    b       led_state                                   @ go set state part   

led_setto_on:
    
    movs    r1, #LED_VAL_ON                             @ The LED is currently "off" so we want to turn it "on"

led_state:
    
    movs    r0, #GPIO_LED_PIN                           @ Update the value of the LED GPIO pin
    bl      asm_gpio_put                                @ //
    bl      set_alarm                                   @ reset alarm
    ldr     r2, =(TIMER_BASE + TIMER_INTE_OFFSET)       @ Enable Alarm
    movs    r1,#1                                       @ //
    str     r1, [r2]                                    @ //
    ldr     r0, =msg1                                   @ print msg1 
    bl      printf                                      @ go print
    pop     {pc}                                     

install_gpio_isr:
    
    ldr     r2, =(PPB_BASE + M0PLUS_VTOR_OFFSET)        @ Get the address of the RAM vector table (PPB_BASE + M0PLUS_VTOR_OFFSET)
    ldr     r1, [r2]                                    @ Make r1 point to the location     
    movs    r2, #GPIO_ISR_OFFSET                        @ Store the address of the gpio_isr to offset for ALARM0
    add     r2, r1                                      @ Find the  interrupt location
    ldr     r0, =gpio_isr                               @ Load the entry point of this interrupt into r0
    str     r0, [r2]                                    @ Set the table location of R0 as the value calculated in r2   
    ldr     r2, =(PPB_BASE + M0PLUS_NVIC_ICPR_OFFSET)   @ Disable the ALARM0 IRQ to (PPB_BASE + M0PLUS_NVIC_ICPR_OFFSET)
    ldr     r1, =0x2000                                 @ 2^13
    str     r1, [r2]                                    @ // 
    ldr     r2, =(PPB_BASE + M0PLUS_NVIC_ISER_OFFSET)   @ Enable the ALARM0 IRQ to (PPB_BASE + M0PLUS_NVIC_ISER_OFFSET)
    ldr     r1, =0x2000                                 @ 2^13
    str     r1, [r2]                                    @//
    bx      lr                                          

.thumb_func

gpio_isr:
     
    push {lr}
    ldr  r2, =(IO_BANK0_BASE + IO_BANK0_PROC0_INTS2_OFFSET)     @ Read the interrupt status 
    Ldr  r1, [r2]   	                                        @ do interrupt
    ldr  r0 ,=0x2000                                            @ //
    str  r0,[r2]                                                @ //
    ldr  r2, =(TIMER_BASE + TIMER_INTE_OFFSET)                  @ Get current led state 
    ldr  r0 ,[r2]                                               @ //
    ldr  r2,=GPIO_BTN_DN_MSK                                    @ Compare to check  which button was pressed
    CMP  r2, r1                                                 @ //
    beq  downButton                                             @ Branch to downButton if gp21 pressed
    ldr  r2,=GPIO_BTN_UP_MSK                                    @ //
    CMP  r2, r1                                                 @ //
    beq  upButton                                               @ Branch to upButton if gp22 pressed
    ldr  r2,=GPIO_BTN_EN_MSK                                    @ //
    CMP  r2, r1                                                 @ //
    bne  end                                                    @ Branch to end if does not match any
    ldr  r2, =(IO_BANK0_BASE + IO_BANK0_INTR2_OFFSET)           @ reset this interrupt when Gp21 pressed
    ldr  r1,=0x400000                                           @ //
    str  r1,[r2]                                                @ //
    ldr  r2,=DFLT_STATE_STOP                                    @ //
    cmp  r0, r2                                                 @ Compare current LED state with off state
    bne  notFlashing                                            @ if is flashing state go to notFlashing
    ldr  r2, =(TIMER_BASE + TIMER_INTE_OFFSET)                  @ active Alarm interupt
    movs r1,#1                                                  @ //
    str  r1, [r2]                                               @ //
    ldr  r0, =msg2                                              @ Print flashing message
    bl   printf                                                 @ //
    bl   end                                                    



downButton:
    
    ldr  r2, =(IO_BANK0_BASE + IO_BANK0_INTR2_OFFSET)           @ Gp20 pressed so reset this interrupt
    ldr  r1,=0x40000                                            @ // 
    str  r1,[r2]                                                @ //
    ldr  r2,=DFLT_STATE_STOP                                    @ Load  led stop 
    cmp  r0, r2                                                 @ compare current state 
    bne  gohalf                                                 @ branch  if not equal
    ldr  r4, =DFLT_ALARM_TIME                                   @ If equal reset toggle interval to default
    ldr  r0, =msg4                                              @ Print interval reset msg
    bl   printf                                                 @ 
    bl   end                                                    @ 

upButton:
    
    ldr  r2, =(IO_BANK0_BASE + IO_BANK0_INTR2_OFFSET)           @ Gp21 pressed so reset this interrupt
    ldr  r1,=0x4000000                                          @ Gp21 pressed so reset 
    str  r1,[r2]                                                @ //
    ldr  r2,=DFLT_STATE_STOP                                    @ Load led stop
    cmp  r0, r2                                                 @ compare current state 
    bne  doubles                                                @ branch  if not equal
    ldr  r4, =DFLT_ALARM_TIME                                   @ If equal reset 
    ldr  r0, =msg4                                              @ Print  reset msg
    bl   printf                                                 @ //
    bl   end                                                  

notFlashing:
    
    ldr  r2, =(TIMER_BASE + TIMER_INTE_OFFSET)                  @ Disable Alarm interupt
    movs r1,#0                                                  @ //
    str  r1, [r2]                                               @ //
    ldr  r0, =msg3                                              @ Print flash Disabled msg
    bl   printf                                                 @ //
    bl   end                                                    @ Branch to end

gohalf:   
    
    lsls r4, r4,#1                                              @ Divide interval by two 
    ldr  r0, =msg5                                              @ Print decressed msg
    bl   printf                                                 @ //
    bl   end                                                    @ Branch to end

doubles:
    
    lsrs r4, r4,#1                                              @ Increase interval by two
    ldr  r0, =msg6                                              @ Print  Increase msg
    bl   printf                                                 @ //
    
end:  
    bl set_alarm                                                @ set Alarm time (reset)
    pop {pc}                                                    
 

.align 4
    
    msg1:    .asciz "LED Toggled.\n"
    msg2:    .asciz "LED is flashing now.\n"
    msg3:    .asciz "LED is not flashing now.\n"
    msg4:    .asciz "Time reset.\n"
    msg5:    .asciz "Time halves.\n"
    msg6:    .asciz "Time doubles.\n"

.data
    lstate: .word   DFLT_STATE_STRT
    ltimer: .word   DFLT_ALARM_TIME

