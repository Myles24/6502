; Clock program for 6502 computer. User inputs time using dip-switches and the time is counted on the LCD

PORTB = $6000
PORTA = $6001
DDRB = $6002
DDRA = $6003
value = $0200
mod10 = $0202
message = $0204
counter = $020a
seconds = $020c
result = $020e
minutes = $0210
hours = $0212
time = $0214
E  = %01000000
RW = %00100000
RS = %00010000


  .org $8000
reset:
  ldx #$ff
  txs
  lda #%11111111 ; set all pins on port B to output
  sta DDRB
  lda #%00000000 ; Set top 3 pins on port A to output
  sta DDRA

  lda #%00000001 ; Clear display
  jsr lcd_instruction

  jsr lcd_init
  lda #%00101000 ; Set 4-bit mode; 2-line display; 5x8 font
  jsr lcd_instruction
  lda #%00001110 ; Display on; cursor on; blink off
  jsr lcd_instruction
  lda #%00000110 ; Increment and shift cursor; don't shift display
  jsr lcd_instruction
  lda #%00000001 ; Clear display
  jsr lcd_instruction

  lda #0
  sta result
  sta minutes
  sta hours
  sta time
  lda #0
  sta counter
  sta counter + 1
  sta seconds

  ldx #0
  lda message2
  jsr print_seconds

loop:
  lda space
  jsr print_space
  lda #%00000010 ; Set cursor to home
  jsr lcd_instruction
  lda #0
  sta message
  sta counter
  jsr bit_check8 ; check which bits are set
  jsr button_check ; check if button is pressed



init:
  lda counter
  sta value
  lda counter + 1
  sta value + 1

; binary to decimal converter for LCD
divide:
  ; initialize remainder to 0
  lda #0
  sta mod10
  sta mod10 + 1
  clc
  ldx #16
divloop:
  ;rotate quotient and remainder
  rol value
  rol value + 1
  rol mod10
  rol mod10 + 1
  ; a,y = dividend - divisor
  sec
  lda mod10
  sbc #10
  tay ; save low byte in Y
  lda mod10 + 1
  sbc #0
  bcc ignore_result
  sty mod10
  sta mod10 + 1
ignore_result:
  dex
  bne divloop
  rol value
  rol value + 1
  lda mod10
  clc
  adc #"0" ; converts digit to ascii
  jsr push_char
  ; if value != 0, then continue dividing
  lda value
  ora value + 1
  bne divide
  lda time
  ldx #0
print:
  lda message,x
  beq exit_print
  jsr print_char
  inx
  jmp print
exit_print: ; prints to display in format HH:MM:SS
  lda #1
  cmp time
  beq hour_clock_loop
  lda #2
  cmp time
  beq minute_clock_loop
  lda #3
  cmp time
  beq second_clock_loop
  lda #4
  cmp time
  beq inf_loop
  jmp loop

hour_clock_loop: ; transfers hours to counter and prints to display
  jsr check_hours_digit
  clc
  lda #0
  sta message
  sta counter
  lda counter
  adc hours
  sta counter
  inc time
  jmp init
minute_clock_loop: ; transfers minutes to counter and prints to display
  ldx #0
  lda #":"
  jsr print_char
  jsr check_minutes_digit
  clc
  lda #0
  sta message
  sta counter
  lda counter
  adc minutes
  sta counter
  inc time
  jmp init
second_clock_loop: ; transfers seconds to counter and prints to display
  ldx #0
  lda #":"
  jsr print_char
  jsr check_seconds_digit
  clc
  lda #0
  sta message
  sta counter
  lda counter
  adc seconds
  sta counter
  inc time
  jmp init


inf_loop: ; loops and adds one second each time
  inc seconds
  jsr check_second
  lda space
  jsr print_space
  lda #1
  sta time
  lda #%00000010 ; Set cursor to home
  jsr lcd_instruction
  jsr DELAY_LOOP
  jsr DELAY_LOOP
  jmp hour_clock_loop

check_second: ; logic to change minute and/or seconds
  lda #60
  cmp seconds
  beq check_minute
  rts
check_minute: ; logic to reset seconds and change minute
  lda #0
  sta seconds
  inc minutes
  lda #60
  cmp minutes
  beq check_hour
  rts
check_hour: ; logic to reset all times if 24 hours have passed or change hour
  lda #0
  sta seconds
  sta minutes
  inc hours
  lda #24
  cmp hours
  bne exit_check_hour
  lda #0
  sta minutes
  sta seconds
  sta hours
