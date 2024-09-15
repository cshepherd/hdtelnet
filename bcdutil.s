*-------------------------------
* Validation, Decimal-to-Hex Module
* 9/15/2024 ballmerpeak
*-------------------------------

; testasc string to BINW little-endian hex:
;        jsr   copyasc
;        jsr   asc2bcd
;        jsr   BCD2BIN

; dotted-decimal keyin string to quadout hex:
;        jsr   quad2hex

; validate that a string contains at least one dot
hasdot  stz   dots
        ldx   #00
hdd3    lda   keyin,x
        beq   hdd4
        cmp   #'.'
        beq   hdd1
        inx
        bra   hdd3
hdd1    inc   dots
        inx 
        bra   hdd3
hdd2    sec
        rts
hdd4    lda   dots
        beq   hdd2
        clc
        rts

; validate that a string is 3 dots separated by at least 1 number
isquad  stz   dots
        ldx   #00
iq3     lda   keyin,x
        beq   iqe
        cmp   #'.'
        beq   iq2
        cmp   #$30
        blt   iqfail
        cmp   #$3a
        bge   iqfail        ; not numeric? fail
        inx
        bra   iq3
iq2     inc   dots
        cpx   #00           ; first character == dot? fail
        beq   iqfail
        dex
        lda   keyin,x
        cmp   #'.'          ; two dots in a row? fail
        beq   iqfail
        inx
        inx
        bra   iq3
iqfail  sec
        rts
iqe     cpx   #00           ; last character == first character? fail
        beq   iqfail
        dex
        lda   keyin,x
        cmp   #'.'
        beq   iqfail        ; last character == dot? fail
        lda   dots
        cmp   #3            ; != 3 dots? fail
        bne   iqfail
        clc
        rts
dots    db    0

quad2hex lda  #<testasc
        sta   $02           ; $02 = ptr to copied ascii
        lda   #>testasc
        sta   $03
        stz   quads         ; quads = quad counter 0-3
        ldx   #00           ; x = offset into dotted quad
qh4     ldy   #00           ; y = offset into copied ascii
qh1     lda   keyin,x
        beq   qh2
        cmp   #'.'
        beq   qh2           ; process if dot or EOL
        sta   ($02),y
        inx
        iny
        bra   qh1
qh2     lda   #00
        sta   ($02),Y       ; write ascii terminator
        phx
        phy                 ; save iterators
        jsr   copyasc
        jsr   asc2bcd
        jsr   BCD2BIN
        ply
        lda   BINW
        ldx   quads         ; quads = index into quadout
        sta   quadout,x
        inx
        cpx   #4
        beq   qh5
        stx   quads
        plx
        inx
        bra   qh4
qh5     plx
        rts

; copy testasc to ascii backwards to preserve leading 0s in ascii
copyasc jsr   clrascii
        ldx   #00
ca1     lda   testasc,x
        beq   ca2
        inx
        bra   ca1
ca2     lda   #<ascii
        sta   $00
        lda   #>ascii
        sta   $01
        ldy   #5
ca3     lda   testasc-1,x
        sta   ($00),Y
        dey
        dex
        bne   ca3
        rts

; reset ascii to '000000'
clrascii lda  #$30
        sta   ascii
        sta   ascii+1
        sta   ascii+2
        sta   ascii+3
        sta   ascii+4
        sta   ascii+5
        rts

asc2bcd lda   ascii
        sec
        sbc   #$30
        asl
        asl
        asl
        asl
        sta   BCDW+2
        lda   ascii+1
        sec
        sbc   #$30
        ora   BCDW+2
        sta   BCDW+2

        lda   ascii+2
        sec
        sbc   #$30
        asl
        asl
        asl
        asl
        sta   BCDW+1
        lda   ascii+3
        sec
        sbc   #$30
        ora   BCDW+1
        sta   BCDW+1

        lda   ascii+4
        sec
        sbc   #$30
        asl
        asl
        asl
        asl
        sta   BCDW
        lda   ascii+5
        sec
        sbc   #$30
        ora   BCDW
        sta   BCDW
        rts

BCD2BIN LDX   #16     ;Set the bit count
OUTER   LDY   #2      ;Set BCD byte count
        CLC           ;Ensure that C=0 on first shift
INNER   LDA   BCDW,Y  ;Divide the BCD byte by two
        ROR
        PHP           ;Save the bit that was shifted out
        BIT   #$80    ;Does the hi nybble need correction?
        BEQ   *+5
        SEC
        SBC   #$30
        BIT   #$08    ;Does the lo nybble need correction?
        BEQ   *+5
        SEC
        SBC   #$03
        PLP           ;Finally recover the carry
        STA   BCDW,Y
        DEY           ;Repeat for next BCD byte
        BPL   INNER
        ROR   BINW+1  ;Catch the remainder
        ROR   BINW+0
        DEX           ;And repeat
        BNE   OUTER
        rts

quads   db    00

testasc asc  '8080',00

ascii   asc  '000000',00

; LSB to MSB: 6502 is $02,$65,$00,$00
BCDW    db   00,00,00,00
; LSB to MSB: $FF is $FF,$00,$00,$00
BINW    db   00,00,00,00

quadout db   00,00,00,00
