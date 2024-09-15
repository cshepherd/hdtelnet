*-------------------------------
* HDTelnet DNS module
* 9/14/2024 ballmerpeak
*-------------------------------

*-------------------------------
* DNS server
dns_ip      db    8,8,8,8

*-------------------------------
* internal variables
hex_in      db    0
bcd_out     db    00,00

*-------------------------------
* DNS request
dns         =     *
dns_id      ddb   6502        ; 16-bit random number for request id
dns_flags   db    $01,$00     ; QR=0,OPCODE=0,TC=0,RD=1,RA=0,Z=0,RCODE=0
dns_qdcount db    $00,$01     ; 1 query follows (big endian 16-bit)
dns_ancount db    $00,$00     ; 0 answers follow
dns_nscount db    $00,$00     ; 0 records follow
dns_arcount db    $00,$00     ; 0 additional records
dns_name    ds    64          ; the name will be here eventually
dns_hdr     =     dns_name-dns

dnsresp     ds    4             ; src ip addr
            ds    2             ; src port
            ds    2             ; data length
reply       ds    256
num_replies =     reply+7

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

            lda   #$05
            ldx   #$04
            jsr   setaddr             ; 0504 = S1 source port
            lda   port_num
            jsr   setdata
            lda   port_num+1
            jsr   setdata

            lda   #$05
            ldx   #$00
            jsr   setaddr             ; $0500 = S1 mode port
            lda   #$02
            jsr   setdata             ; $02 = UDP

            lda   #$05
            ldx   #$01
            jsr   setaddr             ; $0501 = S1 command port
            lda   #$01
            jsr   setdata             ; send OPEN command

            lda   #$05
            ldx   #$0C
            jsr   setaddr             ; $050C = S1 dest ip
            ldx   #0
]dest       lda   dns_ip,x
            jsr   setdata
            inx
            cpx   #4
            bne   ]dest               ; dest ip and port now set

            lda   #00
            jsr   setdata
            lda   #53
            jsr   setdata             ; dest port 53

            ply
            plx
            pla
            rts

; getres
; receive DNS result
getres      phx
            phy
            pha
            ldx   #$28
            jsr   setaddrlo           ; S1_RX_RD (un-translated rx base)
            jsr   getdata
            sta   rx_rd+1             ; +1 to reverse endianness
            sta   rx_rd_orig+1
            jsr   getdata
            sta   rx_rd
            sta   rx_rd_orig

            lda   rx_rd               ; AND #$07ff
            and   #$FF                ; ADD #$6800
            sta   rx_rd               ; former 65816 zone
            lda   rx_rd+1             ; (hence little endian)
            and   #$07
            clc
            adc   #$68
            sta   rx_rd+1

]dnswt      lda   #$05
            ldx   #$26
            jsr   setaddr             ; rx size = $0526
            jsr   getdata
            sta   rx_rcvd+1
            jsr   getdata
            sta   rx_rcvd             ; rx_rcvd now has bytes rcvd
            bne   have_byteU
            lda   rx_rcvd+1
            bne   have_byteU

            bra   ]dnswt

have_byteU  lda   rx_rd+1             ; at least 1 byte available
            ldx   rx_rd
            jsr   setaddr             ; start at this base address
            ldx   #00
]rdresp     jsr   getdata             ; read the byte from the buffer
            sta   dnsresp,x
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
            lda   #$05
            ldx   #$28                ; add rx_rcvd to rx_rd_orig and store back in $0528
            jsr   setaddr
            lda   rx_rd_orig+1
            jsr   setdata
            lda   rx_rd_orig
            jsr   setdata

            ldx   #$01
            jsr   setaddrlo           ; S1 command register
            lda   #$40
            jsr   setdata             ; RECV command

            pla                       ; restore the byte
            ply                       ; restore saved regs
            plx
            sec
            rts

; Send DNS query
; all regs preserved
sendquery   phx
            phy
            pha
            lda   #$05
            ldx   #$24
            jsr   setaddr             ; S1_TX_WR
            jsr   getdata
            sta   tx_wr+1             ; +1 to reverse endianness
            sta   tx_ptr+1
            jsr   getdata
            sta   tx_wr               ; tx_wr is the translated 5100 address we write to
            sta   tx_ptr              ; tx_ptr will be the exact original value
                                      ; + 4KB, 8KB etc without translation

            lda   tx_wr               ; AND #$07ff
            and   #$FF                ; ADD #$4800
            sta   tx_wr               ; former 65816 zone
            lda   tx_wr+1             ; (hence little endian)
            and   #$07
            clc
            adc   #$48
            sta   tx_wr+1

]txwt       lda   #$05
            ldx   #$20
            jsr   setaddr             ; tx free space = $0520
            jsr   getdata
            sta   tx_free+1
            jsr   getdata
            sta   tx_free             ; store little-endian

            lda   tx_free+1
            bne   havebyte3U
            lda   tx_free
            bne   havebyte3U
            bra   ]txwt               ; wait if no tx buffer byte free
                                      ; (i srsly doubt this ever happens)

