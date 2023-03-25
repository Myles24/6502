PORTB = $6000
PORTA = $6001
DDRB = $6002
DDRA = $6003
value = $0200
mod10 = $0202
message = $0204
counter = $020a
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
  sta counter
  sta counter + 1
loop:
  lda #" "
  jsr print_char
  lda #" "
  jsr print_char
;   lda #%11100000 ; Set top 3 pins on port A to output
;   sta DDRA
  lda #%00000010 ; Set cursor to home
  jsr lcd_instruction
  lda #0
  sta message
  sta counter
  ; check which bits are set
  jsr bit_check8
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

bit_check8:
  lda #%00000000
  sta PORTA
  lda PORTA
  and #%00000001
  bne increment8
  jmp bit_check7
increment8:
  lda counter
  adc #128     ; add 16 to 5th bit is set
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
  adc #64     ; add 16 to 5th bit is set
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
  adc #32     ; add 16 to 5th bit is set
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








  .org $fffc
  .word $8000
  .word $0000
