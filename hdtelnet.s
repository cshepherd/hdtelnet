*-------------------------------
* HD Telnet
* VidHD wide-carriage vt100 telnet client
* 8/18/2024 ballmerpeak
*-------------------------------

            org   $2000

; Do once
            jsr   wizinit   ; Initialize the Wiznet
            jsr   vidinit   ; Initialize VidHD output mode
            jsr   openconn  ; Open outbound TCP connection

; Do forever
mainloop    jsr   netin     ; Get a byte frm network
            bcc   localin   ; carry clear = no byte
            jsr   dispchar  ; Display received character
localin     jsr   kbd       ; Check keyboard
            bcc   mainloop  ; carry clear = no key
            jsr   out       ; Send new character
            bra   mainloop

cardslot    dfb   1 ; card slot

*-------------------------------
* Uthernet II configuration
my_gw       db    192,168,64,1
my_mask     db    255,255,255,0
mac_addr    db    $08,00,$20,$C0,$10,$20
my_ip       db    192,168,64,254
port_num    ddb   6502
*-------------------------------
* destination
dest_ip     db    192,168,64,1
dest_port   ddb   23
*-------------------------------
* internal variables
active      db    0
rx_rd       db    00,00
rx_rd_orig  db    00,00
rx_rcvd     db    00,00
tx_wr       db    00,00
tx_ptr      db    00,00
tx_free     db    00,00

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
            lda   cardslot
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

            clc
            ply
            plx
            pla
            rts

initfail    sec
            brk  $00                  ; YOU LOSE
            ply
            plx
            pla
            rts

; set up uthernet II MAC and IP params
; then issue TCP CONNECT command to Wiznet
; all regs preserved
openconn    pha
            phx
            phy
            lda   #$03                ; Indirect Bus IF mode, Address Auto-Increment
            jsr   setglobalreg

            lda   #00
            ldx   #01
            jsr   setaddr             ; 0001 - Gateway Address

            ldx   #00                 ; set gw(4)+mask(4)+mac(6)+ip(4)
]gw         lda   my_gw,x
            jsr   setdata
            inx
            cpx   #18+1
            bne   ]gw

            lda   #00
            ldx   #$1a
            jsr   setaddr             ; 001A - rx mem

            lda   #$55                ; 00 = 4x 2KB socket buffers
            jsr   setdata             ; rx mem: 2K for up to 4 socks
            jsr   setdata             ; tx mem (via auto inc): 2K for up to 4 sockets

            lda   #$04
            ldx   #$04
            jsr   setaddr             ; 0404 = S0 source port
            lda   port_num
            jsr   setdata
            lda   port_num+1
            jsr   setdata

            lda   #$04
            ldx   #$00
            jsr   setaddr             ; $0400 = S0 mode port
            lda   #$01
            jsr   setdata             ; $01 = TCP

            lda   #$04
            ldx   #$01
            jsr   setaddr             ; $0401 = S0 command port
            lda   #$01
            jsr   setdata             ; send OPEN command

            lda   #$04
            ldx   #$0C
            jsr   setaddr             ; $040C = S0 dest ip
            ldx   #0
]dest       lda   dest_ip,x
            jsr   setdata
            inx
            cpx   #4+2
            bne   ]dest               ; dest ip and port now set

]slp        lda   #$04
            ldx   #$03
            jsr   setaddr             ; $0403 = S0 status register
            jsr   getdata
            beq   sockfail
            cmp   #$13
            beq   initpass
            bra   ]slp                ; loop until status of SOCK_INIT is reached
initpass    lda   #$04
            ldx   #$01
            jsr   setaddr             ; $0401 = socket command register
            lda   #04
            jsr   setdata             ; $04 = CONNECT

            ply
            plx
            pla
            rts
sockfail    brk   $01                 ; YOU LOSE (SOCK_CLOSED)

; 'ring' function (check for ring)
; all regs preserved
ring        pha
            phx
            phy
            lda   #$04
            ldx   #$03
            jsr   setaddr             ; $0403 = socket status register
            jsr   getdata
            beq   closed
            cmp   #$17                ; established?
            bne   closed

            lda   #01                 ; answer
            sta   active

            ply
            plx
            pla
            sec                       ; SEC = connected
            rts
closed      lda   #00
            sta   active
            ply
            plx
            pla
            clc                       ; CLC = not connected
            rts

; disconnect / close tcp socket
; all regs preserved
discon      pha
            phx
            phy
            lda   #$04
            ldx   #$01
            jsr   setaddr             ; S0 command register
            lda   #$08                ; DISCON
            jsr   setdata
            ply
            plx
            pla
            clc
            rts

; 'flush' function
; flush wiznet buffer
; all regs preserved
flush       pha
            phx
            phy
            ldy   #1
            lda   #$04
            ldx   #$28                ; add rx_rcvd to rx_rd_orig and store back in $0428
            jsr   setaddr
            lda   rx_rd_orig+1
            jsr   setdata
            lda   rx_rd_orig
            jsr   setdata

            ldy   #2
            ldx   #$01
            jsr   setaddrlo           ; S0 command register
            lda   #$40
            jsr   setdata             ; RECV command to signal we processed the last chunk

            ply
            plx
            pha
            rts