havebyte3U  lda   tx_wr+1
            ldx   tx_wr               ; note little-endian load
            jsr   setaddr             ; start at this base address

            ldx   #00
]slp        lda   dns,x
            jsr   setdata             ; send the byte
            inx
            cpx   dns_length
            bne   ]slp

            lda   tx_ptr
            clc
            adc   dns_length
            sta   tx_ptr
            lda   tx_ptr+1
            adc   #00
            sta   tx_ptr+1

            lda   #$05
            ldx   #$24
            jsr   setaddr
            lda   tx_ptr+1
            jsr   setdata
            lda   tx_ptr
            jsr   setdata             ; inc S1_TX_WR to add the bytes

            lda   #$05
            ldx   #$01
            jsr   setaddr             ; S1 command register
            lda   #$20
            jsr   setdata             ; SEND command

wtU         nop
            lda   #$05
            ldx   #$01
            jsr   setaddr
            jsr   getdata
            bne   wtU                ; wait for send completion

            pla
            ply
            plx
            clc
            rts

; hexdec: convert 8 bits of hex to 2 bytes of BCD
; A = number to convert
; other regs preserved
hexdec      phx
            phy
            cld
            sta   hex_in
            tay
            stz   bcd_out
            stz   bcd_out+1
            ldx   #8
hd1         asl   hex_in
            rol   bcd_out
            rol   bcd_out+1
            dex
            beq   hd3
            lda   bcd_out
            and   #$0F
            cmp   #5
            bmi   hd2
            clc
            lda   bcd_out
            adc   #3
            sta   bcd_out
hd2         lda   bcd_out
            cmp   #$50
            bmi   hd1
            clc
            adc   #$30
            sta   bcd_out
            bra   hd1
hd3         sty   hex_in
            ply
            plx
            rts

; print "Looking up: " followed by domain name
printstart  ldx   #00
ps1         lda   lookingup,x
            beq   ps2
            ora   #$80
            jsr   $FDED
            inx
            bra   ps1
ps2         lda   #$8d
            jsr   $FDED
            rts

; Copy fqdn into properly formatted area in dns query
copyname    lda   #<keyin
            sta   $00
            lda   #>keyin
            sta   $01
            lda   #<dns_name
            sta   $02
            lda   #>dns_name
            sta   $03
cn4         ldy   #00
cn3         lda   ($00),y
            beq   cn1
            cmp   #'.'
            beq   cn2
            iny
            sta   ($02),y
            bra   cn3
cn2         tya               ; end of one segment
            sta   ($02)
            lda   $00
            inc
            clc
            adc   ($02)       ; add length of segment +1 (period) to input
            sta   $00
            lda   $01
            adc   #00         ; just to get carry
            sta   $01
            lda   $02
            inc
            clc
            adc   ($02)       ; add length of segment +1 (length) to output
            sta   $02
            lda   $03
            adc   #00         ; just to get carry
            sta   $03
            bra   cn4
cn1         tya               ; end of the whole thing
            sta   ($02)
            iny
            lda   #00
            sta   ($02),y     ; zero terminator
            iny
            sta   ($02),y     ; 00
            inc
            iny
            sta   ($02),y     ; 01 (dns_qtype = IN)
            dec
            iny
            sta   ($02),y     ; 00
            inc
            iny
            sta   ($02),y     ; 01 (dns_class = A)

            tya
            clc
            adc   $02
            sta   $02
            lda   $03
            adc   #00
            sta   $03         ; $02 is now end of datagram

            lda   $02
            sec
            sbc   $00
            sta   dns_length

            rts

; Get IP address returned by server and place it in dest_ip
parseres    ldx   #$0C        ; start reading reply at 'name'
pr2         lda   reply,x
            beq   pr1         ; skip to the 00 at the end of the name
            inx
            bra   pr2
pr1         inx
            inx               ; q type
            inx
            inx               ; q class
