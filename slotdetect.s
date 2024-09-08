*-------------------------------
* Slot Detection test
* 9/7/2024 ballmerpeak
*-------------------------------

            org   $2000

            ldx   #$FF
]next       inx
            lda   slots,x
            beq   notfound
            jsr   wizinit
            bcs   ]next
            jsr   $fdda
            lda   #$0D
            jsr   $fded
            rts

notfound    brk   $00

; Order to attempt detection
slots       db    01,07,02,04,03,05,06,00

; set addr
; a = reg no hi
; x = reg no lo
setaddr
]cn1        sta   $c000       ; ]cn1+1 = card_base + 1
; set addr lo only
; x = reg no lo
setaddrlo
]cn2        stx   $c000       ; ]cn2+1 = card_base + 2
            rts

; set global reg
; a = value
setglobalreg
]cn3        sta   $c000       ; ]cn3+1 = card_base + 0
            rts

; read global reg
; a = value
getglobalreg
]cn6        lda   $c000       ; ]cn6+1 = card_base + 0
            rts

; send data
; a = value
setdata
]cn4        sta   $c000       ; ]cn4+1 = card_base + 3
            rts

; read data
; a = value
getdata
]cn5        lda   $c000       ; ]cn5+1 = card_base + 3
            rts

; Just reset the Uthernet II
; all regs preserved
wizinit     pha
            phx
            phy
            asl
            asl
            asl
            asl
            clc
            adc   #$84
            sta   ]cn3+1
            sta   ]cn6+1
            inc
            sta   ]cn1+1
            inc
            sta   ]cn2+1
            inc
            sta   ]cn4+1
            sta   ]cn5+1

            lda   #$80                ; $80 = reset
            jsr   setglobalreg

            jsr   getglobalreg
            bne   initfail

            lda   #$03
            jsr   setglobalreg
            jsr   getglobalreg
            cmp   #$03
            bne   initfail

            clc
            ply
            plx
            pla
            rts

initfail    sec
            ply
            plx
            pla
            rts
