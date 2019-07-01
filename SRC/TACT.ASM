;------ character sink subroutines
;	(C) Copyright 1982  Hanno Hinsch

	public	capfile1
	public	sendc
	public	waiter
	public	wait_init
	public	filter			;used by 'window' sink
	public	ansback
	public	ringchk
	public	tsend_init

cm_data segment public 'code'

allocate = 0
include data.pub

tactf	db	0			;local flags
	cr1	equ	2		;last char was cr

cm_data ends

cm_code segment  public 'code'

assume	cs: cm_code
assume	ds: cm_data

extrn	encode:near,cm_send:near
extrn	isxonw:near,tadd:near
extrn	pr_abort:near,pr_dskerr:near
extrn	fwrite:near,wrtclose:near
extrn	pmsg:near,setupd:near
extrn	startpfk:near,cm_ring:near
extrn	isctsw:near, rtson:near, rtsoff:near

;------ tsend_init: set flag, so that if we get a CR as first char, and
;	blank expansion is turned on, we expand line correctly.
;	called by parse on SEND command
tsend_init proc near
	or	tactf,cr1
	ret
tsend_init endp


;------ sendc: send character to com1
;	this is default sender, called when not using protocol transfer
sendc	proc	near
	test	ah,fromc1+fromt1+kill+fromctl
	jz	sendc4
	jmp	sendcx		;don't send

sendc4: test	ah,frompfk
	jz	sendc3
	call	encode		;encode special chars into escape sequences
	jmp	sendcx

sendc3: cmp	ah,fromf1	;from file?
	jne	sendc2		;no --
	test	tflag,xmita	;fake file (pf string)?
	jnz	sendc2		;yes -god this is ugly
	test	parmf,nofilt	;filter off?
	jnz	sendc2		;yes -- skip this nonsense

	cmp	al,32		;control chars?
	jb	sendc0
	and	tactf,255-cr1	;last char was not cr
	jmp	sendc2

;	expand null lines into one-blank lines
sendc0: test	parm2,expand	;expand blank lines?
	jz	sendc1
	cmp	al,13
	jne	sendc1
	test	tactf,cr1	;was there a printing chr since last cr?
	jnz	sendc00 	;no -- go send blank, then cr
	or	tactf,cr1	;set "cr seen" flag
	jmp	sendc2		;and go send it

sendc00: mov	al,' '          ;send blank
	call	cm_send
	mov	al,13
	jmp	sendc2		;and go send cr, too

;	don't send lfs from file if filter is off
sendc1: cmp	al,10		;lf?
	jne	sendc2		;no --
	mov	ah,kill 	;don't display or send to file, either
	jmp	sendcx

sendc2: call	cm_send        ;send char

sendcx:
	ret
sendc	endp



;------ waiter: check for line turnaround
waiter	proc	near
	push	bx

	cmp	ah,fromc1
	je	waitc1
	cmp	ah,fromk
	je	waitk
	cmp	ah,fromf1
	je	waitf1
	jmp	waitx

waitk:	call	isxonw		;waiting for xon?
	mov	bx,62		;xon msg
	jnz	waitk2		;yes

	call	isctsw		;waiting for cts?
	mov	bx,149		;cts msg
	jnz	waitk2

;	test for cr during cts/rts transfer; squelch rts if needed
	cmp	al,13		;cr?
	jne	waitk1		;nope
	test	parm4,protrts	;cts/rts?
	jz	waitk1		;nope
	call	rtsoff		;don't want to send no more

waitk1: jmp	waitx

;don't send chrs from keybd if waiting for xon or cts.
;other sources stopped elsewhere
waitk2:
	call	rtson		;ask for cts
	mov	ah,kill 	;don't try to send it
	or	parm2,msgupd	;note msg should be updated during loop
	mov	msgnum,bx	;store msg
	jmp	waitx

waitf1: cmp	al,13		;carriage return?
	jne	waitx		;no -- ignore char
	test	parm3,ptrans	;protocol transfer
	jnz	waitx		;don't initiate wait here
	call	wait_init	;start waiting for tchar,twait
	jmp	waitx

waitc1: test	tflag,lwait+tdelay	;are we waiting for anything?
	jz	waitx			;no

;	reset wait time -- we want to wait for a quiet line
	push	ax
	mov	al,twtime	;turnaround delay time
	or	al,al
	jz	waitc2		;not needed
	push	cx
	push	dx
	call	tadd		;calculate ending time
	mov	twc,cx		;save hi order
	mov	twd,dx		;save lo order
	pop	dx
	pop	cx
	or	tflag,tdelay	;let em know we're waiting
