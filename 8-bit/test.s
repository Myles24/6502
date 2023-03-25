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
; Initialize the random number generator
    lda #$00     ; Load the value 0 into the accumulator
    sta $fe       ; Store the value in memory location $fe
    sta $02       ; Store the value in memory location $02

; Generate a random number between 1 and 10
generate:
    lda $fe       ; Load the value from memory location $fe into the accumulator
    eor $02       ; Perform an exclusive OR with the value from memory location $02
    sta $fe       ; Store the result in memory location $fe
    asl          ; Shift the accumulator left
    bcs carry     ; If the carry flag is set, branch to carry
    lda #$01     ; Load the value 1 into the accumulator
    jmp done     ; Jump to done
carry:
    lda #$00     ; Load the value 0 into the accumulator
    adc #$0a     ; Add 10 to the accumulator
    sta $fe       ; Store the result in memory location $fe
done:
    ; The random number is now stored in memory location $fe.
    ; To convert it to the range 1-10, add 1 and take the result modulo 10.
    lda $fe       ; Load the random number into the accumulator
    clc          ; Clear the carry flag
    adc #$01     ; Add 1 to the accumulator
    and #$0f     ; Mask the accumulator with 0x0f to take the result modulo 10
    sta $fe       ; Store the final result in memory location $fe

  ; initialize value to number to convert
  lda #$fe
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




  .org $fffc
  .word reset
  .word $0000
