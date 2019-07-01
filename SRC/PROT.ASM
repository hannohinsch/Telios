;------ ptrans protocol transfer
;	(C) Copyright 1983  Hanno Hinsch

	public	pr_rd
	public	pr_send
	public	pr_eof
	public	pr_abort
	public	pr_start
	public	pr_loop
	public	pr_finish
	public	pr_chat
	public	pr_dskerr


cm_data segment public 'code'

allocate = 0
include data.pub

saved_parmf	db	0
saved_parm2	db	0
saved_twtime	db	0

cm_data ends

cm_code segment  public 'code'

assume	cs: cm_code
assume	ds: cm_data

extrn	xm_rd:near,xm_send:near,xm_eof:near,xm_abort:near,xm_start:near
extrn	xm_loop:near

extrn	ke_rd:near,ke_send:near,ke_eof:near,ke_abort:near,ke_start:near
extrn	ke_loop:near

extrn	wrtclose:near,cm_8set:near,cm_8restore:near,cm_flush:near,setupd:near
extrn	clrxonw:near,rdfclose:near

extrn	window:near

;------ pr_loop: this routine gets control once for every main loop (in TLOOP)
pr_loop proc	near
	test	parm3,ptrans
	jz	loerr
	test	parm3,xmodem
	jz	lo1
	call	xm_loop
	jmp	lox

lo1:	test	parm3,kermit
	jz	loerr
	call	ke_loop
	jmp	lox

loerr:	mov	msgnum,18		 ;internal error
lox:	ret
pr_loop endp

;------ pr_rd: handle reception  (zf set by called routines)
pr_rd	proc	near
	test	parm3,ptrans
	jz	rderr

	mov	ah,fromc1			;indicate source
	test	parm3,xmodem
	jz	rd1
	call	xm_rd
	jmp	rdx

rd1:	test	parm3,kermit
	jz	rderr
	call	ke_rd
	jmp	rdx

rderr:	mov	msgnum,18		 ;internal error
rdx:	ret
pr_rd	endp

;------ pr_send: add a char to send packet; send packet when ready
;	char to send is in al
pr_send proc	near
	cmp	ah,fromf1	       ;from file
	jne	sex		       ;no -- don't send

	test	parm3,ptrans
	jz	seerr
	test	parm3,xmodem
	jz	se1
	call	xm_send
	jmp	sex

se1:	test	parm3,kermit
	jz	seerr
	call	ke_send
	jmp	sex

seerr:	mov	msgnum,18		 ;internal error
sex:	ret
pr_send endp


;------ pr_abort: abort current send or receive
pr_abort proc	 near
	test	parm3,ptrans
	jz	abx
	test	parm3,xmodem
	jz	ab1
	call	xm_abort
	jmp	abx

ab1:	test	parm3,kermit
	jz	aberr
	call	ke_abort
	jmp	abx

aberr:	mov	msgnum,18		 ;internal error
abx:	ret
pr_abort endp

;------ pr_eof: send end-of-file packet and cleanup after send
pr_eof	proc	near
	test	parm3,ptrans
	jz	eoerr
	test	parm3,xmodem
	jz	eo1
	call	xm_eof
	jmp	eox

eo1:	test	parm3,kermit
	jz	eoerr
	call	ke_eof
	jmp	eox

eoerr:	mov	msgnum,18		 ;internal error
eox:	ret
pr_eof	endp

;------ pr_start: prepare for protocol send or receive
pr_start proc	 near
	push	ax

	or	parm3,ptrans+pause
	call	cm_flush		;clear receive buffer

	and	parm3,255-screen	;turn screen off
	mov	al,parmf
	mov	saved_parmf,al
	and	parmf,255-(autolf+prton+capoff)
	or	parmf,nofilt		;turn filter off

	mov	al,parm2
	mov	saved_parm2,al
	mov	parm2,routek+routeh

	test	parm3,xmodem
	jz	st1
	and	parmf,255-(protxon+protxont+ltcon)
	and	tflag,255-(tdelay+lwait)
	mov	al,twtime
	mov	saved_twtime,al
	mov	twtime,0
	call	cm_8set 		;set up comm line
	call	clrxonw
	call	xm_start
	jmp	stx