pr3         inx               ; first byte of answer name
            lda   reply,x
            bne   pr3
ans         inx               ; A type
            lda   reply,x
            tay               ; 1 = A, 5 = CNAME
            inx
            inx               ; A class
            inx
            inx
            inx
            inx               ; last byte of TTL
            inx
            inx               ; length of rdata
            cpy  #1
            bne  skip
            inx
            lda  reply,x
            sta  dest_ip
            inx
            lda  reply,x
            sta  dest_ip+1
            inx
            lda  reply,x
            sta  dest_ip+2
            inx
            lda  reply,x
            sta  dest_ip+3
            rts
skip        lda  reply,x      ; skip over CNAME
skip2       inx
            dec
            bne  skip2
            inx
            bra  pr3          ; parse the next answer

; Print output of DNS query
printres    ldx   #00
prr1        lda   connto,x
            beq   prr2
            ora   #$80
            jsr   $FDED
            inx
            bra   prr1
prr2        lda   dest_ip
            jsr   hexdec
            lda   bcd_out+1
            jsr   $fdda
            lda   bcd_out
            jsr   $fdda
            lda   #"."
            jsr   $fded
            lda   dest_ip+1
            jsr   hexdec
            lda   bcd_out+1
            jsr   $fdda
            lda   bcd_out
            jsr   $fdda
            lda   #"."
            jsr   $fded
            lda   dest_ip+2
            jsr   hexdec
            lda   bcd_out+1
            jsr   $fdda
            lda   bcd_out
            jsr   $fdda
            lda   #"."
            jsr   $fded
            lda   dest_ip+3
            jsr   hexdec
            lda   bcd_out+1
            jsr   $fdda
            lda   bcd_out
            jsr   $fdda

            lda   #$8d
            jsr   $fded
            rts

getname     ldx   #00
gn0         lda   enterhost,x
            beq   gn1
            ora   #$80
            jsr   $FDED
            inx
            bra   gn0
gn1         ldx   #00
            lda   $c010
gn2         bit   $c000
            bpl   gn2
            lda   $c010
            and   #$7F
            cmp   #$0D
            beq   gn3
            cmp   #$03
            beq   gn4
            sta   keyin,x
            ora   #$80
            cmp   #$FF
            bne   notbs
            cpx   #00
            beq   notbs
            lda   #$88
            jsr   $FDED
            lda   #$A0
            jsr   $FDED
            lda   #$88
            jsr   $FDED
            dex
            bra   gn2
notbs       jsr   $FDED
            inx
            cpx   #64
            bne   gn2
gn3         lda   #00
            sta   keyin,x
            lda   #$8d
            jsr   $FDED
            clc
            rts
gn4         sec
            rts

getport     ldx   #00
gp0         lda   portnum,x
            beq   gp1
            ora   #$80
            jsr   $FDED
            inx
            bra   gp0
gp1         ldx   #00
            lda   $c010
gp2         bit   $c000
            bpl   gp2
            lda   $c010
            cmp   #$FF
            bne   nbs
            cpx   #00
            beq   nbs
            lda   #$88
            jsr   $FDED
            lda   #$A0
            jsr   $FDED
            lda   #$88
            jsr   $FDED
            dex
            bra   gp2
nbs         cmp   #$8D
            beq   gp3
            cmp   #$B0
            blt   gp2
            cmp   #$Ba
            bge   gp2
            and   #$7F
            sta   testasc,x
            ora   #$80
            jsr   $FDED
            inx
            cpx   #5
            bne   gp2
gp3         lda   #00
            sta   testasc,x
            lda   #$8d
            jsr   $FDED
            rts

; print dns failure
printfail   ldx   #00
pf1         lda   dnsfail,x
            beq   pf2
            ora   #$80
            jsr   $FDED
            inx
            bra   pf1
pf2         ldx   #00
pf4         lda   keyin,x
            beq   pf3
            ora   #$80
            jsr   $FDED
            inx
            bra   pf4
pf3         lda   #$8d
            jsr   $fded
            rts

; strings 'n' such
dnsfail     asc   'DNS failure for name: ',00
portnum     asc   'Port Number [23]: ',00
connto      asc   'Connecting to ',00
connto2     asc   ' on port ',00
enterhost   asc   'Hostname to Connect to or CTRL-C to exit: ',00
lookingup   asc   'Looking up: '

; zero-terminated like it would be if input from keyboard
keyin       ds    64
dns_length  db    0
portin      ds    10
