*-------------------------------
* vt100 / ansi module
* 9/28/2024 ballmerpeak
*-------------------------------

; vt100 character positioning and screen clearing
rcvd_esc    jsr   netin         ; get second character
            cmp   #'['
            beq   rcvd_csi
            cmp   #'('          ; set character set
            beq   set_charset
            cmp   #')'          ; select character set
            beq   set_charset
; take no action on this code
do_nothing  rts

; set / select charset require us to get/throw away another character
set_charset jsr   netin
            rts

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
            lda   #$1E
            jsr   cardwrite
            lda   arg2_dec
            beq   csimv1
            dec
csimv1      cmp   max_h
            blt   csimvh
            lda   max_h
csimvh      clc
            adc   #$20
            jsr   cardwrite
            lda   arg1_dec
            beq   csimh1
            dec
csimh1      cmp   max_v
            blt   csimvv
            lda   max_v
csimvv      clc
            adc   #$20
            jsr   cardwrite
            rts

csi_erase2   jsr   $FC58
            stz   cursor_x
            stz   cursor_y
            rts

csi_curup2   dec   $25
            lda   $25
            bne   cu1
            stz   $25
cu1         inc   xy_first
            lda   $25
            sta   cursor_y
            rts

csi_curdown2 jsr  decode_args
             ldx  arg1_dec
            bne   cdn
            ldx   #1
cdn         lda   #10
            phx
            jsr   cardwrite
            plx
            dex
            bne   cdn
            lda   $25
            sta   cursor_y
            rts

csi_curfwd2  lda  $25
            pha
            jsr   decode_args
            ldx   arg1_dec
            bne   cfw
            ldx   #1
cfw         lda   #28
            phx
            jsr   cardwrite
            plx
            dex
            bne   cfw
            inc   cursor_x
            pla
            cmp   $25
            beq   cfx
            stz   cursor_x
            lda   $25
            sta   cursor_y
cfx         rts

csi_curback2 lda  $25
            pha
            jsr   decode_args
            ldx   arg1_dec
            bne   cbk
            ldx   #1
cbk         lda   #8
            phx
            jsr   cardwrite
            plx
            dex
            bne   cbk
            dec   cursor_x
            pla
            cmp   $25
            beq   cbx
            stz   cursor_x
            lda   $25
            sta   cursor_y
cbx         rts

decode_args lda   csi_arg1
            beq   da1ff
            ldx   #00
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
da1ff       sta   arg1_dec

            lda   csi_arg2
            beq   da2ff
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
da2ff       sta   arg2_dec

            lda   csi_arg3
            beq   da3ff
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
da3ff       sta   arg3_dec

            lda   csi_arg4
            beq   da4ff
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
da4ff       sta   arg4_dec
            rts
