PORTB = $6000
PORTA = $6001
DDRB = $6002
DDRA = $6003
value = $0200
mod10 = $0202
message = $0204
counter = $020a
E  = %10000000 ; Enable bit for LCD
RW = %01000000 ; Read/Write bit for LCD
RS = %00100000 ; Register Select bit for LCD

  .org $8000
reset:
  ldx #$ff
  txs
  cli
  lda #%11111111 ; set all pins on port B to output
  sta DDRB
  lda #%11100000 ; Set top 3 pins on port A to output
  sta DDRA

  lda #%00111000 ; Set 8-bit mode; 2-line display; 5x8 font
  jsr lcd_instruction
  lda #%00001110 ; Display on; cursor on; blink off
  jsr lcd_instruction
  lda #%00000110 ; Increment and shift cursor; don't shift display
  jsr lcd_instruction
  lda #000000001 ; clear display
  jsr lcd_instruction

  lda #0
  sta counter
  sta counter + 1

loop:
  lda #" " ; adds a space after all characters are printed to overwrite any 2s place numbers
  jsr print_char
  lda #%11100000 ; Set top 3 pins on port A to output
  sta DDRA
  lda #%00000010 ; Set cursor to home
  jsr lcd_instruction
  lda #0
  sta message
  sta counter
  ; check which bits are set
  jsr bit_check1
  jsr bit_check2
  jsr bit_check3
  jsr bit_check4
  jsr bit_check5
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
  beq loop
  jsr print_char
  inx
  jmp print


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
  lda #%00000000  ; Port B is input
  sta DDRB
lcdbusy:
  lda #RW
  sta PORTA
  lda #(RW | E)
  sta PORTA
  lda PORTB
  and #%10000000
  bne lcdbusy

  lda #RW
  sta PORTA
  lda #%11111111  ; Port B is output
  sta DDRB
  pla ;take message back from stack, put into accum.
  rts

lcd_instruction:
  jsr lcd_wait
  sta PORTB
  lda #0         ; Clear RS/RW/E bits
  sta PORTA
  lda #E         ; Set E bit to send instruction
  sta PORTA
  lda #0         ; Clear RS/RW/E bits
  sta PORTA
  rts

print_char:
  jsr lcd_wait ; toss A around then load it again, continue.
  sta PORTB
  lda #RS         ; Set RS; Clear RW/E bits
  sta PORTA
  lda #(RS | E)   ; Set E bit to send instruction
  sta PORTA
  lda #RS         ; Clear E bits
  sta PORTA
  rts


bit_check1:
  pha
  lda #%00000000 ; set all pins on PORTA to input
  sta PORTA
  lda PORTA
  and #%00000001 ; AND 1st bit
  bne increment1 ; branch if 1st bit is set
  pla
  rts
increment1:
  pla
  inc counter ; add 1 if 1st bit is set
  rts
bit_check2:
  pha
  lda #%00000000
  sta PORTA
  lda PORTA
  and #%00000010
  bne increment2
  pla
  rts
increment2:
  pla
  inc counter
  inc counter  ; add 2 if 2nd bit is set
  rts
bit_check3:
  pha
  lda #%00000000
  sta PORTA
  lda PORTA
  and #%000000100
  bne increment3
  pla
  rts
increment3:
  lda counter
  adc #4     ; add 4 if 3rd bit is set
  sta counter
  pla
  rts
bit_check4:
  pha
  lda #%00000000
  sta PORTA
  lda PORTA
  and #%00001000
  bne increment4
  pla
  rts
increment4:
  lda counter
  adc #8     ; add 8 if 4th bit is set
  sta counter
  pla
  rts
bit_check5:
  pha
  lda #%00000000
  sta PORTA
  lda PORTA
  and #%00010000
  bne increment5
  pla
  rts
increment5:
  lda counter
  adc #16     ; add 16 to 5th bit is set
  sta counter
  pla
  rts


DELAY_LOOP:
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
  .word reset
  .word $0000