waitc2: pop	ax

	push	ax			;keep complete char around
	and	al,01111111b		;strip off high bit
	cmp	al,turnchr		;turnaround char?
	pop	ax
	jne	waitx			;no --
	and	tflag,255-lwait 	;clear wait state
	mov	msgnum,-1		;clear msg area

waitx:	pop	bx
	ret
waiter	endp


;------ wait_init: start waiting for tchar, twait
wait_init proc	near
	push	ax
	mov	al,twtime	;turnaround delay time
	or	al,al
	jz	wia
	push	cx
	push	dx
	call	tadd		;calculate ending time
	mov	twc,cx		;save hi order
	mov	twd,dx		;save lo order
	pop	dx
	pop	cx
	or	tflag,tdelay	;let em know we're waiting
wia:

	test	parmf,ltcon	;wait for turnaround char?
	jz	wiab
	or	tflag,lwait	;initiate line turnaround wait
	mov	msgnum,64	;tell the world

wiab:	pop	ax
	ret
wait_init endp


;------ capfile1: write char to capture file, if active
capfile1	proc	near
	push	ax

	test	tflag,fcap		;active cap file?
	jz	capx			;nope
	test	parmf,capoff		;cap file toggled off?
	jnz	capx			;yes -- ignore char

	call	filter		;convert unwanted chars to 'kill' attribute

	test	ah,kill+frompfk+fromctl ;for us?
	jnz	capx			;no

	cmp	ah,fromc1	;is it from host?
	je	capf1		;go capture

	cmp	ah,fromt1		;definitely capture
	je	capf3

;	assertion: keybd char or equivalent
	test	parmf,hecho	;is host echo on?
	jnz	capx		;yes -- we shouldn't capture it

	test	parm2,routek		;capture local chr's?
	jz	capx
	jmp	capf3

capf1:	test	parm2,routeh		;capture host chr's?
	jz	capx

capf3:
	push	ax
	call	fwrite			;write chr in al
	call	pmsg			;print possible error msg
	or	ah,ah			;rc = 0?
	jz	capf4			;yes -- all ok
	call	wrtclose		;close file on error
	and	tflag,255-fcap		;cool down this sink
	call	setupd
	test	parm3,ptrans		;protocol transfer in progress?
	jz	capf3a			;no
	call	pr_abort		;close everything
	call	pr_dskerr		;special disk error handling
capf3a: pop	ax
	jmp	capx

capf4:	pop	ax
	cmp	al,13		;was that cr?
	jne	capx		;nope
	mov	al,10		;get a lf
	test	parmf,autolf	;do we add linefeeds?
	jnz	capf3		;we do
	test	parm2,routeh	; and we need lf if we're capturing
	jnz	capx		; >only< local data
	test	parm2,routek
	jnz	capf3		;yes -- add a lf

capx:	pop	ax
	ret
capfile1	endp


;------ filter: kill weird control chars from com port or keyboard
filter	proc	near
	test	ah,fromc1+fromk
	jz	filtx

	cmp	al,32
	jb	filt0
	cmp	al,127
	jae	filt0
	jmp	filtx

filt0:	test	parmf,nofilt		;hands off?
	jnz	filtx			;yes indeed

	and	al,01111111b		;strip parity bit
	cmp	al,127			;del?
	je	filt1			;yes

	cmp	al,32			;less than blank?
	jae	filtx			;no -- leave it

	cmp	al,7			;bel?
	je	filtx
	cmp	al,8			;bs?
	je	filtx
	cmp	al,9			;tab?
	je	filtx
	cmp	al,13			;cr?
	je	filtx
	cmp	al,10			;lf?
	je	filtx
	cmp	al,12			;ff?
	je	filtx


filt1:	mov	ah,kill 		;kill this char
filtx:	ret
filter	endp

;------ ansback: trigger answerback string, if we get ENQ
ansback proc	near

	test	ah,fromc1
	jz	ansx
	cmp	al,5			;ENQ?
	jne	ansx
	test	cmdflg,doact		;cmnd file active
	jnz	ansx
	test	tflag,xmita+f1src
	jnz	ansx
	test	parm3,ptrans		;transfer in progress?
	jnz	ansx

	push	ax
	mov	al,dpfa 		;answerback string
	call	startpfk
	pop	ax

ansx:
	ret
ansback endp

;------ ringchk: check ring indicator, trigger string if set
ringchk proc	near
	call	cm_ring
	jnc	ringx

	test	cmdflg,doact		;cmnd file active
	jnz	ringx
	test	tflag,xmita		;pf key being sent?
	jnz	ringx
	test	parm3,ptrans		;transfer in progress?
	jnz	ringx

	push	ax
	mov	al,dpfring
	call	startpfk
	pop	ax

ringx:
	ret
ringchk endp

cm_code ends
end