st1:	test	parm3,kermit
	jz	sterr
	call	ke_start
	jmp	stx

sterr:	mov	msgnum,18		 ;internal error

stx:	pop	ax
	ret
pr_start endp

;------ pr_finish: restore everything for non-protocol use
pr_finish  proc    near
	push	ax

fi1:	test	tflag,fcap
	jz	fi2
	call	wrtclose		;close capture file
fi2:	and	tflag,255-(fcap+f1src)
	call	setupd			;force redisplay of status line
	call	rdfclose		;close (possibly open) read files

	and	parm3,255-(pause+ptrans)
	or	parm3,screen

	mov	al,saved_parmf
	mov	parmf,al

	mov	al,saved_parm2
	and	al,255-cmndm		;we were in command mode when we saved
					;it, but we're not now
	mov	parm2,al


	test	parm3,xmodem
	jz	fix
	call	cm_8restore
	mov	al,saved_twtime
	mov	twtime,al

fix:	pop	ax
	ret
pr_finish  endp

ten	dw	10
;------ pr_chat: display packet sent/recvd msg
;	bl= {r,s}; ax=seqnum
pr_chat proc	near
	push	ax
	push	bx
	push	cx
	push	dx


	cmp	chatter,chat_on
	je	chat2
	jmp	chatx

chat2:	push	ax			;save parms
	cmp	ax,1			;first seqnum?
	mov	ah,fromt1		   ;fake out window
	jne	chat3			;no

	mov	al,13			;start msgs on new line
	call	window
	mov	al,10
	call	window

chat3:	cmp	bl,'r'                  ;receive or send?
	jne	chats

	mov	al,'R'
	call	window
	mov	al,'e'
	call	window
	mov	al,'c'
	call	window
	mov	al,'v'
	call	window
	mov	al,'d'
	call	window
	mov	al,' '
	call	window
	mov	al,'#'
	call	window
	jmp	chatn

chats:	mov	al,'S'
	call	window
	mov	al,'e'
	call	window
	mov	al,'n'
	call	window
	mov	al,'t'
	call	window
	mov	al,' '
	call	window
	mov	al,'#'
	call	window

chatn:	;print seqnum
	pop	ax		;recover seq num

	sub	dx,dx
	div	ten
	mov	bh,dl		;get remainder (always less than 10)
	add	bh,48		;make ascii

	sub	dx,dx
	div	ten
	mov	bl,dl
	add	bl,48

	sub	dx,dx
	div	ten
	mov	ch,dl
	add	ch,48

	sub	dx,dx
	div	ten
	mov	cl,dl
	add	cl,48

	sub	dx,dx
	div	ten
	add	dl,48			;remainder in dl

	mov	ah,fromt1		;fake out window
	mov	al,dl			;print in reverse order
	call	window
	mov	al,cl
	call	window
	mov	al,ch
	call	window
	mov	al,bl
	call	window
	mov	al,bh
	call	window

	mov	al,13
	call	window

chatx:
	pop	dx
	pop	cx
	pop	bx
	pop	ax
	ret
pr_chat endp

dskmsg	db	13,10,' *** Disk Error; Transfer aborted ***',13,10,0

;------ pr_dskerr: print NOTICEABLE disk error message
pr_dskerr proc	near
	push	ax
	push	si

	mov	ah,fromt1
	mov	si,offset cs:dskmsg

dsklp:	mov	al,cs:[si]
	or	al,al
	jz	dskexit
	call	window
	inc	si
	jmp	dsklp

dskexit: pop	si
	pop	ax
	ret
pr_dskerr endp

cm_code ends
end

