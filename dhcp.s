*-------------------------------
* DHCP module
* 9/15/2024 ballmerpeak
*-------------------------------

*-------------------------------
* DHCP params
server_addr db    0,0,0,0

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

; set up uthernet II MAC and IP params
; then send DNS question via wiznet
; all regs preserved
dhcpsetup   pha
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
            bne   havebyte5
            lda   tx_free
            bne   havebyte5
            bra   ]txwt               ; wait if no tx buffer byte free
                                      ; (i srsly doubt this ever happens)

havebyte5   lda   tx_wr+1
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

            lda   tx_ptr
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

wt9         nop
            lda   #$04
            ldx   #$01
            jsr   setaddr
            jsr   getdata
            bne   wt9                 ; wait for send completion

            pla
            ply
            plx
            clc
            rts

dhcpoffer   ds    400                 ; dhcpoffer will be about 342 bytes
offerdata   =     dhcpoffer+8         ; skip src ip, src port, length
magiccookie =     offerdata+236
offeropts   =     magiccookie+4

; parseoffer
; parse DHCPOFFER
nomoreopts  clc
            rts

parseoffer  lda   magiccookie
            cmp   #$63
            bne   parsefail
            lda   magiccookie+1
            cmp   #$82
            bne   parsefail
            lda   magiccookie+2
            cmp   #$53
            bne   parsefail
            lda   magiccookie+3
            cmp   #$63
            bne   parsefail

            lda   offerdata+16
            sta   my_ip
            lda   offerdata+17
            sta   my_ip+1
            lda   offerdata+18
            sta   my_ip+2
            lda   offerdata+19
            sta   my_ip+3

            lda   offerdata+20
            sta   server_addr
            lda   offerdata+21
            sta   server_addr+1
            lda   offerdata+22
            sta   server_addr+2
            lda   offerdata+23
            sta   server_addr+3

            ldx   #00
]nextopt    lda   offeropts,x
            cmp   #$35               ; DHCP Message Type
            beq   msgtype
            cmp   #$36               ; DHCP Server Identifier (skip it)
            beq   generic
            cmp   #$33               ; DHCP address lease time (skip it)
            beq   generic
            cmp   #$01               ; Subnet mask
            beq   mask
            cmp   #$03               ; Router
            beq   router
            cmp   #$06               ; DNS server
            beq   dnsserver
            cmp   #$ff
            beq   nomoreopts
            bra   generic            ; unknown option (skip it)

parsefail   sec
            rts

msgtype     inx
            lda   offeropts,x
            cmp   #1                 ; 0102: DHCPOFFER
            bne   parsefail
            inx
            lda   offeropts,x
            cmp   #2
            bne   parsefail          ; 0102: DHCPOFFER
            inx
            bra   ]nextopt

generic     inx
            lda   offeropts,x        ; option length
            sta   $00
            txa
            clc
            adc   $00
            tax
            inx
            bra   ]nextopt

mask        inx
            inx                       ; skip length
            lda   offeropts,x
            sta   my_mask
            inx
            lda   offeropts,x
            sta   my_mask+1
            inx
            lda   offeropts,x
            sta   my_mask+2
            inx
            lda   offeropts,x
            sta   my_mask+3
            inx
            bra   ]nextopt

router      inx
            inx                       ; skip length
            lda   offeropts,x
            sta   my_gw
            inx
            lda   offeropts,x
            sta   my_gw+1
            inx
            lda   offeropts,x
            sta   my_gw+2
            inx
            lda   offeropts,x
            sta   my_gw+3
            inx
            jmp   ]nextopt

dnsserver   inx
            inx                       ; skip length
            lda   offeropts,x
            sta   dns_ip
            inx
            lda   offeropts,x
            sta   dns_ip+1
            inx
            lda   offeropts,x
            sta   dns_ip+2
            inx
            lda   offeropts,x
            sta   dns_ip+3
            inx
            jmp   ]nextopt

; getoffer
; receive DHCPOFFER
getoffer    phx
            phy
            pha
            ldx   #$28
            jsr   setaddrlo           ; S0_RX_RD (un-translated rx base)
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

]dnswt      lda   #$04
            ldx   #$26
            jsr   setaddr             ; rx size = $0426
            jsr   getdata
            sta   rx_rcvd+1
            jsr   getdata
            sta   rx_rcvd             ; rx_rcvd now has bytes rcvd
            bne   have_byteD
            lda   rx_rcvd+1
            bne   have_byteD

            bra   ]dnswt

have_byteD  lda   rx_rd+1             ; at least 1 byte available
            ldx   rx_rd
            jsr   setaddr             ; start at this base address
            ldx   #00
]rdresp     jsr   getdata             ; read the byte from the buffer
            sta   dhcpoffer,x
            inx
            cpx   #255
            bne   ]rdresp

            ldx   #00
]rdresp     jsr   getdata             ; read the byte from the buffer
            sta   dhcpoffer+255,x
            inx
            cpx   rx_rcvd
            bne   ]rdresp

            lda   rx_rd_orig
            clc
            adc   rx_rcvd
            sta   rx_rd_orig          ; this is what we'll write back to rx_rd
            lda   rx_rd_orig+1
            adc   rx_rcvd+1
            sta   rx_rd_orig+1        ; converted 65816 addition

            ldy   #1
            lda   #$04
            ldx   #$28                ; add rx_rcvd to rx_rd_orig and store back in $0428
            jsr   setaddr
            lda   rx_rd_orig+1
            jsr   setdata
            lda   rx_rd_orig
            jsr   setdata

            ldx   #$01
            jsr   setaddrlo           ; S0 command register
            lda   #$40
            jsr   setdata             ; RECV command

            pla                       ; restore the byte
            ply                       ; restore saved regs
            plx
            sec
            rts

