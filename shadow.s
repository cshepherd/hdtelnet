*-------------------------------
* HD Telnet
* Screen RAM shadowing module
* 10/4/2024 ballmerpeak
*-------------------------------

; byte to write in A
; x/y position in cursor_x / cursor_y
s_write     pha
            lda  cursor_y
            asl
            tax
            lda  slookup,X    ; Low byte first (dw pseudo-op)
            clc
            adc  cursor_x
            sta  $00
            lda  slookup+1,x
            adc  #00          ; Carry if necessary
            sta  $01
            pla
            stz  $c005        ; Write to Aux RAM
            sta  ($00)
            stz  $c004        ; Write to Main RAM
            rts 

; start of each horizontal line in 'shadow' ram
slookup     dw   $2000
            dw   $20f0
            dw   $21e0
            dw   $22d0
            dw   $23c0
            dw   $24b0
            dw   $25a0
            dw   $2690
            dw   $2780
            dw   $2870
            dw   $2960
            dw   $2a50
            dw   $2b40
            dw   $2c30
            dw   $2d20
            dw   $2e10
            dw   $2f00
            dw   $2ff0
            dw   $30e0
            dw   $31d0
            dw   $32c0
            dw   $33b0
            dw   $34a0
            dw   $3590
            dw   $3680
            dw   $3770
            dw   $3860
            dw   $3950
            dw   $3a40
            dw   $3b30
            dw   $3c20
            dw   $3d10
            dw   $3e00
            dw   $3ef0
            dw   $3fe0
            dw   $40d0
            dw   $41c0
            dw   $42b0
            dw   $43a0
            dw   $4490
            dw   $4580
            dw   $4670
            dw   $4760
            dw   $4850
            dw   $4940
            dw   $4a30
            dw   $4b20
            dw   $4c10
            dw   $4d00
            dw   $4df0
            dw   $4ee0
            dw   $4fd0
            dw   $50c0
            dw   $51b0
            dw   $52a0
            dw   $5390
            dw   $5480
            dw   $5570
            dw   $5660
            dw   $5750
            dw   $5840
            dw   $5930
            dw   $5a20
            dw   $5b10
            dw   $5c00
            dw   $5cf0
            dw   $5de0
            dw   $5ed0
            dw   $5fc0
            dw   $60b0
            dw   $61a0
            dw   $6290
            dw   $6380
            dw   $6470
            dw   $6560
            dw   $6650
            dw   $6740
            dw   $6830
            dw   $6920
            dw   $6a10
            dw   $6b00
            dw   $6bf0
            dw   $6ce0
            dw   $6dd0
            dw   $6ec0
            dw   $6fb0
            dw   $70a0
            dw   $7190
            dw   $7280
            dw   $7370
            dw   $7460
            dw   $7550
            dw   $7640
            dw   $7730
            dw   $7820
            dw   $7910
            dw   $7a00
            dw   $7af0
            dw   $7be0
            dw   $7cd0
            dw   $7dc0
            dw   $7eb0
            dw   $7fa0
            dw   $8090
            dw   $8180
            dw   $8270
            dw   $8360
            dw   $8450
            dw   $8540
            dw   $8630
            dw   $8720
            dw   $8810
            dw   $8900
            dw   $89f0
            dw   $8ae0
            dw   $8bd0
            dw   $8cc0
            dw   $8db0
            dw   $8ea0
            dw   $8f90
            dw   $9080
            dw   $9170
            dw   $9260
            dw   $9350
            dw   $9440
            dw   $9530
            dw   $9620
            dw   $9710
            dw   $9800
            dw   $98f0
            dw   $99e0
            dw   $9ad0
            dw   $9bc0
            dw   $9cb0
            dw   $9da0
