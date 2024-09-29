*-------------------------------
* Telnet IAC module
* 9/29/2024 ballmerpeak
*-------------------------------

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
