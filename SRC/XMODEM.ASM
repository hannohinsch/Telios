;------ xmodem protocol transfer
;	(C) Copyright 1983  Hanno Hinsch

	public	xm_rd
	public	xm_send
	public	xm_eof
	public	xm_abort
	public	xm_start
	public	xm_loop


cm_data segment public 'code'

allocate = 0
include data.pub

ack	equ	6
eot	equ	4
nak	equ	21
can	equ	24
soh	equ	1

retries 	db	0	;number of timeout retries (maxretry is max)
packet0 	db	132 dup (?)
packet_cnt	db	1	;packet block id
chatnum 	dw	0	;seq num for pr_chat
packet_indx	dw	0	;current byte within packet
checksum	db	0
cur_ptr 	dw	offset packet0

rdbuffer	db	128 dup (?)
rd_indx 	dw	0

state		db	0
ack_wait	equ	1		;sender only
build_packet	equ	2		;sender only
recv_state	equ	3		;receiver active


substate	db	0
send_eot	equ	1
final		equ	2		;sender
send_can	equ	3		;receiver only
startup 	equ	4
continue	equ	5

txbuf		db	256 dup (?)
txhead		dw	0
txtail		dw	0
txbufmask	dw	00ffh
txbufcnt	dw	0

cm_data ends

cm_code segment  public 'code'

assume	cs: cm_code
assume	ds: cm_data

extrn	kbread:near,cm_rd:near,cm_send:near,pmsg:near
extrn	chktime:near,tadd_sec:near,cm_flush:near
extrn	pr_finish:near,window:near,pr_chat:near
extrn	isctsw:near,rtson:near,rtsoff:near


;------ xm_loop: this routine gets control once for every main loop (in TLOOP)
xm_loop proc	near
	push	ax
	push	bx
	push	cx
	push	dx
	push	di
	push	si

	cmp	state,recv_state
	je	lrec
	jmp	lsend

lrec:	cmp	rd_indx,length rdbuffer
	jne	lrecx1				;don't look till buffer empty
	call	cm_rd				;look for char
	jnz	lrec1
	jmp	chktm				;none there

