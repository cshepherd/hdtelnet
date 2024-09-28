*-------------------------------
* vt100 / ansi module
* 9/28/2024 ballmerpeak
*-------------------------------

; vt100 character positioning and screen clearing
rcvd_esc    jsr   netin         ; get second character
            cmp   #'['
            beq   rcvd_csi
; take no action on this code
do_nothing  rts

csi_arg1    db    00,00,00,00,00 ; 5 bytes for arg1
csi_arg2    db    00,00,00,00,00 ; 5 bytes for arg2
csi_arg3    db    00,00,00,00,00 ; 5 bytes for arg2
csi_arg4    db    00,00,00,00,00 ; 5 bytes for arg2
argno       db    00             ; 1 byte for current arg number
arg1_dec    db    00             ; arg 1, decoded
arg2_dec    db    00             ; arg 2, decoded
arg3_dec    db    00             ; arg 3, decoded
arg4_dec    db    00             ; arg 4, decoded
csi_q       db    00

; esc+[ = beginning of CSI sequence
rcvd_csi    ldx   #00
            txa
]z1         sta   csi_arg1,x    ; clear out any potential arguments
            inx
            cpx   #26
            bne   ]z1
csi_in      jsr   netin
            cmp   #'?'
            bne   csi2
            inc   csi_q
            bra   csi_in
csi2        cmp   #'0'
            blt   notnum
            cmp   #':'
            blt   is_num
notnum      cmp   #';'
            beq   inc_argno
            cmp   #$2C          ; merlin32 hates #','
            beq   inc_argno
            cmp   #'H'
            beq   csi_movto
            cmp   #'f'
            beq   csi_movto
            cmp   #'J'
            beq   csi_erase
            cmp   #'A'
            beq   csi_curup
            cmp   #'B'
            beq   csi_curdown
            cmp   #'C'
            beq   csi_curfwd
            cmp   #'D'
            beq   csi_curback
            rts                 ; ignore most

csi_curback jmp   csi_curback2
csi_curup   jmp   csi_curup2
csi_erase   jmp   csi_erase2
csi_curdown jmp   csi_curdown2
csi_curfwd  jmp   csi_curfwd2

; increment arg count and store digit for decoding
inc_argno   inc   argno
            bra   csi_in
is_num      pha
            lda   argno
            beq   store_arg1
            cmp   #1
            beq   store_arg2
            cmp   #2
            beq   store_arg3

store_arg4  ldx   #00
]z4         lda   csi_arg4,X
            beq   sa4h
            inx 
            bra   ]z4
sa4h        pla
            sta   csi_arg4,x
            bra   csi_in

store_arg3  ldx   #00
]z5         lda   csi_arg3,X
            beq   sa3h
            inx
            bra   ]z5
sa3h        pla
            sta   csi_arg3,X
            bra   csi_in

store_arg2  ldx   #00
]z2         lda   csi_arg2,X
            beq   sa2h
            inx
            bra   ]z2
sa2h        pla
            sta   csi_arg2,X
            jmp   csi_in

store_arg1  ldx   #00
]z3         lda   csi_arg1,X
            beq   sa1h
            inx
            bra   ]z3
sa1h        pla
            sta   csi_arg1,X
            jmp   csi_in

csi_movto   jsr   decode_args
            lda   arg1_dec
            beq   csim1
            dec
csim1       sta   $24
            lda   arg2_dec
            beq   csim2
            dec
csim2       sta   $25
            inc   xy_first
            rts

csi_erase2   jsr   $FC58
            rts

csi_curup2   dec   $25
            lda   $25
            bne   cu1
            stz   $25
cu1         inc   xy_first
            rts

csi_curdown2 inc   $25
            inc   xy_first
            rts

csi_curfwd2  inc   $24
            inc   xy_first
            rts

csi_curback2 dec   $24
            lda   $24
            bne   cb1
            stz   $24
cb1         inc   xy_first
            rts

decode_args ldx   #00
]da1        lda   csi_arg1,X
            beq   da1f
            sta   testasc,X
            inx
            bra   ]da1
da1f        sta   testasc,x
            jsr   copyasc
            jsr   asc2bcd
            jsr   BCD2BIN
            lda   BINW
            sta   arg1_dec

            ldx   #00
]da2        lda   csi_arg2,x
            beq   da2f
            sta   testasc,x
            inx
            bra   ]da2
da2f        sta   testasc,X
            jsr   copyasc
            jsr   asc2bcd
            jsr   BCD2BIN
            lda   BINW
            sta   arg2_dec

            ldx   #00
]da3        lda   csi_arg3,x
            beq   da3f
            sta   testasc,X
            inx
            bra   ]da3
da3f        sta   testasc,X
            jsr   copyasc
            jsr   asc2bcd
            jsr   BCD2BIN
            lda   BINW
            sta   arg3_dec

            ldx   #00
]da4        lda   csi_arg4,X
            beq   da4f
            sta   testasc,X
            inx
            bra   ]da4
da4f        sta   testasc,X
            jsr   copyasc
            jsr   asc2bcd
            jsr   BCD2BIN
            lda   BINW
            sta   arg4_dec            
            rts
