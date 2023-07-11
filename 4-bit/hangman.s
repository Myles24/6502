; Hangman 2-player game for the 65C02 processor. This program has 3 phases: length, secret word, and guesses.
; the length phase prompts one user to enter the secret word's length
; the secret word phase prompts the same user to enter the secret word's characters in ascii binary
; the guesses phase prompts another player to make guesses of the letters that could be in the word

PORTB = $6000
PORTA = $6001
DDRB = $6002
DDRA = $6003
counter = $0200
length = $0202
guess_num = $0203
presses = $0204
secret = $020a
guesses = $0212
test = $021c
correct = $021e


E  = %01000000
RW = %00100000
RS = %00010000

  .org $8000

reset:
  ldx #$ff
  txs
  lda #%11111111 ; set all pins on port B to output
  sta DDRB
  lda #%00000000 ; Set all pins on port A to input
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

  ldx #0
  ldy #0
  lda #0
  sta counter
  sta length
  sta presses
  sta secret
  sta correct
  sta test
  lda #6
  sta guess_num

  ldx #0
  jsr print0

loop:             ; main loop of the program
  lda #%00000010 ; Set cursor to home
  jsr lcd_instruction
  lda space
  jsr print_space
  lda #%00000010 ; Set cursor to home
  jsr lcd_instruction
  lda #0
  sta counter
  jsr check_numGuesses
  jsr bit_check8            ; check which bits are set
  jsr button_check          ; check if button is pressed
  jsr check_print_counter   ; determine whether to display an ascii digit
  jsr print_char            ; prints character on display
  jsr guess_check           ; determines whether to display the guesses string on display
  jmp loop


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
  clc
  lda #%11111111 ; set PORTB back to output
  sta DDRB
  lda presses
  bne presses_check ; branches if presses is not zero
  jsr print1      ; if presses = 0, then print "Length Stored"
  jsr DELAY_LOOP
  jsr init_print3
  jsr DELAY_LOOP
  lda length
  adc counter ; adds counter to length to set the length of the secret word
  sta length
  inc presses ; increments presses
  jmp loop


presses_check: ; this runs if presses > 0
  ;inc presses
  lda presses
  cmp length
  bcc less_than ; branch if presses < length (keep entering characters)
  beq init_print_word ; branch if presses = length (prints the secret word and "Make Guesses")
  jmp init_guess ; if presses > length, then the program is in its "guesses" phase

less_than: ; this runs if presses < length
  inc presses
  lda counter
  jsr push_char ; pushes an ascii value to the String "secret"
  jsr print2    ; prints "Letter Stored.
  jsr DELAY_LOOP
  jmp loop

init_print_word: ; this runs if presses = length
  inc presses
  lda counter
  jsr push_char  ; pushes last character to secret
  lda #0         ; stores a null-bute at the end of secret
  sta secret,y
  jsr print2     ; prints "Letter Stored."
  jsr DELAY_LOOP
  lda #%00000001 ; Clear display
  jsr lcd_instruction
print_word:              ; prints "Word: "
  lda message3,x
  beq init_printword2
  jsr print_char
  inx
  jmp print_word
init_printword2:
  ldx #0
print_word2:              ; prints the secret word
  lda secret,x
  beq init_print_guesses
  jsr print_char
  inx
  jmp print_word2
init_print_guesses:
  jsr DELAY_LOOP
  jsr DELAY_LOOP
  lda #%00000001 ; Clear display
  jsr lcd_instruction
  ldx #0
print_guesses:           ; prints "Make Guesses." At this point, player 2 would make the guesses
  lda message4,x
  beq jmp_loop
  jsr print_char
  inx
  jmp print_guesses

jmp_loop:
  jsr DELAY_LOOP
  jsr DELAY_LOOP
  jmp loop