exit_check_hour:
  rts

; the next 3 labels add a zero if a number has one digit
check_seconds_digit:
  lda seconds
  cmp #10
  bcc add_zero
  rts
check_minutes_digit:
  lda minutes
  cmp #10
  bcc add_zero
  rts
check_hours_digit:
  lda hours
  cmp #10
  bcc add_zero
  rts
add_zero:
  lda #"0"
  jsr print_char
  rts

; Add character in the A register to the beginning of the null terminated string
push_char:
  pha ; push new first char onto stack
  ldy #0 ; initialize y to zero
char_loop:
  lda message,y ; load index y of message to accumulator
  tax ; transfer index y of message to x register
  pla ; pull char into accumulator
  sta message,y ; put char in message at index y
  iny
  txa ; transfer index y - 1 of message to accumulator
  pha ; push index y - 1 of message onto stack
  bne char_loop ; if index y != 0, keep looping
  pla ; if y = 0, transfer index y of message to accumulator
  sta message,y ; store a null byte at last index of message
  rts

lcd_wait:
  pha
  lda #%11110000  ; LCD data is input
  sta DDRB
lcdbusy:
  lda #RW
  sta PORTB
  lda #(RW | E)
  sta PORTB
  lda PORTB       ; Read high nibble
  pha             ; and put on stack since it has the busy flag
  lda #RW
  sta PORTB
  lda #(RW | E)
  sta PORTB
  lda PORTB       ; Read low nibble
  pla             ; Get high nibble off stack
  and #%00001000
  bne lcdbusy

  lda #RW
  sta PORTB
  lda #%11111111  ; LCD data is output
  sta DDRB
  pla
  rts

lcd_init:
  lda #%00000010 ; Set 4-bit mode
  sta PORTB
  ora #E
  sta PORTB
  and #%00001111
  sta PORTB
  rts

lcd_instruction:
  jsr lcd_wait
  pha
  lsr
  lsr
  lsr
  lsr            ; Send high 4 bits
  sta PORTB
  ora #E         ; Set E bit to send instruction
  sta PORTB
  eor #E         ; Clear E bit
  sta PORTB
  pla
  and #%00001111 ; Send low 4 bits
  sta PORTB
  ora #E         ; Set E bit to send instruction
  sta PORTB
  eor #E         ; Clear E bit
  sta PORTB
  rts

print_char:
  jsr lcd_wait
  pha
  lsr
  lsr
  lsr
  lsr             ; Send high 4 bits
  ora #RS         ; Set RS
  sta PORTB
  ora #E          ; Set E bit to send instruction
  sta PORTB
  eor #E          ; Clear E bit
  sta PORTB
  pla
  and #%00001111  ; Send low 4 bits
  ora #RS         ; Set RS
  sta PORTB
  ora #E          ; Set E bit to send instruction
  sta PORTB
  eor #E          ; Clear E bit
  sta PORTB
  rts

; adds numbers based on which bits are set
bit_check8:
  lda #%00000000
  sta PORTA
  lda PORTA
  and #%00000001
  bne increment8
  jmp bit_check7
increment8:
  lda counter
  adc #128     ; add 128 if 8th bit is set
  sta counter
bit_check7:
  lda #%00000000
  sta PORTA
  lda PORTA
  and #%00000010
  bne increment7
  jmp bit_check6
increment7:
  lda counter
  adc #64     ; add 64 if 7th bit is set
  sta counter
bit_check6:
  lda #%00000000
  sta PORTA
  lda PORTA
  and #%00000100
  bne increment6
  jmp bit_check5
increment6:
  lda counter
  adc #32     ; add 32 if 6th bit is set
  sta counter
bit_check5:
  lda #%00000000
  sta PORTA
  lda PORTA
  and #%00001000
  bne increment5
  jmp bit_check4
increment5:
  lda counter
  adc #16     ; add 16 if 5th bit is set
  sta counter
bit_check4:
  lda #%00000000
  sta PORTA
  lda PORTA
  and #%00010000
  bne increment4
  jmp bit_check3
increment4:
  lda counter
  adc #8     ; add 8 if 4th bit is set
  sta counter
bit_check3:
  lda #%00000000
  sta PORTA
  lda PORTA
  and #%00100000
  bne increment3
  jmp bit_check2
increment3:
  lda counter
  adc #4     ; add 4 if 3rd bit is set
  sta counter
