PORTB = $6000
PORTA = $6001
DDRB = $6002
DDRA = $6003
value = $0200
mod10 = $0202
message = $0204
counter = $020a
temp = $0204
seed = $020c
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
  lda #" "
  jsr print_char
;   lda #%11100000 ; Set top 3 pins on port A to output
;   sta DDRA
  lda #%00000010 ; Set cursor to home
  jsr lcd_instruction
  lda #0
  sta message
  sta counter
  sta temp
  sta seed
  ; check which bits are set

  ; put generator here


done:
  jsr generate
  sta value
  lda #0
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

loop:
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




generate:
  ; Initialize random number generator with a seed value
  LDX #$FF    ; Seed value
  STX seed    ; Store seed in memory location "seed"

  ; Generate a pseudorandom number between 0 and 10
  LDA seed    ; Load seed into accumulator
  CLC         ; Clear carry flag
  ADC $1      ; Add value from memory location "1" to seed
  STA seed    ; Store new seed value
  LSR         ; Shift seed right to discard low bit (optional)
  ROR         ; Rotate right to shuffle bits (optional)
  AND #$0F    ; Mask out all but the 4 least significant bits
  CMP #$0B    ; Compare to 11 (10+1)
  BCS start   ; If greater than 10, start over
  RTS         ; Return with random number in accumulator
start:
  DEY         ; Decrement Y register
  BNE start   ; If Y is not zero, try again
  LDA #$0A    ; Load 10 into accumulator
  RTS         ; Return with 10 in accumulator (if all retries fail)



  .org $fffc
  .word $8000
  .word $0000
