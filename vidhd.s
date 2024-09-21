*-------------------------------
* HDTelnet Vidhd module
* 9/21/2024 ballmerpeak
*-------------------------------

; Detect VidHD card slot and set up Pascal vectors
vidinit     stz   $C00B       ; SETSLOTC3ROM: so we can detect a vidhd in slot 3
            jsr   vdetect
            bcs   novhd
            cmp   #3
            beq   nots3
            stz   $C00A       ; Back to Internal ROM for Slot 3 because the card isn't there
nots3       tax
            ora   #$C0
            sta   cardinit+2
            sta   cardwrite+2
            sta   readinit+2
            sta   readwrite+2
            jsr   readinit
            jsr   readwrite
            txa
            pha
            ldx   #<str_vfound
            ldy   #>str_vfound
            jsr   prtstr
            pla
            pha
            jsr   $fdda
            lda   #$8d
            jsr   $FDED
            pla
            clc
            rts

; no vidhd: init 80-column card, set vectors, and set carry
novhd       stz   $c00A
            jsr   $c300
            jsr   readinit
            jsr   readwrite
            ldx   #<str_nfound
            ldy   #>str_nfound
            jsr   prtstr
            sec
            rts

; read offset to pascal init routing
readinit    lda   $c30d
            sta   cardinit+1
            rts

; read offset to pascal write routine
readwrite   lda   $c30f
            sta   cardwrite+1
            rts

; cardinit: init pascal firmware
cardinit    jsr   $c300
            rts

; cardwrite: pascal write
cardwrite   jsr   $c300
            rts

; 05:07:0B:0C pascal card ids:
; slot 03 internal 80col adapter: 38:18 01:88 (ie after stz c00a)
; slot 03                  vidhd: 2C:18 01:8B
; slot 02 internal    modem port: 38:18 01:31
; slot 04 internal         mouse: 38:18 01:20

; vdetect
; returns with carry set if no vidhd found
; returns with carry clear and slot number in A if found
vdetect     ldx   #00
vloop       lda   vslots,x
            beq   vnotfound
            ora   #$C0
            sta   vgetid1+2
            sta   vgetid2+2
            sta   vgetid3+2
            sta   vgetid4+2
            jsr   vgetid1
            cmp   #$2C
            bne   vnc1
            jsr   vgetid2
            cmp   #$18
            bne   vnc1
            jsr   vgetid3
            cmp   #$01
            bne   vnc1
            jsr   vgetid4
            cmp   #$88
            bne   vnc1
            clc
            lda   vslots,x
            rts
vnc1        inx
            bra   vloop
vnotfound   sec
            rts

vslots      db    3,7,1,2,4,5,6,0

vgetid1     lda   $C005
            rts

vgetid2     lda   $c007
            rts

vgetid3     lda   $C00B
            rts

vgetid4     lda   $C00C
            rts

; x = low byte
; y = high byte
prtstr      stx   prtstr2+1
            sty   prtstr2+2
            ldx   #00
prtstr2     lda   str_vfound,x
            beq   prteof
            ora   #$80
            jsr   $fded
            inx
            bra   prtstr2
prteof      rts

str_vfound  asc   "VidHD found in Slot: ",00
str_nfound  asc   "VidHD not found; Using 80-column firmware.",$8D,00
