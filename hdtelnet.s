*-------------------------------
* HD Telnet
* VidHD wide-carriage vt100 telnet client
* 8/18/2024 ballmerpeak
*-------------------------------

            org   $2000

; Do once
            jsr   vidinit   ; Initialize VidHD output mode
            jsr   slotdet   ; Detect slot

            jsr   getrand
            sta   mac_addr+5  ; Randomize last octet of MAC address
            sta   chaddr+5    ; Save for DHCP
            sta   rchaddr+5   ; Save for DHCP

; DHCP flow to populate IP params
            jsr   wizinit     ; Initialize the Wiznet
            jsr   dhcpsetup   ; Set up UDP socket
            ldx   #6
discloop    clc
            phx
            jsr   discover    ; Send DHCPDISCOVER
            ldx   #<sentdisc
            ldy   #>sentdisc
            jsr   prtstr

            jsr   getoffer    ; Await / get DHCPOFFER
            bcc   discnext
            plx
            dex
            bne   discloop
            ldx   #<dhcpto    ; Timed out waiting for DHCPOFFER
            ldy   #>dhcpto
            jsr   prtstr
            jmp   exit
discnext    plx
            ldx   #<gotoffer
            ldy   #>gotoffer
            jsr   prtstr

            jsr   parseoffer  ; Parse DHCPOFFER

            ldx   #6
ackloop     clc
            phx
            jsr   request     ; Send DHCPREQUEST
            ldx   #<sentreq
            ldy   #>sentreq
            jsr   prtstr

            jsr   getack      ; Await / get DHCPACK
            bcc   acknext
            plx
            dex
            bne   ackloop
            ldx   #<dhcpto    ; Timed out trying to get DHCPACK
            ldy   #>dhcpto
            jsr   prtstr
            ldx   #<danyway
            ldy   #>danyway
            jsr   prtstr
;            jmp   exit
            jmp   noack
acknext     plx
            jsr   verifyack   ; Verify DHCPACK
noack       jsr   prtdhcp

; Now proceed as normal
            jsr   wizinit   ; Initialize the Wiznet for reals

            jsr   udpsetup  ; Set DNS server as S1 UDP destination
newconn     jsr   getname
            bcs   ejmp2

            jsr   getport
            lda   testasc
            bne   nc2
            lda   #00
            sta   dest_port
            lda   #23
            sta   dest_port+1
            bra   ps00
nc2         jsr   copyasc
            jsr   asc2bcd
            jsr   BCD2BIN
            lda   BINW+1
            sta   dest_port
            lda   BINW
            sta   dest_port+1

ps00        jsr   printstart
            jsr   isquad
            bcs   ps01
            jsr   quad2hex
            lda   quadout
            sta   dest_ip
            lda   quadout+1
            sta   dest_ip+1
            lda   quadout+2
            sta   dest_ip+2
            lda   quadout+3
            sta   dest_ip+3
            bra   ps02
ps01        jsr   copyname
            jsr   sendquery ; Send the UDP DNS query
            jsr   getres    ; Await / get DNS answer
            bcc   ps03
            jsr   printfail
            bra   newconn
ps03        lda   num_replies
            bne   dcont
            jsr   printfail ; Print DNS failure
            bra   newconn
ejmp2       jmp   exit
dcont       jsr   parseres  ; Parse DNS result
ps02        jsr   printres  ; Print DNS answer

            jsr   openconn  ; Open outbound S0 TCP connection

            ldx   #<connEstab
            ldy   #>connEstab
            jsr   prtstr

; Do forever
; part I: display chars from net
mainloop    jsr   netin     ; Get a byte frm network
            bcc   localin   ; carry clear = no byte
            cmp   #$FF      ; telnet protocol IAC
            bne   maindisp2
            jsr   rcvd_iac
            bra   localin   ; don't print IAC stuff
maindisp2   cmp   #$1B      ; is esc?
            bne   maindisp
            jsr   rcvd_esc
            bra   localin
maindisp    jsr   dispchar  ; Display received character

; part III: send chars from kbd to net
localin     jsr   kbd       ; Check keyboard
            bcc   mainloop  ; carry clear = no key
            pha
            lda   $C061
            and   #$80
            cmp   #$00
            beq   noOA      ; check for open apple
            pla
            cmp   #'X'
            beq   closeconn
            cmp   #'x'
            beq   closeconn
            cmp   #'B'
            beq   brnk
            cmp   #'b'
            beq   brnk
            cmp   #'1'
            beq   chmode
            cmp   #'2'
            beq   chmode
            cmp   #'3'
            beq   chmode
            bra   mainloop
chmode      lda   vhd_slot
            cmp   #$ff
            beq   mainloop
            sec
            sbc   #$2f      ; '1' -> 2, '2' -> 3, '3' -> 4
            tax
            stz   $c010
            jsr   vidhd_mode ; set new mode
            bra   mainloop
noOA        pla
            jsr   out       ; Send new character
            bra   mainloop
