PORTB = $6000
PORTA = $6001
DDRB = $6002
DDRA = $6003
value = $0200
mod10 = $0202
temp = $0204
counter = $020a
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
  sta temp
  sta counter
  sta counter + 1
  sta seed
  ldx #0
print:
  lda message,x
  beq done
  jsr print_char
  inx
  jmp print

message: .asciiz "Generating..."

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

done:
  jsr bit_check8
  jsr generate
  ldx #0
  ;lda counter
  cmp counter
  bne loop
  inx
equal:
  lda #%00000010 ; Set cursor to home
  jsr lcd_instruction
  ldx #0
  jmp print2

print2:
  lda correct,x
  beq loop
  jsr print_char
  inx
  jmp print2

correct: .asciiz "Correct!     "

loop:
  jmp loop

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