init_guess: ; runs if presses > length (player 2's turn)
  inc presses
  ldy #0
make_guess: ;
  cpy length ; if the current index equals the length of secret, then branch back to the main loop
  beq inf_loop
  clc
  lda secret,y ; loads y index of secret into a register
  cmp counter  ; compares player 2's guess to y index of secret
  bne add_space ; if the guess is incorrect at that index, add an "x" at that index of the "guesses" String
  lda secret,y  ; if the guess is correct at that index, push that character at that index to the "guesses" String
  jsr push_char2
  inc correct ; increments correct each time a valid guess is made
  jmp make_guess

add_space: ; if a guess is incorrect at a particular index of secret, an "x" is added at that index of guesses
  lda test ; the test variable is used to determine whether or not it is the 1st guess or not
  bne test2 ; if it is not the 1st guess, branch to test2
  lda #"x"
  jsr push_char2 ; otherwise, push an "x" to the index y of guesses
  jmp make_guess

test2: ; this runs if it is not the 1st guess and it checks if a particular index of guesses already has an "x" there or not; as to not mark other correct guesses as incorrect
       ; for example, if the guesses string was "CxT", and "A" is guessed, the program should not display "xAx", but "CAT" instead.
  lda guesses,y
  cmp #"x"
  bne jmp_guess ; if an index is not filled with an "x", then ignore that index as a valid guess is already stored there.
  jsr push_char2 ; otherwise, push an "x" to overwrite the existing "x" (may not be needed)
  jmp make_guess
jmp_guess:
  iny      ; increments index
  jmp make_guess


inf_loop:
  lda correct
  bne inf_loop2 ; if correct is > 0, then branch back to main loop
  jsr DELAY_LOOP2
  dec guess_num ; if correct > 0, then that means that the current guess was incorrect and to decrement the number of guesses left
inf_loop2:
  stz correct ; resets correct to zero
  inc test    ; increments each time a guess is made
  jmp loop


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


print_guessString: ; prints the current String guesses, populated with the current string (filled or unfilled) of valid and/or invalid guesses
  ldy #0
guessString:
  lda guesses,y
  beq exit_print_guessString
  jsr print_char
  iny
  jmp guessString
exit_print_guessString:
  rts

guess_check: ; checks to see if a guess has been made yet
  lda test
  bne init_print_word3 ; branch if a guess has been made
  rts
init_print_word3: ; prints some padding and also the number of current guesses left
  lda #" "
  jsr print_char
  lda guess_num
  adc #"0"
  jsr print_char
  lda #" "
  jsr print_char
exit_printword3:
  lda #":"
  jsr print_char
  lda #" "
  jsr print_char
  jsr print_guessString ; prints the current String of guesses
  rts

push_char:     ; pushes a character to secret
  sta secret,y
  iny
  rts

push_char2:     ; pushes a character to guesses
  sta guesses,y
  iny
  rts

check_numGuesses: ; checks if guesses are depleted
  lda guess_num
  beq init_no_guesses ; branch if guesses are depleted
  rts

init_no_guesses:
  ldx #0
no_guesses:      ; prints "Guesses Depleted"
  lda message5,x
  beq exit_no_guesses
  jsr print_char
  inx
  jmp no_guesses
exit_no_guesses: ; halts program if guesses are depleted
  jmp exit_no_guesses


check_print_counter: ; if the user is entering the length variable, then display that as an ascii digit
  lda presses
  bne exit_check_print
  lda counter
  adc #"0"
  rts
exit_check_print:
  lda counter
  rts



message: .asciiz "Enter Length"
message1: .asciiz "Length Stored."
message2: .asciiz "Letter Stored."
message3: .asciiz "Word: "
message4: .asciiz "Make Guesses"
message5: .asciiz "Guesses Depleted"
message6: .asciiz "Enter Letter"
space: .asciiz "                "

print0:         ; prints "Enter Length"
  lda message,x
  beq exit_print0
  jsr print_char
  inx
  jmp print0
exit_print0:
  jsr DELAY_LOOP
  jsr DELAY_LOOP
  rts

print_space: ; prints enough spaces to overwrite display
  lda space,x
  beq exit_print_space
  jsr print_char
  inx
  jmp print_space
exit_print_space:
  rts

print1:         ; prints "Length Stored."
  lda message1,x
  beq exit_print1
  jsr print_char
  inx
  jmp print1
exit_print1:
  rts

print2:         ; prints "Letter Stored"
  lda message2,x
  beq exit_print2
  jsr print_char
  inx
  jmp print2
exit_print2:
  rts

init_print3:
  lda #%00000001 ; Clear display
  jsr lcd_instruction
  ldx #0
print3:
  lda message6,x
  beq exit_print3
  jsr print_char
  inx
  jmp print3
exit_print3:
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

DELAY_LOOP: ; 1 second delay
    tya
    LDX #$FF       ; Initialize X register to 255
    OUTER_LOOP:
        LDY #$FF   ; Initialize Y register to 255
        INNER_LOOP:
            NOP     ; Execute the NOP instruction, which takes 2 cycles
            DEY     ; Decrement the Y register, which takes 2 cycles
            BNE INNER_LOOP  ; Branch back to INNER_LOOP if Y is not zero, which takes 3 cycles
        DEX         ; Decrement the X register, which takes 2 cycles
        BNE OUTER_LOOP  ; Branch back to OUTER_LOOP if X is not zero, which takes 3 cycles
    tay
    RTS             ; Return from the subroutine
DELAY_LOOP2: ; 1 second delay
    tya
    LDX #100       ; Initialize X register to 255
    OUTER_LOOP2:
        LDY #$FF   ; Initialize Y register to 255
        INNER_LOOP2:
            NOP     ; Execute the NOP instruction, which takes 2 cycles
            DEY     ; Decrement the Y register, which takes 2 cycles
            BNE INNER_LOOP2  ; Branch back to INNER_LOOP if Y is not zero, which takes 3 cycles
        DEX         ; Decrement the X register, which takes 2 cycles
        BNE OUTER_LOOP2  ; Branch back to OUTER_LOOP if X is not zero, which takes 3 cycles
    tay
    RTS             ; Return from the subroutine


  .org $fffc
  .word reset
  .word $0000