newconn2    jmp   newconn
closeconn   jsr   discon
closedconn  jsr   $FC58
            ldx   #<connClosed
            ldy   #>connClosed
            jsr   prtstr
closedcon2  bra   newconn2
brnk        brk   00
ejmp        jmp   exit

cardslot    dfb   1 ; card slot

*-------------------------------
* Uthernet II configuration
my_gw       db    0,0,0,0
my_mask     db    0,0,0,0
mac_addr    db    $08,00,$20,$C0,$10,$22
my_ip       db    0,0,0,0
port_num    ddb   6502
*-------------------------------
* destination
dest_ip     db    0,0,0,0
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
stackptr    db    0
xy_first    db    0
            use   dns.s

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

; received telnet IAC
; parse the rest
rcvd_iac    jsr   netin       ; get next byte
            bcc   do_abort    ; no byte? just bail
            cmp   #253        ; DO
            beq   iac_do
            cmp   #251        ; WILL
            beq   iac_will
            cmp   #254        ; DON'T
            beq   iac_dont
            cmp   #252        ; WON'T
            beq   iac_wont
do_abort    rts               ; bail (shouldn't happen)
iac_do      jsr   netin
            bcc   do_abort
;            cmp   #24         ; terminal ID
;            beq   send_term   ; send ansi terminal ID
            jmp   send_wont   ; send IAC WON'T for this DO
iac_will    jsr   netin
            bcc   do_abort
            jmp   send_dont   ; send IAC DON'T for this WILL
iac_dont    jsr   netin       ; get DON'T and throw it away
            rts
iac_wont    jsr   netin       ; get WON'T and throw it away
            rts
send_wont   pha
            lda   #$FF        ; IAC
            jsr   out
            lda   #252        ; WON'T
            jsr   out
            pla               ; saved option number
            jsr   out
            rts
send_dont   pha
            lda   #$FF        ; IAC
            jsr   out
            lda   #254        ; DON'T
            jsr   out
            pla               ; saved option number
            jsr   out
            rts
send_term   lda   #$FF        ; IAC
            jsr   out
            lda   #250        ; SB
            jsr   out
            lda   #24         ; termtype
            jsr   out
            lda   #00         ; IS
            jsr   out
            lda   #'v'
            jsr   out
            lda   #'t'
            jsr   out
            lda   #'1'
            jsr   out
            lda   #'0'
            jsr   out
            lda   #'0'
            jsr   out
            lda   #$FF        ; IAC
            jsr   out
            lda   #240        ; SE
            jsr   out
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

initfail    ldx  #<initUnable
            ldy  #>initUnable
            jsr  prtstr
            jmp  exit

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

            lda   #$55                ; 55 = 4x 2KB socket buffers
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
sockfail    ldx   #<sockUnable
            ldy   #>sockUnable
            jsr   prtstr
            jmp   exit

; exit / stop everything
; print a message, accept a keypress, quit to P8
exit        jsr   discon              ; put uther ii in a nice state
            lda   #$8d
            jsr   $fded
            jsr   $fded
            ldx   #<presstoquit
            ldy   #>presstoquit
            jsr   prtstr
            sta   $c010
exit3       lda   $c000
            bpl   exit3
            jsr   $bf00
            db    $65
            dw    qparms

qparms      db    4
            db    0
            dw    0
            db    0
            dw    0

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
            ldx   #$03
            jsr   setaddr
            jsr   getdata
            bne   noclose
            ply
            plx
            pla
            pla                       ; restore regs but also unwind the jsr from main loop
            jmp   closedconn
noclose     ldx   #$28
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
            and   #$7F    ; strip hi bit
            sec
nokey       rts

; dispchar
; Write the character in A to the screen
; The first character after changing x/y should be done through FDED
; all others should be done with the Pascal write vector
dispchar    pha
            lda   xy_first ; first output after setting xy?
            bne   dcfded
            stz   xy_first
            pla
            ora   #$80      ; set hi bit
            jmp   cardwrite ; do pascal-vector write
dcfded      stz   xy_first
            pla
            ora   #$80
            jsr   $fded
            rts

; slotdet
; attempt a variant of wizinit for different slots
; try not to format any disks teehee
slotdet     ldx   #$FF
]next       inx
            lda   slots,x
            beq   notfound
            jsr   wizinit2
            bcs   ]next
            sta   cardslot
            ldx   #<slotFound
            ldy   #>slotFound
            jsr   prtstr
            lda   cardslot
            clc
            adc   #$b0
            jsr   $fded
            lda   #$8D
            jsr   $fded
            rts

notfound    ldx   #<slotUnable
            ldy   #>slotUnable
            jsr   prtstr
            jmp   exit

; Order to attempt detection
slots       db    01,07,02,04,03,05,06,00

; Just reset the Uthernet II
; all regs preserved
wizinit2    pha
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
            bne   initfail2

            lda   #$03
            jsr   setglobalreg
            jsr   getglobalreg
            cmp   #$03
            bne   initfail2

            clc
            ply
            plx
            pla
            rts

initfail2   sec
            ply
            plx
            pla
            rts

