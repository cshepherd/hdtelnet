*-------------------------------
* HDTelnet ADB module
* 9/21/2024 ballmerpeak
*-------------------------------

; set vidhd text mode
; 0 - 40x24 (esc-4)
; 1 - 80x24 (esc-8)
; 2 - 80x45 (esc-1) (vhd only)
; 3 - 120x67 (esc-2) (vhd only)
; 4 - 240x135 (esc-3) (vhd only)
vidhd_mode  phx
            ldx   #$35
            jsr   adb_sendkey
            pla
            asl
            tax
            lda   vmodes,x
            tax
            jsr   adb_sendkey
vhdget      jsr   $c305      ; TODO change with slot number
            rts

vmodes       db    $15,$1c,$12,$13,$14

adb_benable lda   #$04
            sta   $c026
            jsr   adb_wait
            lda   #$10
            sta   $c026
            jsr   adb_wait
            rts

adb_sendkey lda   #$11
            sta   $c026
            jsr   adb_wait
            txa
            sta   $c026
            jsr   adb_wait
            lda   #$11
            sta   $c026
            jsr   adb_wait
            txa
            ora   $80
            sta   $c026
            jsr   adb_wait
            rts

adb_wait    lda   #10
            jsr   $fca8
            rts