; netin
; get one byte frm wiznet buffer
; if carry set, byte in A
; if carry clear, no byte
; xy preserved
netin       phx
            phy
            lda   #$04
            ldx   #$28
            jsr   setaddr             ; S0_RX_RD (un-translated rx base)
            jsr   getdata
            sta   rx_rd+1             ; +1 to reverse endianness
            sta   rx_rd_orig+1
            jsr   getdata
            sta   rx_rd
            sta   rx_rd_orig

            lda   rx_rd               ; AND #$07ff
            and   #$FF                ; ADD #$6000
            sta   rx_rd               ; former 65816 zone
            lda   rx_rd+1             ; (hence little endian)
            and   #$07
            clc
            adc   #$60
            sta   rx_rd+1

            lda   #$04
            ldx   #$26
            jsr   setaddr             ; rx size = $0426
            jsr   getdata
            sta   rx_rcvd+1
            jsr   getdata
            sta   rx_rcvd             ; rx_rcvd now has bytes rcvd
            bne   have_byte
            lda   rx_rcvd+1
            bne   have_byte

            ply
            plx
            clc
            rts                       ; no byte. clc/rts

have_byte   lda   rx_rd+1             ; at least 1 byte available
            ldx   rx_rd
            jsr   setaddr             ; start at this base address
            jsr   getdata             ; read the byte from the buffer
            pha

            lda   rx_rd_orig
            clc
            adc   #$01
            sta   rx_rd_orig          ; this is what we'll write back to rx_rd
            lda   rx_rd_orig+1
            adc   #$00
            sta   rx_rd_orig+1        ; converted 65816 addition

            lda   rx_rcvd
            sec
            sbc   #$01
            sta   rx_rcvd             ; also subtract 1 from rx_rcvd
            lda   rx_rcvd+1
            sbc   #$00
            sta   rx_rcvd+1           ; converted 65816 subtraction

            ldy   #1
            lda   #$04
            ldx   #$28                ; add rx_rcvd to rx_rd_orig and store back in $0428
            jsr   setaddr
            lda   rx_rd_orig+1
            jsr   setdata
            lda   rx_rd_orig
            jsr   setdata

* muti-byte-receive support broken
*            lda   rx_rcvd
*            bne   have_byte2
*            lda   rx_rcvd+1
*            bne   have_byte2

            ldx   #$01
            jsr   setaddrlo           ; S0 command register
            lda   #$40
            jsr   setdata             ; RECV command

have_byte2  pla                       ; restore the byte
            ply                       ; restore saved regs
            plx
            sec
            rts

; out function
; add one byte to wiznet buffer
; a = byte, xy preserved
bytes       db    00,00
out         phx
            phy
            pha                       ; save data byte
            lda   #1
            sta   bytes
            lda   #$04
            ldx   #$24
            jsr   setaddr             ; S0_TX_WR
            jsr   getdata
            sta   tx_wr+1             ; +1 to reverse endianness
            sta   tx_ptr+1
            jsr   getdata
            sta   tx_wr               ; tx_wr is the translated 5100 address we write to
            sta   tx_ptr              ; tx_ptr will be the exact original value
                                      ; + 4KB, 8KB etc without translation

            lda   tx_wr               ; AND #$07ff
            and   #$FF                ; ADD #$4000
            sta   tx_wr               ; former 65816 zone
            lda   tx_wr+1             ; (hence little endian)
            and   #$07
            clc
            adc   #$40
            sta   tx_wr+1

]txwt       lda   #$04
            ldx   #$20
            jsr   setaddr             ; tx free space = $0420 blaze it
            jsr   getdata
            sta   tx_free+1
            jsr   getdata
            sta   tx_free             ; store little-endian

            lda   tx_free+1
            bne   havebyte3
            lda   tx_free
            bne   havebyte3
            bra   ]txwt               ; wait if no tx buffer byte free
                                      ; (i srsly doubt this ever happens)

havebyte3   lda   tx_wr+1
            ldx   tx_wr               ; note little-endian load
            jsr   setaddr             ; start at this base address

            pla
            jsr   setdata             ; send the byte
            pha
            cmp   #$0D
            bne   notcr
            lda   #$0a
            jsr   setdata             ; add cr after lf
            inc   bytes

notcr       lda   tx_ptr
            clc
            adc   bytes
            sta   tx_ptr
            lda   tx_ptr+1
            adc   #00
            sta   tx_ptr+1

            lda   #$04
            ldx   #$24
            jsr   setaddr
            lda   tx_ptr+1
            jsr   setdata
            lda   tx_ptr
            jsr   setdata             ; inc S0_TX_WR to add the byte

            lda   #$04
            ldx   #$01
            jsr   setaddr             ; S0 command register
            lda   #$20
            jsr   setdata             ; SEND command

wt          nop
            lda   #$04
            ldx   #$01
            jsr   setaddr
            jsr   getdata
            bne   wt          ; wait for send completion

            pla               ; restore a to print the byte
            ply
            plx
            clc
            rts

; kbd
; Check if a character is being entered
; if carry set, byte in A
; if carry clear, no byte
kbd         clc
            bit   $c000
            bpl   nokey
            lda   $c010
            sec
nokey       rts

; dispchar
; Write the character in A to the screen
; TODO
dispchar    jsr   $FDED
            rts


; vidinit
; Initialize video / VidHD / etc to desired mode
; TODO
vidinit     jsr   $c300
            jsr   $FC58
            rts
