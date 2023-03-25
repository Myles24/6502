PORTB = $6000
PORTA = $6001
DDRB = $6002
DDRA = $6003
value = $0200
mod10 = $0202
message = $0204
counter = $020a
counter2 = $020c
result = $020e
guesses = $0210
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
  sta guesses
  lda #0
  sta counter
  sta counter + 1
  sta counter2
  sta counter2 + 1
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
  ; initialize value to number to convert
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
  ldx #0
print:
  lda message,x
  beq exit_print
  jsr print_char
  inx
  jmp print
exit_print:
  jmp loop

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
  adc #128     ; add 128 to 8th bit is set
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
  adc #64     ; add 64 to 7th bit is set
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
  adc #32     ; add 32 to 6th bit is set
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
  adc #16     ; add 16 to 5th bit is set
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
  lda #%11111111
  sta DDRB
  lda result
  bne is_equal ; if result > 0, then it must be after the 1st button press
  lda counter2
  adc counter
  sta counter2 ; if result = 0, store counter in counter2
  inc result ; count number of button presses
  ldx #0
  jmp print2 ; prints "Stored."
button_calls:
  jsr DELAY_LOOP
  jsr DELAY_LOOP
  jmp loop

print2: ; Print "Stored."
  lda message2,x
  beq button_calls ; jumps to loop after 1st button press
  jsr print_char
  inx
  jmp print2

is_equal:
  clc
  ldx #0
  lda counter2
  cmp counter
  bne exit_is_equal ; if guess and counter are not equal, run comparisons
  jsr print3 ; if guess and counter are equal, print "Correct"
exit_is_equal:
  inc guesses
  ldx counter    ; load first value into X register
  cpx counter2    ; compare second value with X register
  bcs greater   ; branch if carry set (value2 is greater)
  ; if we get here, value1 is greater or equal to value2
  clc           ; clear carry flag
  ldx #0
  lda counter2
  cmp counter
  beq print3 ; If values are equal, print "Correct"
  jmp print5 ; If they are not equal, the guess must be lower
greater:
  ldx #0
  clc
  jmp print6

print3: ; Prints "Correct"
  lda message3,x
  beq inf_loop
  jsr print_char
  inx
  jmp print3

init_print_4: ; checks if guesses are depleted
  lda #%00000010 ; Set cursor to home
  jsr lcd_instruction
  ldx #0
  lda #3 ; set number of guesses to 3
  cmp guesses
  beq print4
  jsr DELAY_LOOP
  jsr DELAY_LOOP
  jmp loop ; jumps back to loop if guesses aren't depleted
print4: ; Prints "Incorrect" if guesses are depleted
  lda message4,x
  beq inf_loop
  jsr print_char
  inx
  jmp print4

inf_loop:
  jmp inf_loop

print5: ; Prints "Higher"
  lda message5,x
  beq exit_print5
  jsr print_char
  inx
  jmp print5
exit_print5:
  jmp init_print_4

print6: ; "Prints "Lower"
  lda message6,x
  beq exit_print6
  jsr print_char
  inx
  jmp print6
exit_print6:
  jmp init_print_4

message2: .asciiz "Stored"
message3: .asciiz "Correct"
message4: .asciiz "Incorrect"
message5: .asciiz "Higher"
message6: .asciiz "Lower"
space: .asciiz "             "

print_space: ; prints enough spaces to overwrite display
  lda space,x
  beq exit_print_space
  jsr print_char
  inx
  jmp print_space
exit_print_space:
  rts

DELAY_LOOP: ; 1 second delay
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
    tax
    RTS             ; Return from the subroutine

  .org $fffc
  .word $8000
  .word $0000