lrec1:	call	show_char
	or	parm3,rtimer			;timer invalid (chr received
	mov	bx,cur_ptr			;store in packet buffer
	mov	si,packet_indx
	mov	byte ptr [bx+si],al

	cmp	si,(length packet0) - 1 	;packet full?
	je	lrec3				;yes...
	inc	packet_indx

	or	si,si
	jnz	lrecx1

	cmp	al,eot				;check out first char
	jne	lrec2
	mov	al,ack				;acknowledge eot
	call	putbuf
	call	show_char
	call	pr_finish
	mov	msgnum,107			;transfer complete
	jmp	lex

lrec2:	cmp	al,soh				;first char must be soh
	je	lrecx1
	mov	packet_indx,0			;restart packet

lrecx1: jmp	lex

lrec3:	;end of packet checking
	; bx = offset of packet0

;	get rid of (possible) junk in receive buffer
	call	cm_flush

	cmp	byte ptr [bx],soh
	je	lrec3a
	jmp	lrnak

lrec3a: mov	al,byte ptr [bx+1]		;get packet_cnt
	mov	dl,byte ptr [bx+2]		; and complement
	add	dl,al				;gotta be 255
	inc	dl
	jnz	lrnak				;no good

	mov	cx,131			       ;calculate checksum
	mov	si,bx
	sub	dl,dl
lrec4:	lodsb
	add	dl,al
	loop	lrec4

	cmp	dl,byte ptr [bx+131]
	jne	lrnak

	mov	al,byte ptr [bx+1]		;get packet cnt again
	cmp	al,packet_cnt			;check block number
	je	lrec5				;ok
	jb	lrack				;already got it
	cmp	al,255
	je	lrack				;catch duplicate block on overflow
;	****	if we get here, we missed a a packet
	jmp	lrnak

lrec5:	inc	packet_cnt

	mov	si,cur_ptr
	add	si,3			;skip header

	push	es
	mov	cx,ds
	mov	es,cx
	mov	di,offset rdbuffer
	mov	cx,128
	rep	movsb			;move string to buffer
	pop	es
	mov	rd_indx,0		;initialize read pointer
	inc	chatnum

lrack:	mov	packet_indx,0
	mov	msgnum,102		;packet ok

	mov	bl,'r'                  ;status report
	mov	ax,chatnum
	call	pr_chat

	mov	retries,0
	mov	al,ack
	cmp	substate,send_can	;cancel requested?
	jne	lrec6
	call	pr_finish
	mov	msgnum,106		;transfer aborted
	mov	al,can
lrec6:	call	putbuf			 ;acknowledge packet
	call	show_char
	jmp	lex

lrnak:	mov	al,nak
	mov	msgnum,103		;packet not ok
	cmp	substate,send_can
	jne	lrec7
	call	pr_finish
	mov	al,can
	mov	msgnum,106		;transfer aborted
lrec7:	call	putbuf
	call	show_char
	mov	packet_indx,0
	jmp	lex

lrecx:	jmp	lex

lsend:	cmp	state,ack_wait
	je	lsen_0
	jmp	chktm

lsen_0: call	cm_rd			;waiting for response to sent packet
	jnz	lsen_1			; (or initial NAK)
	jmp	chktm

lsen_1: call	show_char
	or	parm3,rtimer
	cmp	al,nak
	je	lsnak
	cmp	al,ack
	je	lsack
	cmp	al,can
	je	lscan
	jmp	lex

lscan:	call	pr_finish		;cancel transfer
	mov	msgnum,105
	jmp	lex

lsnak:	mov	msgnum,99		;nak received
	call	pmsg			;print it now

	cmp	substate,startup	;is this initial nak?
	je	lsinak			;yes
	jmp	lsrsp			;no -- resend last packet

lsinak: mov	state,build_packet
	and	parm3,255-pause
	mov	substate,continue
	jmp	lex

lsrsp:	cmp	substate,final		;resend eot if necessary
	jne	lsrsp1			; (no state change necessary)
	mov	al,eot
	call	putbuf
	call	show_char
	jmp	lex

lsrsp1:
	mov	al,retries
	inc	al
	mov	retries,al
	cmp	al,maxretry
	jbe	lrsp2
	call	pr_finish		;that's enough
	mov	msgnum,101		;retry limit reached
	jmp	lex

lrsp2:	mov	bx,cur_ptr		;resend packet
	call	tx_packet
	jmp	lex

lsack:	mov	msgnum,100		;ack received
	cmp	substate,startup
	jne	lsack1
	jmp	lex			;looking for nak, not ack

lsack1: cmp	substate,send_eot	;has last packet been sent?
	je	lseot			;yes
	cmp	substate,final		;is transfer finished?
	je	lsfin			;yes
	jmp	lssnx			;prepare for next packet


lsfin:	call	pr_finish
	mov	msgnum,107		;transfer complete
	jmp	lex

lseot:	mov	al,eot			;send final eot
	call	putbuf
	call	show_char
	mov	state,ack_wait
	mov	substate,final
	jmp	lex

lssnx:	mov	state,build_packet	;prepare to send next packet
	inc	packet_cnt
	mov	packet_indx,0
	and	parm3,255-pause
	mov	retries,0
	inc	chatnum
	jmp	lex

;	since we did nothing this loop, we may have timed out. check for it
chktm:	cmp	timeout,0
	jz	chktm2			;timeout disabled

	test	parm3,rtimer		;is timer ok?
	jz	chktm1			;yes

	and	parm3,255-rtimer		;indicate timer valid again
	mov	al,timeout	;time interval (seconds)
	sub	ah,ah
	call	tadd_sec	;calculate ending time
	mov	timerc,cx	;save hi order
	mov	timerd,dx	;save lo order
	jmp	lex

chktm1: mov	si,offset timerc
	call	chktime
	jz	chktm2			;time not up -- continue

;	we timed out
	or	parm3,rtimer		;mark timer as invalid
	call	xm_time
chktm2:

lex:	call	pmsg			;make sure it gets printed
	call	tx232			;send everything in buffer
	pop	si
	pop	di
	pop	dx
	pop	cx
	pop	bx
	pop	ax
	ret
xm_loop endp


;------ xm_time: handle timeout during both send and receive
xm_time proc	near
	push	ax
	push	bx

	mov	msgnum,98		;packet timeout
	mov	al,retries
	inc	al
	mov	retries,al
	cmp	al,maxretry
	jbe	ti0
	call	pr_finish		;that's enough
	mov	msgnum,101		;retry limit reached
	jmp	tix

ti0:	; check whether send or receive, call appropriate routine
	cmp	state,recv_state
	je	tir			;receiver
	jmp	tis			;sender

tir:	mov	al,nak			;send nak on receive timeout
	cmp	substate,send_can
	jne	tir2
	call	pr_finish
	mov	msgnum,106		;transfer aborted
	mov	al,can
tir2:	call	putbuf
	call	show_char
	mov	packet_indx,0		;start new packet
	jmp	tix

tis:
	cmp	substate,send_eot	;have we tried to stop?
	je	tis2
	cmp	substate,final
	je	tis2
	jmp	tix

tis2:	call	pr_finish		;yes -- pull the plug
	mov	msgnum,106		;transfer aborted

tix:	pop	bx
	pop	ax
	ret
xm_time endp

;------ xm_rd: handle reception
;	massage chars from async buffer.  if complete packet is ready, pass
;	one char back to caller. set zf if no char available
xm_rd	proc	near
	push	si
	push	bx

rd1:	mov	si,rd_indx
	cmp	si,length rdbuffer
	je	rd2
	mov	bx,offset rdbuffer
	mov	al,[bx+si]
	inc	rd_indx
	jmp	rd3

rd2:	cmp	al,al		;clear zf (no char yet
rd3:
	pop	bx
	pop	si
	ret
xm_rd	endp

;------ xm_send: add a char to send packet; send packet when ready
;	char to send is in al
xm_send proc	near
	push	ax
	push	bx
	push	dx
	push	si

	cmp	ah,fromf1
	je	se2z			;send only chars from file
	jmp	sex

se2z:	mov	dl,al			;save char

	cmp	state,build_packet
	jne	se_err

	cmp	packet_indx,0		;build header and first char
	jne	se2a
	mov	bx,cur_ptr
	mov	byte ptr [bx],soh
	mov	checksum,soh
	mov	al,packet_cnt
	mov	byte ptr [bx+1],al
	add	checksum,al
	not	al			;one's complement
	mov	byte ptr [bx+2],al
	add	checksum,al
	mov	byte ptr [bx+3],dl	;store first real char
	add	checksum,dl
	mov	packet_indx,4		;point to second char
	jmp	sex

se2a:	cmp	packet_indx,(length packet0) - 2 ;packet full?
	jb	se2b			;no
	mov	bx,cur_ptr
	mov	si,packet_indx
	mov	byte ptr [bx+si],dl	;store final char
	mov	al,checksum
	add	al,dl			;add last char
	mov	byte ptr [bx+si+1],al	     ;store checksum
	call	tx_packet
	mov	state,ack_wait
	jmp	sex


se2b:	mov	bx,cur_ptr		;store char in packet
	mov	si,packet_indx
	mov	byte ptr [bx+si],dl
	add	checksum,dl
	inc	packet_indx
	jmp	sex

se_err: mov	msgnum,7	;internal error
sex:	pop	si
	pop	dx
	pop	bx
	pop	ax
	ret
xm_send endp

;------ tx_packet: transmit buffer pointed to by BX register
tx_packet proc	near
	push	ax
	push	bx
	push	si
	push	cx

	call	cm_flush		  ;clear receive buffer

	mov	cx,132
	mov	si,bx
txp:	lodsb
	call	show_char		;debug display
	call	putbuf
	loop	txp

	or	parm3,pause+rtimer	;can't send no more
	mov	msgnum,104		;packet sent

	mov	bl,'s'                  ;status msg
	mov	ax,chatnum
	call	pr_chat

	pop	cx
	pop	si
	pop	bx
	pop	ax
	ret
tx_packet endp

;------ xm_abort: abort current send or receive
xm_abort proc	 near
	push	ax
	test	tflag,f1src		;sending?
	jnz	ab1
	cmp	substate,send_can	;have we been here before?
	jne	ab0

	call	pr_finish
	mov	msgnum,106		;transfer aborted
	jmp	ab2

ab0:	mov	substate,send_can	;receiving
	jmp	ab2

ab1:	cmp	substate,send_eot	;have we been here before?
	jne	ab1a

	call	pr_finish
	mov	msgnum,106		;transfer aborted
	jmp	ab2


ab1a:	mov	substate,send_eot	;sending

ab2:
	pop	ax
	ret
xm_abort endp

;------ xm_eof: send end-of-file packet and cleanup after send
xm_eof	proc	near
	push	ax
	push	bx
	push	cx
	push	di
	push	es

	push	ds
	pop	es

	cmp	packet_indx,0		;have we started next packet?
	jne	eo1			;yes-- need to send partial packet

	mov	al,eot			;no -- send eot
	call	putbuf
	call	show_char
	mov	state,ack_wait
	mov	substate,final
	jmp	eox

eo1:	mov	di,cur_ptr		 ;pad buffer w/ nulls
	add	di,packet_indx
	mov	cx,(length packet0) - 1
	sub	cx,packet_indx
	sub	al,al
	rep	stosb

	mov	al,checksum
	stosb
	mov	bx,cur_ptr
	call	tx_packet

	mov	state,ack_wait
	mov	substate,send_eot	     ;send eot next time

eox:	pop	es
	pop	di
	pop	cx
	pop	bx
	pop	ax
	ret
xm_eof	endp

;------ xm_start: prepare for xmodem send or receive
xm_start proc	 near
	push	ax

	call	cm_flush		;clean out receive buffer
	mov	retries,0
	mov	checksum,0
	mov	packet_cnt,1
	mov	packet_indx,0
	mov	cur_ptr,offset packet0
	mov	rd_indx,length rdbuffer
	mov	chatnum,0

	test	tflag,f1src		;sending?
	jz	st2			;no
	mov	state,ack_wait
	mov	substate,startup
	jmp	stx

st2:	mov	state,recv_state
	mov	substate,0
	mov	al,nak			;send initial nak
	call	putbuf
	call	show_char
	jmp	stx

stx:	pop	ax
	ret
xm_start endp


;------ show_char: debugging routine to display char (in al) in window
show_char proc near
	push	ax
	cmp	chatter,chat_bug
	jne	show_x
	mov	ah,fromc1
	or	parmf,autolf
	call	window
	and	parmf,255-autolf
show_x: pop	ax
	ret
show_char endp


;------ tx232:	send stuff in txbuf if ready
tx232	proc	near

tx232a: cmp	txbufcnt,0
	ja	tx232b
	call	rtsoff
	jmp	tx232x

tx232b: call	rtson
	call	isctsw		;check for cts
	jnz	tx232x		; -- we're waiting
	call	getbuf
	call	cm_send 	;send char from buffer
	jmp	tx232a		;send next one

tx232x: ret
tx232	endp

;------ putbuf	: put char (in al) into send buffer
putbuf	proc	near
	push	bx
	push	si

	mov	si,txhead
	mov	bx,offset txbuf
	mov	[si+bx],al	;write char into buffer
	inc	si
	and	si,txbufmask	;account for buffer wrap
	mov	txhead,si	;remember advanced head

	inc	txbufcnt

	pop	si
	pop	bx
	ret
putbuf	endp

;------ getbuf: get char from send buffer into al
getbuf	proc	near
	push	bx
	push	si

	mov	si,txtail
	mov	bx,offset txbuf
	mov	al,[bx+si]		;get char
	inc	si
	and	si,txbufmask
	mov	txtail,si

	dec	txbufcnt

	pop	si
	pop	bx
	ret
getbuf	endp

cm_code ends
end
