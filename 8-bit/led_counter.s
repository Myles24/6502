PORTB = $6000
PORTA = $6001
DDRB = $6002
DDRA = $6003
value = $0200
mod10 = $0202
message = $0204
counter = $020a
E  = %10000000
RW = %01000000
RS = %00100000

  .org $8000
reset:
  ldx #$ff
  txs
  cli
  lda #%11111111 ; set all pins on port B to output
  sta DDRB
  lda #%11111111 ; Set top 3 pins on port A to output
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
  lda #%00000010 ; Set cursor to home
  jsr lcd_instruction

  lda #0
  sta message

  ; initialize value to number to convert
  lda counter
  sta value
  lda counter + 1
  sta value + 1
  jsr increment

  inc PORTA ; Turn LED on
  jsr DELAY_LOOP
  dec PORTA ; Turn LED off
  jsr DELAY_LOOP

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
  adc #"0"
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
  ldy #0
char_loop:
  lda message,y
  tax
  pla
  sta message,y
  iny
  txa
  pha
  bne char_loop
  pla
  sta message,y
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

increment:
  inc counter
  bne exit_increment
  inc counter + 1
exit_increment:
  rts

  .org $fffc
  .word reset
  .word $0000