*-------------------------------
* DHCPREQUEST datagram
* Sent to MAC FF:FF:FF:FF:FF:FF
dhcprequest = *
            db    $01                    ; OP 0x01
            db    $01                    ; HTYPE 0x01
            db    $06                    ; HLEN 0x06
            db    $00                    ; HOPS 0x00
reqxid      db    $39,$03,$F3,$26        ; XID
            db    $00,$00                ; SECS
reqflags    db    $00,$00                ; FLAGS
rciaddr     db    $00,$00,$00,$00        ; Client IP Address
ryiaddr     db    $00,$00,$00,$00        ; Your IP Address
rsiaddr     db    $00,$00,$00,$00        ; Server IP Address
rgiaddr     db    $00,$00,$00,$00        ; Gateway IP Address
rchaddr     db    $08,00,$20,$C0,$10,$20 ; Client Hardware Address
            ds    10                     ; chaddr padding
rsname      ds    64                     ; Server Name (optional)
rbootfile   ds    128                    ; BOOTP legacy, 'boot file'
rmagic      db    $63,$82,$53,$63        ; Magic Cookie
* options
            db    $35,01,03              ; Message Type: DHCPREQUEST
            db    $32,$04
rreqip      db    00,00,00,00            ; requested client ip
            db    $36,$04
rserverip   db    00,00,00,00            ; requested server ip
            db    $ff                    ; end of request
dhcprequestpage2 = dhcprequest+255
request_length = * - dhcprequestpage2    ; like a full page +1 or 2, that's life

; Send DHCPREQUEST
; all regs preserved
request     phx
            phy
            pha

            lda   server_addr
            sta   rserverip
            sta   rsiaddr
            lda   server_addr+1
            sta   rserverip+1
            sta   rsiaddr+1
            lda   server_addr+2
            sta   rserverip+2
            sta   rsiaddr+2
            lda   server_addr+3
            sta   rserverip+3
            sta   rsiaddr+3

            lda   my_ip
            sta   rreqip
            lda   my_ip+1
            sta   rreqip+1
            lda   my_ip+2
            sta   rreqip+2
            lda   my_ip+3
            sta   rreqip+3

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
            bne   havebyte4
            lda   tx_free
            bne   havebyte4
            bra   ]txwt               ; wait if no tx buffer byte free
                                      ; (i srsly doubt this ever happens)

havebyte4   lda   tx_wr+1
            ldx   tx_wr               ; note little-endian load
            jsr   setaddr             ; start at this base address

            ldx   #00
]slp        lda   dhcprequest,x
            jsr   setdata             ; send the byte
            inx
            cpx   #$FF
            bne   ]slp

            ldx   #00
]slp2       lda   dhcprequest+255,x  ; second loop because request is (slightly) more than 255
            jsr   setdata
            inx
            cpx   #request_length
            bne   ]slp2

            lda   tx_ptr
            clc
            adc   #request_length
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

wt2         nop
            lda   #$04
            ldx   #$01
            jsr   setaddr
            jsr   getdata
            bne   wt2                 ; wait for send completion

            pla
            ply
            plx
            clc
            rts

; getack
; receive DHCPACK
getack      phx
            phy
            pha
            ldx   #$28
            jsr   setaddrlo           ; S0_RX_RD (un-translated rx base)
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

]dnswt      lda   #$04
            ldx   #$26
            jsr   setaddr             ; rx size = $0426
            jsr   getdata
            sta   rx_rcvd+1
            jsr   getdata
            sta   rx_rcvd             ; rx_rcvd now has bytes rcvd
            bne   have_byteE
            lda   rx_rcvd+1
            bne   have_byteE

            bra   ]dnswt

have_byteE  lda   rx_rd+1             ; at least 1 byte available
            ldx   rx_rd
            jsr   setaddr             ; start at this base address
            ldx   #00
]rdresp     jsr   getdata             ; read the byte from the buffer
            sta   dhcpack,x
            inx
            cpx   #255
            bne   ]rdresp

            ldx   #00
]rdresp     jsr   getdata             ; read the byte from the buffer
            sta   dhcpack+255,x
            inx
            cpx   rx_rcvd
            bne   ]rdresp

            lda   rx_rd_orig
            clc
            adc   rx_rcvd
            sta   rx_rd_orig          ; this is what we'll write back to rx_rd
            lda   rx_rd_orig+1
            adc   rx_rcvd+1
            sta   rx_rd_orig+1        ; converted 65816 addition

            ldy   #1
            lda   #$04
            ldx   #$28                ; add rx_rcvd to rx_rd_orig and store back in $0428
            jsr   setaddr
            lda   rx_rd_orig+1
            jsr   setdata
            lda   rx_rd_orig
            jsr   setdata

            ldx   #$01
            jsr   setaddrlo           ; S0 command register
            lda   #$40
            jsr   setdata             ; RECV command

            pla                       ; restore the byte
            ply                       ; restore saved regs
            plx
            sec
            rts

verifyack   lda   magiccookie2
            cmp   #$63
            bne   ackfail
            lda   magiccookie2+1
            cmp   #$82
            bne   ackfail
            lda   magiccookie2+2
            cmp   #$53
            bne   ackfail
            lda   magiccookie2+3
            cmp   #$63
            bne   ackfail

            clc
            rts

ackfail     sec
            rts

dhcpack     ds    400                 ; dhcpack will be about 342 bytes
ackdata     =     dhcpack+8           ; skip src ip, src port, length
magiccookie2 =    ackdata+236
ackopts     =     magiccookie2+4
