*-------------------------------
* DHCP test
* 9/7/2024 ballmerpeak
*-------------------------------

            org   $2000

            jsr   wizinit   ; Initialize the Wiznet
            jsr   udpsetup  ; Set up UDP socket
            jsr   discover  ; Send DHCPDISCOVER
;            jsr   getoffer  ; Await / get DHCPOFFER
;            jsr   request   ; Send DHCPREQUEST
;            jsr   getack    ; Await / get DHCPACK

            rts

*-------------------------------
* Uthernet II configuration
my_gw       db    255,255,255,255
my_mask     db    255,255,255,255
mac_addr    db    $08,00,$20,$C0,$10,$20
my_ip       db    0,0,0,0

*-------------------------------
* internal variables
active      db    0
rx_rd       db    00,00
rx_rd_orig  db    00,00
rx_rcvd     db    00,00
tx_wr       db    00,00
tx_ptr      db    00,00
tx_free     db    00,00
stackptr    db    0
cardslot    db    1

*-------------------------------
* DHCPDISCOVER datagram
* Sent to MAC FF:FF:FF:FF:FF:FF
dhcpdiscover = *
            db    $01                    ; OP 0x01
            db    $01                    ; HTYPE 0x01
            db    $06                    ; HLEN 0x06
            db    $00                    ; HOPS 0x00
discxid     db    $39,$03,$F3,$26        ; XID
            db    $00,$00                ; SECS
discflags   db    $00,$00                ; FLAGS
ciaddr      db    $00,$00,$00,$00        ; Client IP Address
yiaddr      db    $00,$00,$00,$00        ; Your IP Address
siaddr      db    $00,$00,$00,$00        ; Server IP Address
giaddr      db    $00,$00,$00,$00        ; Gateway IP Address
chaddr      db    $08,00,$20,$C0,$10,$20 ; Client Hardware Address
            ds    10                     ; chaddr padding
sname       ds    64                     ; Server Name (optional)
bootfile    ds    128                    ; BOOTP legacy, 'boot file'
magic       db    $63,$82,$53,$63        ; Magic Cookie
* options
            db    53,01,01               ; Message Type: DHCPDISCOVER
            db    61,07,01               ; Client ID: 01 + ether address
discid      db    $08,00,$20,$C0,$10,$20
            db    12,04                  ; Hostname + strlen(hostname)
            asc   'iigs'
            db    55,06                  ; Params (6 of them)
            db    01,03,06,15,58,59      ; Params: subnetMask, routers, dns, domainName, dhcpT1value, dhcpT2value
            db    255                    ; endParam
dhcpdiscoverpage2 = dhcpdiscover+255
discover_length = * - dhcpdiscoverpage2

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

; set up uthernet II MAC and IP params
; then send DNS question via wiznet
; all regs preserved
udpsetup    pha
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
            jsr   setaddr             ; 0404 = S0 source port (68)
            lda   #00
            jsr   setdata
            lda   #68
            jsr   setdata

            lda   #$04
            ldx   #$00
            jsr   setaddr             ; $0400 = S0 mode port
            lda   #$02
            jsr   setdata             ; $02 = UDP

            lda   #$04
            ldx   #$01
            jsr   setaddr             ; $0401 = S0 command port
            lda   #$01
            jsr   setdata             ; send OPEN command

            lda   #$04
            ldx   #$06
            jsr   setaddr
            lda   #$ff
            jsr   setdata
            jsr   setdata
            jsr   setdata
            jsr   setdata
            jsr   setdata
            jsr   setdata             ; destination MAC: ff:ff:ff:ff:ff:ff (broadcast)

            lda   #$ff
            jsr   setdata
            jsr   setdata
            jsr   setdata
            jsr   setdata             ; destination address: 255.255.255.255 (broadcast)

            lda   #00
            jsr   setdata
            lda   #67
            jsr   setdata             ; dest port 67

            lda   #$ff

            ply
            plx
            pla
            rts

; Send DHCPDISCOVER
; all regs preserved
discover    phx
            phy
            pha
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

            ldx   #00
]slp        lda   dhcpdiscover,x
            jsr   setdata             ; send the byte
            inx
            cpx   #$FF
            bne   ]slp

            ldx   #00
]slp2       lda   dhcpdiscover+255,x  ; second loop because discover is more than 255
            jsr   setdata
            inx
            cpx   #discover_length
            bne   ]slp2

notcr       lda   tx_ptr
            clc
            adc   #discover_length
            sta   tx_ptr
            lda   tx_ptr+1
            adc   #01
            sta   tx_ptr+1

            lda   #$04
            ldx   #$24
            jsr   setaddr
            lda   tx_ptr+1
            jsr   setdata
            lda   tx_ptr
            jsr   setdata             ; inc S0_TX_WR to add the bytes

            lda   #$04
            ldx   #$01
            jsr   setaddr             ; S0 command register
            lda   #$21
            jsr   setdata             ; SEND_MAC command

wt          nop
            lda   #$04
            ldx   #$01
            jsr   setaddr
            jsr   getdata
            bne   wt          ; wait for send completion

            pla
            ply
            plx
            clc
            rts
