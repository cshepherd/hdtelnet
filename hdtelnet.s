*-------------------------------
* HD Telnet
* VidHD wide-carriage vt100 telnet client
* 8/18/2024 ballmerpeak
*-------------------------------

            org   $2000

; Do once
            jsr   vidinit   ; Initialize VidHD output mode
            jsr   slotdet   ; Detect slot

; DHCP flow to populate IP params
            jsr   wizinit     ; Initialize the Wiznet
            jsr   dhcpsetup   ; Set up UDP socket
            jsr   discover    ; Send DHCPDISCOVER
            jsr   getoffer    ; Await / get DHCPOFFER
            jsr   parseoffer  ; Parse DHCPOFFER
            jsr   request     ; Send DHCPREQUEST
            jsr   getack      ; Await / get DHCPACK
            jsr   verifyack   ; Verify DHCPACK
            jsr   prtdhcp

; Now proceed as normal
            jsr   wizinit   ; Initialize the Wiznet for reals

            jsr   udpsetup  ; Set DNS server as S1 UDP destination
newconn     jsr   getname
            bcs   ejmp
            jsr   printstart
            jsr   copyname
            jsr   sendquery ; Send the UDP DNS query
            jsr   getres    ; Await / get DNS answer

            lda   num_replies
            bne   dcont
            jsr   printfail ; Print DNS failure
ejmp        jmp   exit
dcont       jsr   parseres  ; Parse DNS result
            jsr   printres  ; Print DNS answer

            jsr   openconn  ; Open outbound S0 TCP connection

; Do forever
; part I: display chars from net
mainloop    jsr   netin     ; Get a byte frm network
            bcc   localin   ; carry clear = no byte
            cmp   #$FF      ; telnet protocol IAC
            bne   maindisp2
            jsr   rcvd_iac
maindisp2   cmp   #$1B      ; is esc?
            bne   maindisp
            jsr   rcvd_esc
            bra   localin
maindisp    jsr   dispchar  ; Display received character

; part III: send chars from kbd to net
localin     jsr   kbd       ; Check keyboard
            bcc   mainloop  ; carry clear = no key
            jsr   out       ; Send new character
            bra   mainloop

closedconn  ldx   #$00
closedcon3  lda   connClosed,x 
            beq   closedcon2
            ora   #$80
            jsr   $fded
            inx
            bra   closedcon3
closedcon2  bra   newconn

cardslot    dfb   1 ; card slot

*-------------------------------
* Uthernet II configuration
my_gw       db    0,0,0,0
my_mask     db    0,0,0,0
mac_addr    db    $08,00,$20,$C0,$10,$20
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

; vt100 character positioning and screen clearing
rcvd_esc    jsr   netin
            cmp   #'['
            bne   esc_done
            jsr   netin
            cmp   #'H'
            beq   movetop
            cmp   #'J'
            beq   clears
esc_done    rts
;movetop     stz   $24
;            stz   $25
;            rts
movetop
clears      jsr   $FC58
            rts

; received telnet IAC
; parse the rest
rcvd_iac    jsr   netin       ; get next byte
            bcc   do_abort    ; no byte? just bail
            cmp   #$FD        ; DO
            beq   iac_do
            cmp   #$FB        ; WILL
            beq   iac_will
            cmp   #$FE        ; DON'T
            beq   iac_dont
            cmp   #$FC        ; WON'T
            beq   iac_wont
do_abort    rts               ; bail (shouldn't happen)
iac_do      jsr   netin
            bcc   do_abort
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
            lda   #$FC        ; WON'T
            jsr   out
            pla               ; saved option number
            jsr   out
            rts
send_dont   pha
            lda   #$FF        ; IAC
            jsr   out
            lda   #$FE        ; DON'T
            jsr   out
            pla               ; saved option number
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

initfail    ldx  #$00
initfail3   lda  initUnable,x
            beq  initfail4
            ora  #$80
            jsr  $fded
            inx
            bra  initfail3
initfail4   jmp  exit

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
sockfail    ldx   #$00
sockfail3   lda   sockUnable,x
            beq   sockfail2
            ora   #$80
            jsr   $fded
            inx
            bra   sockfail3
sockfail2   jmp   exit

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

; exit / stop everything
; print a message, accept a keypress, quit to P8
exit        jsr   discon              ; put uther ii in a nice state
            lda   #$8d
            jsr   $fded
            jsr   $fded
exit4       lda   presstoquit,x
            beq   exit2
            ora   #$80
            jsr   $fded
            inx
            bra   exit4
exit2       sta   $c010
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
; TODO
dispchar
            ora   #$80     ; set hi bit
            jsr   $fded
dispgo      rts


; vidinit
; Initialize video / VidHD / etc to desired mode
; TODO
vidinit
            jsr   $c300
            jsr   $FC58
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
            ldx   #$00
slotdet3    lda   slotFound,x
            beq   slotdet2
            ora   #$80
            jsr   $fded
            inx
            bra   slotdet3
slotdet2    lda   cardslot
            clc
            adc   #$b0
            jsr   $fded
            lda   #$8D
            jsr   $fded
            rts

notfound    ldx   #$00
notfound3   lda   slotUnable,x
            beq   notfound2
            ora   #$80
            jsr   $fded
            inx
            bra   notfound3
notfound2   jmp   exit

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

prtdhcp     ldx   #$00
prtdhcp3    lda   dhcpComplete,x
            beq   prtdhcp5
            ora   #$80
            jsr   $fded
            inx
            bra   prtdhcp3

            ldx   #$00
prtdhcp5    lda   myIPstr,x
            beq   prtdhcp4
            ora   #$80
            jsr   $fded
            inx
            bra   prtdhcp5

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

            ldx   #$00
prtdhcp6    lda   myMaskstr,x
            beq   prtdhcp7
            ora   #$80
            jsr   $fded
            inx
            bra   prtdhcp6

prtdhcp7    lda   my_mask
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

            ldx   #$00
prtdhcp8    lda   myGWstr,x
            beq   prtdhcp9
            ora   #$80
            jsr   $fded
            inx
            bra   prtdhcp8

prtdhcp9    lda   my_gw
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


            ldx   #$00
prtdhcp10   lda   myDNSstr,x
            beq   prtdhcp11
            ora   #$80
            jsr   $fded
            inx
            bra   prtdhcp10

prtdhcp11   lda   dns_ip
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

presstoquit str   'Press any key to return to ProDOS 8',00
initUnable  str   'Unable to initialize W5100 chip',00
sockUnable  str   'Unable to setup TCP socket',00
slotUnable  str   'Unable to find Uthernet II in any slot',00
slotFound   str   'Found Uthernet II in slot ',00
dhcpComplete str  'DHCP configuration complete.',$8d,00
myIPstr     str   'My IP Address: ',00
myDNSstr    str   'My DNS Server: ',00
myGWstr     str   'My Default Gateway: ',00
myMaskstr   str   'My Network Mask: ',00
connClosed  str   $8d,$8d,'Connection reset by remote host.',$8d,00

            use   dhcp.s