bit_check2:
  lda #%00000000
  sta PORTA
  lda PORTA
  and #%01000000
  bne increment2
  jmp bit_check1
increment2:
  lda counter
  adc #2    ; add 2 if 2nd bit is set
  sta counter
bit_check1:
  lda #%00000000 ; set all pins on PORTA to input
  sta PORTA
  lda PORTA
  and #%10000000 ; AND 1st bit
  bne increment1 ; branch if 1st bit is set
  rts
increment1:
  inc counter ; add 1 if 1st bit is set
  rts

; check if button is pressed
button_check:
  lda #%00000000 ; set all pins on port B to input
  sta DDRB
  lda PORTB
  and #%10000000
  bne button_pressed ; branch if button is pressed
  lda #%11111111 ; set all pins on port B back to output
  sta DDRB
  rts ; if button is not pressed, return to loop
button_pressed: ; if button is pressed...
  ldx #0
  lda #%11111111 ; set Port B back to output
  sta DDRB
  lda result
  cmp #0
  beq print_minutes ; prints "Set Minutes"
  cmp #1 ; if the button is pressed, then print "Set Hours"
  beq print_hours
  cmp #2
  beq jmp_printime

jmp_printime:
  ldx #0
  jmp print_time_set

message2: .asciiz "Set Seconds"
message3: .asciiz "Set Minutes"
message4: .asciiz "Set Hours"
message5: .asciiz "Time Set"
space: .asciiz "               "

print_seconds: ; prints "Set Seconds"
  lda message2,x
  beq exit_print_seconds
  jsr print_char
  inx
  jmp print_seconds
exit_print_seconds:
  jsr DELAY_LOOP
  jsr DELAY_LOOP
  rts

print_minutes: ; prints "Set Minutes"
  lda message3,x
  beq exit_print_minutes
  jsr print_char
  inx
  jmp print_minutes
exit_print_minutes: ; sets seconds to counter variable
  clc
  jsr DELAY_LOOP
  jsr DELAY_LOOP
  inc result
  lda seconds
  adc counter
  sta seconds
  rts

print_hours: ; prints "Set Hours"
  lda message4,x
  beq exit_print_hours
  jsr print_char
  inx
  jmp print_hours
exit_print_hours: ; sets minutes to counter variable
  clc
  jsr DELAY_LOOP
  jsr DELAY_LOOP
  inc result
  lda minutes
  adc counter
  sta minutes
  rts

print_time_set: ; prints "Time Set"
  lda message5,x
  beq exit_time_set
  jsr print_char
  inx
  jmp print_time_set
exit_time_set:
  jsr DELAY_LOOP
  jsr DELAY_LOOP
  inc result
  clc
  lda hours
  adc counter; sets hours to counter variable
  sta hours
  inc time
  ldx #0
  lda #%00000010 ; Set cursor to home
  jsr lcd_instruction
  lda #%00000001 ; Clear display
  jsr lcd_instruction
  jmp hour_clock_loop

print_space: ; prints enough spaces to overwrite display
  lda space,x
  beq exit_print_space
  jsr print_char
  inx
  jmp print_space
exit_print_space:
  rts


DELAY_LOOP: ; 0.5 second delay
    txa
    LDX #$FF       ; Initialize X register to 255
    OUTER_LOOP:
        LDY #$FF   ; Initialize Y register to 255
        INNER_LOOP:
            NOP     ; Execute the NOP instruction, which takes 2 cycles
            DEY     ; Decrement the Y register, which takes 2 cycles
            BNE INNER_LOOP  ; Branch back to INNER_LOOP if Y is not zero, which takes 3 cycles
        DEX         ; Decrement the X register, which takes 2 cycles
        BNE OUTER_LOOP  ; Branch back to OUTER_LOOP if X is not zero, which takes 3 cycles
    LDX #72       ; Initialize X register to 255
    OUTER_LOOP2:
        LDY #72   ; Initialize Y register to 255
        INNER_LOOP2:
            NOP     ; Execute the NOP instruction, which takes 2 cycles
            DEY     ; Decrement the Y register, which takes 2 cycles
            BNE INNER_LOOP2  ; Branch back to INNER_LOOP if Y is not zero, which takes 3 cycles
        DEX         ; Decrement the X register, which takes 2 cycles
        BNE OUTER_LOOP2  ; Branch back to OUTER_LOOP if X is not zero, which takes 3 cycles
    tax
    RTS             ; Return from the subroutine

  .org $fffc
  .word $8000
  .word $0000