prtdhcp     ldx   #<dhcpComplete
            ldy   #>dhcpComplete
            jsr   prtstr

            ldx   #<myIPstr
            ldy   #>myIPstr
            jsr   prtstr

prtdhcp4    lda   my_ip
            jsr   hexdec
            lda   bcd_out+1
            jsr   $fdda
            lda   bcd_out
            jsr   $fdda
            lda   #"."
            jsr   $fded
            lda   my_ip+1
            jsr   hexdec
            lda   bcd_out+1
            jsr   $fdda
            lda   bcd_out
            jsr   $fdda
            lda   #"."
            jsr   $fded
            lda   my_ip+2
            jsr   hexdec
            lda   bcd_out+1
            jsr   $fdda
            lda   bcd_out
            jsr   $fdda
            lda   #"."
            jsr   $fded
            lda   my_ip+3
            jsr   hexdec
            lda   bcd_out+1
            jsr   $fdda
            lda   bcd_out
            jsr   $fdda
            lda   #$8d
            jsr   $fded

            ldx   #<myMaskstr
            ldy   #>myMaskstr
            jsr   prtstr

            lda   my_mask
            jsr   hexdec
            lda   bcd_out+1
            jsr   $fdda
            lda   bcd_out
            jsr   $fdda
            lda   #"."
            jsr   $fded
            lda   my_mask+1
            jsr   hexdec
            lda   bcd_out+1
            jsr   $fdda
            lda   bcd_out
            jsr   $fdda
            lda   #"."
            jsr   $fded
            lda   my_mask+2
            jsr   hexdec
            lda   bcd_out+1
            jsr   $fdda
            lda   bcd_out
            jsr   $fdda
            lda   #"."
            jsr   $fded
            lda   my_mask+3
            jsr   hexdec
            lda   bcd_out+1
            jsr   $fdda
            lda   bcd_out
            jsr   $fdda
            lda   #$8d
            jsr   $fded

            ldx   #<myGWstr
            ldy   #>myGWstr
            jsr   prtstr

            lda   my_gw
            jsr   hexdec
            lda   bcd_out+1
            jsr   $fdda
            lda   bcd_out
            jsr   $fdda
            lda   #"."
            jsr   $fded
            lda   my_gw+1
            jsr   hexdec
            lda   bcd_out+1
            jsr   $fdda
            lda   bcd_out
            jsr   $fdda
            lda   #"."
            jsr   $fded
            lda   my_gw+2
            jsr   hexdec
            lda   bcd_out+1
            jsr   $fdda
            lda   bcd_out
            jsr   $fdda
            lda   #"."
            jsr   $fded
            lda   my_gw+3
            jsr   hexdec
            lda   bcd_out+1
            jsr   $fdda
            lda   bcd_out
            jsr   $fdda
            lda   #$8d
            jsr   $fded


            ldx   #<myDNSstr
            ldy   #>myDNSstr
            jsr   prtstr

            lda   dns_ip
            jsr   hexdec
            lda   bcd_out+1
            jsr   $fdda
            lda   bcd_out
            jsr   $fdda
            lda   #"."
            jsr   $fded
            lda   dns_ip+1
            jsr   hexdec
            lda   bcd_out+1
            jsr   $fdda
            lda   bcd_out
            jsr   $fdda
            lda   #"."
            jsr   $fded
            lda   dns_ip+2
            jsr   hexdec
            lda   bcd_out+1
            jsr   $fdda
            lda   bcd_out
            jsr   $fdda
            lda   #"."
            jsr   $fded
            lda   dns_ip+3
            jsr   hexdec
            lda   bcd_out+1
            jsr   $fdda
            lda   bcd_out
            jsr   $fdda
            lda   #$8d
            jsr   $fded

            rts

; This was good enough for woz
; use RNDH/RNDL as seed for LFSR
; result in A
getrand     lda   $4F
            bne   gr2
            cmp   $4E
            adc   #00
gr2         and   #$7F
            sta   $4F
            ldy   #$11
gr3         lda   $4F
            asl
            clc
            adc   #$40
            asl
            rol   $4E
            rol   $4F
            dey
            bne   gr3
            rts

presstoquit asc   'Press any key to return to ProDOS 8',00
initUnable  asc   'Unable to initialize W5100 chip',00
sockUnable  asc   'Unable to setup TCP socket',00
slotUnable  asc   'Unable to find Uthernet II in any slot',00
slotFound   asc   'Found Uthernet II in slot ',00
dhcpComplete asc  'DHCP configuration complete.',$8d,00
myIPstr     asc   'My IP Address: ',00
myDNSstr    asc   'My DNS Server: ',00
myGWstr     asc   'My Default Gateway: ',00
myMaskstr   asc   'My Network Mask: ',00
connClosed  asc   $8d,$8d,'Connection reset by remote host.',$8d,00
connEstab   asc   'Connection established. Apple-X to close.',$8d,00

            use   vt100.s
            use   vidhd.s
            use   adb.s
            use   bcdutil.s
            use   dhcp.s
