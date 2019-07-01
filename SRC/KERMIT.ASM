;------ Kermit protocol transfer

;	(C) Copyright 1983  Hanno Hinsch

	public	ke_rd
	public	ke_send
	public	ke_eof
	public	ke_abort
	public	ke_start
	public	ke_loop
	public	ke_init


cm_data segment public 'code'

allocate = 0
include data.pub

nul	equ	0
ack	equ	6
eot	equ	4
cr	equ	13
lf	equ	10
nak	equ	21
can	equ	24
soh	equ	1
del	equ	127
blank	equ	32

packet struc
@index		dw	?
@markb		db	?
@chrcnt 	db	?
@chrseq 	db	?
@type		db	?
@data		db	96 dup (?)
@check1 	db	?
@check2 	db	?
@check3 	db	?
packet ends

rpacket packet <>
spacket packet <>

rd_exp		db	0	;lil state machine to indicate read state
exp_mark	equ	1
exp_chrcnt	equ	2
exp_chrseq	equ	3
exp_type	equ	4
exp_data	equ	5
exp_check1	equ	6
exp_check2	equ	7
exp_check3	equ	8


;NOTE that many of these defaults have to be reset after each use of the module
retries 	db	0	;number of timeout retries (maxretry is max)
seqnum		db	0	;packet block id
seqmod		equ	00111111b ;byte for mod 64 wrap around
chktype 	db	0	;type of checksum
chk1		equ	'1'     ;single char checksum
chk2		equ	'2'     ;double char checksum
crc16		equ	'3'     ;crc16 packet checking (3 bytes)
terminator	db	cr	;last char of outgoing packets
bufsiz		db	80	;max packet size of host (default)
maxbuf		equ	94	;our max buffer size (don't send 127 or 128)
npad		db	20	;number of pad characters to use
pad		db	nul	;pad char to use
outmark 	db	soh	;start of packet character to send
inmark		db	soh	;start of packet character we're expecting
eol		db	cr	;last char of incoming packets
outquote	db	'#'     ;ctrl character quote for outgoing packets
inquote 	db	'#'     ;ctrl character quote for incoming packets
quote8		db	'&'     ;8-bit character quote
repeat		db	'~'     ;repeat character quote
chatnum 	dw	0	;packet number for pr_chat display

kflag		db	ftime + fexp_packet
fquote8 	equ	1	;8-bit quoting in use
frepeat 	equ	2	;repeat char quoting in use
fpad		equ	4	;pad needed
ftime		equ	8	;timeout checking enforced
fpanic		equ	16	;panic button was hit
fsend_req	equ	32	;send packet prepared and waiting
fexp_packet	equ	64	;we're expecting a packet
fpar8		equ	128	;8-bit data path in use

rdbuffer	db	96  dup (?)
rd_indx 	dw	0
rd_tail 	dw	0

state	db	0
s	equ	1		;send send_init packet
sf	equ	2		;send file_header packet
sd	equ	3		;send file_data packet (start new packet)
sd_con	equ	31		;continue building file_data packet
sz	equ	4		;send eof packet
sb	equ	5		;send break (eot) packet
r	equ	7		;expect send_init
rf	equ	8		;expect file-header packet
rd	equ	9		;expect file-data packet
ra	equ	10		;expect ack/nak packet
rap	equ	105		;expect ack w/parms
c	equ	11		;send complete
a	equ	12		;abort signalled

ack_rec_state	db	0	;send state to set upon receipt of ack

superstate	db	0	; (r)eceive or (s)end

saved_parmf	db	0

;following buffer used by getbuf/putbuf foe flow control
txbuf		db	256 dup (?)
txhead		dw	0
txtail		dw	0
txbufmask	dw	00ffh
txbufcnt	dw	0

crctab	dw	0
	dw	10201q
	dw	20402q
	dw	30603q
	dw	41004q
	dw	51205q
	dw	61406q
	dw	71607q
	dw	102010q
	dw	112211q
	dw	122412q
	dw	132613q
	dw	143014q
	dw	153215q
	dw	163416q
	dw	173617q

crctb2	dw	0
	dw	10611q
	dw	21422q
	dw	31233q
	dw	43044q
	dw	53655q
	dw	62466q
	dw	72277q
	dw	106110q
	dw	116701q
	dw	127532q
	dw	137323q
	dw	145154q
	dw	155745q
	dw	164576q
	dw	174367q
cm_data ends

cm_code segment  public 'code'

assume	cs: cm_code
assume	ds: cm_data

extrn	cm_rd:near,cm_send:near,pmsg:near,ispar8:near
extrn	chktime:near,tadd_sec:near
extrn	cm_flush:near,pr_finish:near,window:near,pr_chat:near
extrn	wait_init:near, waiter:near
extrn	rtson:near,rtsoff:near,isctsw:near

char	macro	register
	add	register,32
	endm

unchar	macro	register
	sub	register,32
	endm

ctl	macro	register
	xor	register,64
	endm

;------ ke_init: set outmark from al
ke_init proc	near
	mov	outmark,al
	ret
ke_init endp


;------ ke_loop: this routine gets control once for every main loop (in TLOOP)
;	check the state, call appropriate routine
;	routines set next state
ke_loop proc	near
	push	ax
	push	cx
	push	dx
	push	si

	cmp	state,a 		;abort -- msgnum should have been
	jne	ko1c			;...set by routine that set state = a
	call	pr_finish
	jmp	kox

ko1c:	test	kflag,fsend_req 		;packet prepared?
	jz	ko1
	test	tflag,(tdelay+lwait)		;waiting for opportunity?
	jz	ko1a				; got it
	call	cm_rd				;check com buffer
	jnz	ko1b				;process char (in al)
	jmp	chktm				;nothing for us

ko1b:	call	show_char			;possible debug display
	mov	ah,fromc1			;indicate source
	mov	cx,msgnum			;protect from waiter
	call	waiter				;look for tchar
	mov	msgnum,cx
	jmp	chktm

ko1a:	call	tx_packet			;send prepared packet
	and	kflag,255-fsend_req

ko1:	cmp	state,s
	jne	ko2
	call	send_send_init
	jmp	korcv
ko2:

	cmp	state,sf
	jne	ko3
	call	send_file_header
	jmp	korcv
ko3:

	cmp	state,sd
	jne	ko4
	call	send_file_data
	jmp	korcv
ko4:

	cmp	state,sz
	jne	ko5
	call	send_eof
	jmp	korcv
ko5:

	cmp	state,sb
	jne	ko6
	call	send_eot
	jmp	korcv

ko6:

ko7:	cmp	state,c
	jne	ko8
	mov	ax,rd_indx
	cmp	ax,rd_tail
	je	ko7a
	jmp	kox			;don't quit till buffer empty
ko7a:	mov	msgnum,107		;transfer complete
	call	pr_finish
	jmp	kox

ko8:	;not in send state (must be waiting for something)


korcv:	test	kflag,fexp_packet	  ;are we expecting?
	jz	korcv2			;no
	call	dlc_recv_packet 	;look for packet
	jnz	koprocess		;found one
korcv2: jmp	chktm

koprocess:

;	we know the other guy is ready, so we can send error packet here
	test	kflag,fpanic
	jz	kr0
	call	panic_response
	jmp	chktm

kr0:	cmp	state,rap
	jne	kr1
	call	recv_parm_ack
	jmp	chktm

kr1:	cmp	state,ra
	jne	kr2
	call	recv_ack
	jmp	chktm

kr2:
	cmp	state,r
	jne	kr3
	call	recv_init
	jmp	chktm
kr3:
	cmp	state,rf
	jne	kr4
	call	recv_file_header
	jmp	chktm
kr4:
	cmp	state,rd
	jne	kr5
	call	recv_file_data
	jmp	chktm

kr5:	call	e_packet		;we received an unexpected packet

;	since we did nothing this loop, we may have timed out. check for it
chktm:	cmp	timeout,0
	jz	chktm2			;timeout disabled

	test	parm3,rtimer		;is timer ok?
	jz	chktm1			;yes

	and	parm3,255-rtimer		;indicate timer valid again
	push	ax
	sub	ah,ah
	mov	al,timeout	;time interval (seconds)
	call	tadd_sec	;calculate ending time
	mov	timerc,cx	;save hi order
	mov	timerd,dx	;save lo order
	pop	ax
	jmp	kox

chktm1: mov	si,offset timerc
	call	chktime
	jz	chktm2			;time not up -- continue

;	we timed out
	or	parm3,rtimer		;mark timer as invalid
	call	ke_time
chktm2:

kox:
	call	tx232			;send stuff in buffer if ready
	pop	si
	pop	dx
	pop	cx
	pop	ax
	ret
ke_loop endp

;------ panic_response: user hit panic button. send error packet, wait
;	for host to acknowledge.  If we time out, we'll automatically abort
;	We also abort when host responds
panic_response proc near
	push	ax

	cmp	rpacket.@type,'N'       ;nak?
	jne	panr2

	mov	al,seqnum
	inc	al
	and	al,seqmod
	cmp	al,rpacket.@chrseq
	je	panr4			;nak for next packet = ack for this
panr1:	mov	state,a 		;we're screwed up -- just abort
	mov	msgnum,106		;transfer aborted
	jmp	panrx

panr2:	cmp	rpacket.@type,'Y'       ;ack?
	jne	panr3			;no -- send error w/out increment

	mov	al,seqnum		;correct seqnum?
	cmp	al,rpacket.@chrseq
	jne	panr1			;no -- abort now

panr4:
	inc	seqnum
	and	seqnum,seqmod

panr3:	call	send_error		;tell host we wanna quit
	mov	state,a
	mov	msgnum,106
	and	kflag,255-fpanic

panrx:	pop	ax
	ret
panic_response endp

; *** OK
;------ send_send_init: send initial packet (if sending)
;	request options as set in defaults (may want to change that later)
send_send_init proc near
	push	ax
	push	dx
	push	si

	mov	spacket.@type,'S'
	mov	spacket.@index,0
	and	kflag,255-fexp_packet

	mov	dl,maxbuf
	char	dl
	mov	si,spacket.@index
	mov	spacket.@data[si],dl
	inc	spacket.@index

	mov	dl,timeout
	char	dl
	mov	si,spacket.@index
	mov	spacket.@data[si],dl
	inc	spacket.@index

	mov	dl,0			;we don't need padding
	char	dl
	mov	si,spacket.@index
	mov	spacket.@data[si],dl
	inc	spacket.@index

	mov	dl,nul			;(don't pad) with nulls
	ctl	dl
	mov	si,spacket.@index
	mov	spacket.@data[si],dl
	inc	spacket.@index

	mov	dl,eol
	char	dl
	mov	si,spacket.@index
	mov	spacket.@data[si],dl
	inc	spacket.@index

	mov	dl,outquote		; what we use to quote outgoing packets
	mov	si,spacket.@index
	mov	spacket.@data[si],dl
	inc	spacket.@index

	mov	dl,'Y'                  ;we will if you will
	test	kflag,fpar8		;do we have 8-bit data path
	jnz	sinit1			;yes
	mov	dl,'&'                  ;8-bit quoting needed if parity in use

sinit1: mov	quote8,dl		;remember what we sent
	mov	si,spacket.@index
	mov	spacket.@data[si],dl
	inc	spacket.@index

;***	mov	dl,crc16		;crc16 (3 byte)
	mov	dl,chk2 		;2 byte checksum, for now
	mov	si,spacket.@index
	mov	spacket.@data[si],dl
	inc	spacket.@index

	mov	dl,blank		;no repeat prefix
	mov	si,spacket.@index
	mov	spacket.@data[si],dl
	inc	spacket.@index

	mov	ack_rec_state,sf
	mov	state,rap
	call	dlc_send_packet
	call	packet_prepared

	pop	si
	pop	dx
	pop	ax
	ret
send_send_init endp

;------ send_recv_init: send initial packet (if receiving)
; this send routine is a little weird in that the states are not modified
send_recv_init proc near
	push	dx

	mov	spacket.@type,'R'
	mov	spacket.@index,0
	and	kflag,255-fexp_packet

; *** should send real filename here

	mov	dl,'f'
	call	add_char
	mov	dl,'o'
	call	add_char
	mov	dl,'o'
	call	add_char

	call	dlc_send_packet
	call	packet_prepared

	pop	dx
	ret
send_recv_init endp

;------ send_file_header
send_file_header proc near
	push	ax
	push	cx
	push	dx
	push	si

	mov	spacket.@type,'F'
	mov	spacket.@index,0
	and	kflag,255-fexp_packet

;	send host file name	(set by parse)
	mov	cx,sflen
	mov	si,offset sfname
	jcxz	sfh3

sfh1:	lodsb
	mov	dl,al
	call	add_char
	loop	sfh1

sfh3:	mov	ack_rec_state,sd
	mov	state,ra
	call	dlc_send_packet
	call	packet_prepared

	pop	si
	pop	dx
	pop	cx
	pop	ax
	ret
send_file_header  endp

; *** OK ***
;------ send_file_data (initialize packet; set sd_con for ke_send)
;	ke_send actually assembles the data packet, and sends it
send_file_data proc near
	mov	spacket.@type,'D'
	mov	spacket.@index,0
	and	kflag,255-fexp_packet
	inc	chatnum 			;pr_chat status display

	and	parm3,255-pause
	mov	state,sd_con
	ret
send_file_data endp

; *** OK ***
;------ send_eof
send_eof proc	near
	mov	spacket.@type,'Z'
	mov	spacket.@index,0
	and	kflag,255-fexp_packet

	mov	ack_rec_state,sb		;eventually, send more files
	mov	state,ra
	call	dlc_send_packet
	call	packet_prepared
	ret
send_eof endp

; *** OK ***
;------ send_eot
send_eot proc near
	mov	spacket.@type,'B'
	mov	spacket.@index,0
	and	kflag,255-fexp_packet

	mov	ack_rec_state,c
	mov	state,ra
	call	dlc_send_packet
	call	packet_prepared
	ret
send_eot endp

; *** OK ***
;------ send_ack: DOES NOT CHANGE STATE
send_ack proc near
	mov	spacket.@type,'Y'
	mov	spacket.@index,0
	and	kflag,255-fexp_packet

	call	dlc_send_packet
	call	packet_prepared
	ret
send_ack endp

;------ send_parm_ack: DOES NOT CHANGE STATE
send_parm_ack proc near
	push	ax
	push	dx
	push	si

	mov	spacket.@type,'Y'
	mov	spacket.@index,0
	and	kflag,255-fexp_packet

	mov	dl,maxbuf
	char	dl
	mov	si,spacket.@index
	mov	spacket.@data[si],dl
	inc	spacket.@index

	mov	dl,timeout
	char	dl
	mov	si,spacket.@index
	mov	spacket.@data[si],dl
	inc	spacket.@index

	mov	dl,0				;don't pad
	char	dl
	mov	si,spacket.@index
	mov	spacket.@data[si],dl
	inc	spacket.@index

	mov	dl,nul				;(unnecessary padchar = nul)
	ctl	dl
	mov	si,spacket.@index
	mov	spacket.@data[si],dl
	inc	spacket.@index

	mov	dl,eol
	char	dl
	mov	si,spacket.@index
	mov	spacket.@data[si],dl
	inc	spacket.@index

	mov	dl,outquote		; what we use to quote outgoing packets
	mov	si,spacket.@index
	mov	spacket.@data[si],dl
	inc	spacket.@index


	mov	dl,'N'                  ;assume no 8-bit quoting wanted
	cmp	quote8,0		;quote8 is what you sent me
	je	spa8			; (0 is initialized value)
	cmp	quote8,'N'
	je	spa8

;	if you sent me 'Y'and we have 7-bit data path, I send you char
;	if you sent me char, I send you 'Y'
	cmp	quote8,'Y'
	je	spa7
	mov	dl,'Y'                  ;quote8 already contains quote char
	or	kflag,fquote8		;use quoting
	jmp	spa8

spa7:	;you assent to do quoting, but didn't demand it (you sent 'Y')
	test	kflag,fpar8		;do i have 8-bit path?
	jnz	spa8			;yes -- no quoting necessary
	mov	quote8,'&'              ;no -- use this quote char
	mov	dl,'&'
	or	kflag,fquote8		;use quoting

spa8:	mov	si,spacket.@index
	mov	spacket.@data[si],dl
	inc	spacket.@index

	mov	dl,chktype		;we do what is asked
	mov	si,spacket.@index
	mov	spacket.@data[si],dl
	inc	spacket.@index

	mov	dl,blank		;no repeat prefix
	mov	si,spacket.@index
	mov	spacket.@data[si],dl
	inc	spacket.@index

	mov	al,chktype
	mov	chktype,chk1		;always send parm_ack w/ chk1
	call	dlc_send_packet
	mov	chktype,al

	call	packet_prepared

	pop	si
	pop	dx
	pop	ax
	ret
send_parm_ack endp

; *** OK ***
;------ send_nak: DOES NOT CHANGE STATE
send_nak proc near
	push	ax
	mov	spacket.@type,'N'
	mov	spacket.@index,0
	and	kflag,255-fexp_packet

	mov	al,retries		;protect from reset in dlc_send_packet
	call	dlc_send_packet
	mov	retries,al

	call	packet_prepared
	pop	ax
	ret
send_nak endp

; *** OK
;------ send_error
send_error proc near
	mov	spacket.@type,'E'
	mov	spacket.@index,0
	and	kflag,255-fexp_packet

	call	dlc_send_packet
	call	packet_prepared
	ret
send_error endp

;------ send_host_cmnd proc near
send_host_cmnd proc near
	mov	spacket.@type,'C'
	mov	spacket.@index,0
	and	kflag,255-fexp_packet

	call	dlc_send_packet
	call	packet_prepared
	ret
send_host_cmnd endp

;------ send_generic_cmnd
send_generic_cmnd proc near
	mov	spacket.@type,'G'
	mov	spacket.@index,0
	and	kflag,255-fexp_packet

	call	dlc_send_packet
	call	packet_prepared
	ret
send_generic_cmnd endp

;*
;* The receive subroutines (below) all process an rpacket that has
;* been prepared by dlc_recv_packet.  They are called by loopunit,
;* which keeps track of what kind of packet is expected.
;* Each routine should check the sequence number (and possibly increment it),
;* the packet type, and also acknowledge the received packet (if required).
;* Each routine is responsible for setting the state.
;*

;------ recv_init
;	want send_init packet. ack it w/local parms
recv_init proc near
	push	ax
	push	bx
	push	cx
	push	dx
	push	si

	cmp	rpacket.@type,'S'
	je	ri1
	call	e_packet
	jmp	rix			;ignore unknown packet types

; *** don't we need to check seqnum here?

ri1:	mov	si,offset rpacket.@data
	sub	ch,ch
	mov	cl,rpacket.@chrcnt
	sub	cx,3			;account for seqnum, type, chk1

	or	cx,cx
	jnz	ri4
	jmp	ri_end

ri4:	mov	dl,[si]
	unchar	dl
	mov	bufsiz,dl

	inc	si
	dec	cx
	jnz	ri5
	jmp	ri_end

ri5:	mov	dl,[si]
	unchar	dl
	mov	timeout,dl

	inc	si
	dec	cx
	jnz	ri6
	jmp	ri_end

ri6:	mov	dl,[si]
	unchar	dl
	mov	npad,dl
	and	kflag,255-fpad
	or	dl,dl
	jz	ri3
	or	kflag,fpad		;remember to pad

ri3:	inc	si
	dec	cx
	jnz	ri8
	jmp	ri_end

ri8:	mov	dl,[si]
	ctl	dl
	mov	pad,dl

	inc	si
	dec	cx
	jnz	ri9
	jmp	ri_end

ri9:	mov	dl,[si]
	unchar	dl
	mov	terminator,dl

	inc	si
	dec	cx
	jnz	ri10
	jmp	ri_end

ri10:	mov	dl,[si]
	mov	inquote,dl		;quote that other guy uses (we recv)

	inc	si
	dec	cx
	jnz	ri11
	jmp	ri_end

ri11:
	mov	dl,[si]
	mov	quote8,dl		;(send_parm_ack finishes setup)

ri11a:	inc	si
	dec	cx
	jnz	ri12
	jmp	ri_end

ri12:	mov	dl,[si] 		;set new chktype
;**	mov	chktype,crc16		;crc removed for now
;**	cmp	dl,crc16
;**	je	ri7
	mov	chktype,chk2
	cmp	dl,chk2
	je	ri7
	mov	chktype,chk1
ri7:

	inc	si
	dec	cx
	jnz	ri13
	jmp	ri_end

ri13:	mov	dl,[si]
	mov	dl,blank		;no repeat prefix yet either

ri_end: mov	state,rf

	call	send_parm_ack
	inc	seqnum
	and	seqnum,seqmod
	jmp	rix

rix:
	pop	si
	pop	dx
	pop	cx
	pop	bx
	pop	ax
	ret
recv_init endp

;------ recv_file_header
;	treat it as data, for now
; *** in theory, this is the local name we should give the file,
;	but in fact we use the name specified on the command line.
recv_file_header proc near
	push	ax

	mov	al,rpacket.@type

	cmp	al,'S'
	jne	rfh2
	jmp	rfh_s

rfh2:	cmp	al,'Z'
	jne	rfh3
	jmp	rfh_z

rfh3:	cmp	al,'B'
	jne	rfh4
	jmp	rfh_b

rfh4:	cmp	al,'F'
	jne	rfh5
	jmp	rfh_f

rfh5:	call	e_packet
	jmp	rfhx

rfh_s:	;received send_init
rfh_z:	;received eof

	mov	al,seqnum
	dec	al
	and	al,seqmod
	cmp	al,rpacket.@chrseq	;same as last packet?
	jne	rfh5			; no -- ignore
	call	packet_prepared 	; yes -- resend acknowledgment
	jmp	rfhx

rfh_f:	mov	al,seqnum
	cmp	al,rpacket.@chrseq
	jne	rfh5			;ignore
	; *** in theory, we open local file w/ this file header
	call	send_ack
	inc	seqnum
	and	seqnum,seqmod
	mov	state,rd		;ready to receive data
	jmp	rfhx

rfh_b:	mov	al,seqnum
	cmp	al,rpacket.@chrseq
	jne	rfh5			;ignore
	call	send_ack
	mov	state,c 		;transmission complete
	jmp	rfhx

rfhx:
	pop	ax
	ret
recv_file_header endp

;------ recv_file_data
;	check out packet (seqnum, type) and respond
;	if packet ok -- move to read buffer
recv_file_data proc near
	push	ax
	push	bx
	push	cx
	push	dx
	push	di
	push	si
	push	es

	mov	al,rpacket.@type
	cmp	al,'D'
	jne	rfd2
	jmp	rfd_d

rfd2:	cmp	al,'Z'
	jne	rfd4
	jmp	rfd_z

rfd4:	cmp	al,'F'
	jne	rfd5
	jmp	rfd_f

rfd5:	call	e_packet
	jmp	recvx

rfd_d:	;received data packet
	mov	al,seqnum
	cmp	al,rpacket.@chrseq	;right packet num?
	je	rfd_d2

	call	packet_prepared 	; no -- resend acknowledgment
	jmp	recvx

rfd_d2: ;process good packet

	mov	rpacket.@index,0
	call	send_ack
	inc	seqnum
	and	seqnum,seqmod

;	move data to receive buffer (includes unquoting)
	mov	rd_tail,0
	mov	rd_indx,0

	mov	cx,ds
	mov	es,cx
	mov	di,offset rdbuffer
	mov	si,offset rpacket.@data
	sub	ch,ch
	mov	cl,rpacket.@chrcnt
	sub	cx,3			;account for seqnum, type, chk1
	cmp	chktype,chk1
	je	recv6
	dec	cx			;account for chk2
	cmp	chktype,chk2
	je	recv6
	dec	cx			;account for crc16
recv6:	mov	bl,inquote

	mov	bh,bl
	or	bh,80h			;bh = quote w/8-bit on

	mov	dl,quote8

	jcxz	 recv9
recv7:	lodsb
	sub	dh,dh			;no high bit yet
	test	kflag,fquote8
	jz	recv7m			;no 8-bit quoting
	cmp	al,dl			;is it 8-quote?
	jne	recv7m			;no
	mov	dh,80h			;turn on high bit
	lodsb				;get next char
	dec	cx

recv7m: cmp	al,bl			;quote character ?
	jne	recv8			;no -- store this one
	lodsb				;yes -- get quoted character
	dec	cx			;keep cnt correct (LOOP ins also dec's)
	cmp	al,bl			;quote?
	je	recv8
	cmp	al,bh			;quote w/eight bit on?
	je	recv8
	test	kflag,fquote8
	jz	recv7r
	cmp	al,dl			;is it 8-quote?
	je	recv8			;yes -- skip un-ctrl

recv7r: ctl	al			;unctl it
recv8:	or	al,dh			;or in possible high bit
	stosb				;store char into read buffer
	inc	rd_tail
	jcxz	recv9			;should never happen
	loop	recv7

recv9:
	mov	state,rd

	mov	bl,'r'
	inc	chatnum
	mov	ax,chatnum
	call	pr_chat 		;write packet status msg

	or	al,1			;clear zf to indicate packet is ready
	jmp	recvx


rfd_z:	;received end of file
	mov	al,seqnum
	cmp	al,rpacket.@chrseq	;check num
	je	rfd_z2
	cmp	al,al			;set zf (packet not ready)
	jmp	recvx

rfd_z2: call	send_ack
	; *** in theory, we close the current file here
	inc	seqnum
	and	seqnum,seqmod
	mov	state,rf		;look for file header
	cmp	al,al			;set zf
	jmp	recvx

rfd_f:	;received file header
	mov	al,seqnum		;is it last packet?
	dec	al
	and	al,seqmod
	cmp	al,rpacket.@chrseq
	je	rfd_f2			;yes
	cmp	al,al
	jmp	recvx			;ignore it

rfd_f2: call	packet_prepared 	      ;resend last acknowledgment
	cmp	al,al
	jmp	recvx


recvx:
	pop	es
	pop	si
	pop	di
	pop	dx
	pop	cx
	pop	bx
	pop	ax
	ret
recv_file_data endp

; *** OK ***
;------ recv_ack: looking for ack
;	resend packet if nak, else goto ack_rec_state
recv_ack proc near
	push	ax

	cmp	rpacket.@type,'N'       ;nak
	jne	rac2
	mov	msgnum,99		;nak received
	mov	al,seqnum
	inc	al
	and	al,seqmod
	cmp	al,rpacket.@chrseq
	je	rac4			;nak for next packet = ack for this
rac1:	call	packet_prepared 	      ;resend last packet
	jmp	racx

rac2:	cmp	rpacket.@type,'Y'       ;ack
	jne	rac3

	mov	al,seqnum		;correct seqnum?
	cmp	al,rpacket.@chrseq
	jne	rac1

rac4:	mov	msgnum,100		;ack received
	inc	seqnum
	and	seqnum,seqmod

	mov	al,ack_rec_state	;switch to next state
	mov	state,al
	jmp	racx

rac3:	call	e_packet
racx:
	pop	ax
	ret
recv_ack endp

;------ recv_parm_ack (response to our send_init)
;	store parms that come w/ response
;	resend packet if nak, else goto ack_rec_state
recv_parm_ack proc near
	push	ax
	push	cx
	push	dx
	push	si

	cmp	rpacket.@type,'N'       ;nak
	jne	rpa2
	mov	msgnum,99		;nak received
rpa1:	call	packet_prepared 	;resend last packet
	jmp	rpax2

rpa2:	cmp	rpacket.@type,'Y'       ;ack
	je	rpa4
	call	e_packet
	jmp	rpax2			;abort

rpa4:
	mov	al,seqnum		;correct seqnum?
	cmp	al,rpacket.@chrseq
	jne	rpa1			;resend

	mov	msgnum,100		;ack received
	mov	si,offset rpacket.@data
	sub	ch,ch
	mov	cl,rpacket.@chrcnt
	sub	cx,3			;account for seqnum, type, chk1
					;(parm-ack should always come w/ chk1)
rp2:	or	cx,cx
	jnz	rp4
	jmp	rpax

rp4:	mov	dl,[si]
	unchar	dl
	mov	bufsiz,dl

	inc	si
	dec	cx
	jnz	rp5
	jmp	rpax

rp5:	mov	dl,[si]
	unchar	dl
	mov	timeout,dl

	inc	si
	dec	cx
	jnz	rp9
	jmp	rpax

rp9:	mov	dl,[si]
	unchar	dl
	mov	npad,dl
	and	kflag,255-fpad
	or	dl,dl
	jz	rp3
	or	kflag,fpad		;remember to pad

rp3:	inc	si
	dec	cx
	jnz	rp10
	jmp	rpax

rp10:	mov	dl,[si]
	ctl	dl
	mov	pad,dl

	inc	si
	dec	cx
	jnz	rp11
	jmp	rpax

rp11:	mov	dl,[si]
	unchar	dl
	mov	terminator,dl

	inc	si
	dec	cx
	jnz	rp12
	jmp	rpax

rp12:	mov	dl,[si]
	mov	inquote,dl		;quote that other guy uses (we recv)

	inc	si
	dec	cx
	jnz	rp13
	jmp	rpax

rp13:	mov	dl,[si] 		;8-bit quoting arbitration
	cmp	dl,'N'
	je	rp13n			;no quote wanted

	cmp	dl,'Y'
	je	rp13aa			;go check out 'Y'
	mov	quote8,dl		;use suggested 8 bit char
	jmp	rp13y

rp13aa: cmp	quote8,'Y'              ;did we send a 'Y'
	je	rp13n			;yes -- so neither of us needs it
					;no -- use what we sent

rp13y:	or	kflag,fquote8
	jmp	rp13a

rp13n:	and	kflag,255-fquote8

rp13a:	inc	si
	dec	cx
	jnz	rp14
	jmp	rpax

rp14:	mov	dl,[si] 		;we sent '2'; if anything else
	mov	chktype,chk2		; comes back, we go with chk1
	cmp	dl,chk2 		;**** change for crc16
	je	rp7
	mov	chktype,chk1
rp7:

	inc	si
	dec	cx
	jnz	rp15
	jmp	rpax

rp15:	mov	dl,[si]
	mov	dl,blank		;no repeat prefix yet either

rpax:	inc	seqnum
	and	seqnum,seqmod

	mov	al,ack_rec_state	;switch to next state
	mov	state,al
	jmp	rpax2

rpax2:
	pop	si
	pop	dx
	pop	cx
	pop	ax
	ret
recv_parm_ack endp


; *** OK ***
;------ dlc_send_packet: add data link info to spacket
;	mark, chrcnt, seqnum, checksum
dlc_send_packet proc near
	push	ax
	push	bx
	push	cx
	push	dx
	push	si

	mov	retries,0

	mov	al,outmark
	mov	spacket.@markb,al

	mov	ax,spacket.@index	;number of data bytes (ax < 255)
	add	al,3			;add for seqnum,type,checknum
	cmp	chktype,chk1		;single byte check?
	je	dsp1
	inc	al			;add another for 2-byte check
	cmp	chktype,chk2
	je	dsp1
	inc	al			;three byte check
dsp1:	char	al
	mov	spacket.@chrcnt,al

	mov	al,seqnum
	and	al,seqmod
	char	al
	mov	spacket.@chrseq,al

	mov	si,offset spacket
	call	comp_check		;get checksum into ax,bl
	mov	word ptr spacket.@check1,ax
	mov	byte ptr spacket.@check3,bl

dspx:	pop	si
	pop	dx
	pop	cx
	pop	bx
	pop	ax
	ret
dlc_send_packet endp

; *** OK ***
;------ dlc_recv_packet: process chars in recv buffer, if any
;	clear zf if a packet is ready
dlc_recv_packet proc near
	push	ax
	push	bx
	push	cx
	push	dx
	push	di
	push	si
	push	es

	mov	ax,rd_indx
	cmp	ax,rd_tail
	je	dlr1
	jmp	lrecx				;don't look till buffer empty

dlr1:	call	cm_rd				;look for char
	jnz	lrec1
	jmp	lrecx				;none there

lrec1:	or	parm3,rtimer			;indicate timer invalid

	call	show_char

	cmp	al,inmark
	jne	lrec0
	jmp	act_mark			;resynchronize on mark

lrec0:	cmp	rd_exp,exp_data
	jne	lrstat1
	jmp	act_data

lrstat1:cmp	rd_exp,exp_mark
	jne	lrstat2
	jmp	act_mark

lrstat2:cmp	rd_exp,exp_chrcnt
	jne	lrstat3
	jmp	act_chrcnt

lrstat3:cmp	rd_exp,exp_chrseq
	jne	lrstat4
	jmp	act_chrseq

lrstat4:cmp	rd_exp,exp_type
	jne	lrstat5
	jmp	act_type

lrstat5:cmp	rd_exp,exp_check1
	jne	lrstat6
	jmp	act_check1

lrstat6:cmp	rd_exp,exp_check2
	jne	lrstat7
	jmp	act_check2

lrstat7:cmp	rd_exp,exp_check3
	jne	lrstat8
	jmp	act_check3

lrstat8:;***** error situation ******

;	al contains received character
act_mark:
	cmp	al,inmark		  ;ignore all till mark
	jne	mrej
	mov	rd_exp,exp_chrcnt
	mov	rpacket.@index,0
mrej:	jmp	lrecx

act_chrcnt:
	mov	rpacket.@chrcnt,al
	mov	rd_exp,exp_chrseq
	jmp	lrecx

act_chrseq:
	mov	rpacket.@chrseq,al
	mov	rd_exp,exp_type
	jmp	lrecx

act_type:
	mov	rpacket.@type,al
	mov	rd_exp,exp_data
	jmp	lrecx

act_data:
	mov	si,rpacket.@index

	sub	bx,bx
	mov	bl,rpacket.@chrcnt
	unchar	bl
	sub	bx,3			;account for sequence, type, chk1 fields
	cmp	chktype,chk1
	je	acda2
	dec	bx			;account for chk2
	cmp	chktype,chk2
	je	acda2
	dec	bx

acda2:	cmp	si,bx
	jb	mordat
	jmp	act_check1		;not our character

mordat: mov	rpacket.@data[si],al
	inc	si
	mov	rpacket.@index,si
	jmp	lrecx

act_check1:
	mov	rpacket.@check1,al
	mov	rd_exp,exp_check2
	cmp	chktype,chk1
	jne	lmchk
	jmp	lrec2			;end of packet checking
lmchk:	jmp	lrecx

act_check2:
	mov	rpacket.@check2,al
	mov	rd_exp,exp_check3
	cmp	chktype,chk2
	jne	lmchk2
	jmp	lrec2			;packet finished -- go check it out
lmchk2: jmp	lrecx

act_check3:
	mov	rpacket.@check3,al
	jmp	lrec2



;	check the packet (calculate and compare checksum)
;	if checksum error, ignore packet
lrec2:
	mov	rd_exp,exp_mark 	;reset lil state machine
	mov	si,offset rpacket
	call	comp_check		;compute checksum (in ax, bl)
	cmp	chktype,chk1
	jne	lrec3
	cmp	al,rpacket.@check1
	je	lrec5
	jmp	lrignore

lrec3:	cmp	chktype,chk2
	jne	lrec4
	cmp	al,rpacket.@check1
	jne	lrec35
	cmp	ah,rpacket.@check2
	je	lrec5
lrec35: jmp	lrignore

lrec4:	cmp	al,rpacket.@check1
	jne	lrec45
	cmp	ah,rpacket.@check2
	jne	lrec45
	cmp	bl,rpacket.@check3
	je	lrec5
lrec45: jmp	lrignore


lrignore:
	mov	msgnum,103		;received packet not ok
	jmp	lrecx

lrec5:
	mov	msgnum,102		;received packet ok

	mov	al,rpacket.@chrcnt
	unchar	al
	mov	rpacket.@chrcnt,al

	mov	al,rpacket.@chrseq
	unchar	al
	mov	rpacket.@chrseq,al

	or	al,1			;clear zf -- packet ready
	jmp	lrecx2

lrecx:	cmp	al,al			;set zf -- no packet ready
lrecx2: pop	es
	pop	si
	pop	di
	pop	dx
	pop	cx
	pop	bx
	pop	ax
	ret
dlc_recv_packet endp

; *** OK
;------ comp_check: compute checksum
;	si points to packet; on exit AX, BL contains checksum
;	note that checksum calculation, and value of AX, depends on chktype
;	note that this procedure transforms checksum via CHAR macro
comp_check proc near
	push	cx
	push	dx
	push	si

	sub	ax,ax
	mov	cx,[si].@index		;index = # of data chars in buffer
	add	cx,3			;add for chrcnt,seqnum,type
	sub	bx,bx
	add	si,@chrcnt		;point to checksumable data

	cmp	chktype,crc16
	je	com5
com3:
	mov	bl,byte ptr [si]
	add	ax,bx
	inc	si
	loop	com3

;	ax now contains 2-byte checksum

	cmp	chktype,chk1		;do one byte checksum (into al)
	jne	com4
	mov	bl,al
	and	bl,11000000b
	mov	cl,6
	shr	bl,cl
	add	al,bl
	and	al,00111111b
	char	al
	jmp	comx


com4:	mov	bx,ax			;2-byte check
	and	al,00111111b		;bits 0-5
	mov	ah,al			;check2 into ah
	char	ah

	mov	cl,6			;bits 6-11
	shr	bx,cl
	and	bl,00111111b
	mov	al,bl			;check1 into al
	char	al
	jmp	comx


com5:	;si --> string; cx has length
	sub	dx,dx			;dx contains crc
	jcxz	lp4			;cx contains character count

kp1:	lodsb
	xor	ax,dx

	push	cx

	mov	bx,ax			;high 4 bits
	mov	cl,4
	shr	bx,cl
	and	bx,000fh

	mov	di,ax
	and	di,000fh		;low 4 bits

	mov	ax,crctb2[di]
	xor	ax,crctab[bx]

	mov	dl,dh			;shift right 8
	sub	dh,dh

	xor	dx,ax

	pop	cx
	loop	kp1

lp4:	;crc16 in dx
	mov	ax,dx			;3-byte check
	and	al,00111111b		;bits 0-5
	mov	bl,al			;check3 into bl
	char	bl

	mov	ax,dx
	mov	cl,6			;bits 6-11
	shr	ax,cl
	and	al,00111111b
	mov	ah,al			;check2 into ah
	char	ah

	mov	cl,12			;bits 12-15
	shr	dx,cl			; top bits all 0
	mov	al,dl			;check1 into al
	char	al

	jmp	comx

comx:

	pop	si
	pop	dx
	pop	cx
	ret
comp_check endp

; *** OK ***
;------ ke_time: handle timeout during both send and receive
ke_time proc	near
	push	ax

	test	kflag,fpanic		;if panic button hit, then quit now
	jnz	ti00
	jmp	ti000


ti00:	and	kflag,255-fpanic
	mov	state,a
	mov	msgnum,106
	jmp	tix

ti000:
	mov	msgnum,98		;packet timeout
	mov	al,retries
	cmp	al,maxretry
	jle	ti0
	mov	msgnum,101		;retry limit reached
	mov	state,a 		;abort
	jmp	tix

ti0:	or	parm3,rtimer		;indicate timer invalid

	call	bail_out		;send something
	call	tx_packet		;resend (increments 'retries', as well)
	and	kflag,255-fsend_req	;note that we send right away

tix:	and	tflag,255-(lwait+tdelay)  ;stop waiting for send opportunity
	pop	ax
	ret
ke_time endp

; *** OK
;------ bail_out: send nak or resend last packet, depending on state
;	called by timeout or dlc_recv_packet when things go awry
bail_out proc near
	cmp	superstate,r
	je	bor			;receiver
	jmp	bos			;sender

bor:
	call	send_nak
	jmp	bosx

bos:	; resend last packet in all send states ...

bosx:	call	packet_prepared 	;wait for send opportunity
	ret
bail_out endp


; *** OK ***
;------ ke_rd: handle reception
;	massage chars from packet buffer.  if complete packet is ready, pass
;	one char back to caller. set zf if no char available
ke_rd	proc	near
	push	si
	push	bx

	test	parm3,ptrans
	jnz	rd1
	mov	msgnum,7	;internal error
	jmp	rd2

rd1:	mov	si,rd_indx
	cmp	si,rd_tail
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
ke_rd	endp

; *** OK ***
;------ ke_send: add a char to send packet; send packet when ready
;	char to send is in al; add it to spacket
ke_send proc	near
	push	ax
	push	bx
	push	dx
	push	si

	cmp	ah,fromf1
	je	se2z			;send only chars from file
	jmp	sex

se2z:	mov	dl,al			;save char
	test	parm3,ptrans
	jz	se_err

	cmp	state,sd_con		;send data packet?
	je	se2a
	jmp	se_err

se2a:
	call	add_char
	sub	ah,ah
	mov	al,bufsiz		;packet full?
	sub	al,10			;subtract fixed fields/ possible quote
	cmp	ax,spacket.@index
	ja	sex			;no
	call	dlc_send_packet 	;yes -- send it
	call	packet_prepared
	mov	ack_rec_state,sd
	mov	state,ra
	or	parm3,pause			;stop sending
	mov	msgnum,104		;packet sent
	jmp	sex

se_err: mov	msgnum,7	;internal error
sex:	pop	si
	pop	dx
	pop	bx
	pop	ax
	ret
ke_send endp

; *** OK
;------ add_char: add data character to spacket, doing all necessary quoting
;	char to be added is in dl
add_char proc	near
	push	ax
	push	bx
	push	si

	mov	bx,offset spacket.@data ;store char in packet
	mov	si,spacket.@index


	or	dl,dl			;high bit on ?
	jns	add3			;no
	test	kflag,fquote8+fpar8	;can we send 8-bit?
	jnz	add4			;yes -- go send it
	mov	msgnum,128		;no -- give error msg
	mov	state,a 		;and abort
	jmp	addx

add4:	test	kflag,fquote8		;should we quote?
	jz	add3			;no, don't bother

	and	dl,7fh			;strip high bit
	mov	al,quote8		;quote it
	mov	byte ptr [bx+si],al
	inc	si

add3:	mov	al,dl
	and	al,01111111b		;check low seven bits
	cmp	al,blank		;do quoting
	jb	add0
	cmp	al,del
	je	add0
	cmp	al,outquote
	je	add1
	test	kflag,fquote8
	jz	add2
	cmp	al,quote8
	je	add1
	jmp	add2

add0:	ctl	dl
	jmp	add1

add1:	mov	al,outquote
	mov	byte ptr [bx+si],al
	inc	si
add2:	mov	byte ptr [bx+si],dl
	inc	si

	mov	spacket.@index,si

addx:
	pop	si
	pop	bx
	pop	ax
	ret
add_char endp

; *** OK ***
;------ packet_prepared: called when spacket should be sent
;	packet is actually sent at first send opportunity
packet_prepared proc near

	or	kflag,fsend_req 	;note request to send

	ret
packet_prepared endp

; *** OK ***
;------ tx_packet: transmit spacket
tx_packet proc	near
	push	ax
	push	si
	push	cx

	mov	al,retries
	inc	al
	mov	retries,al
	cmp	al,maxretry
	jle	pa00
	mov	msgnum,101			;retry limit reached
	mov	state,a
	jmp	pax


pa00:	test	kflag,fpad		;leading pad chars?
	jz	pa1
	sub	ch,ch
	mov	cl,npad
	jcxz	pa1

pa0:	mov	al,pad
	call	putbuf

	call	show_char

	loop	pa0

pa1:	mov	cx,4
	add	cx,spacket.@index
	mov	si,offset spacket.@markb
txp:	lodsb
	call	putbuf

	call	show_char

	loop	txp

	mov	al,spacket.@check1		;1 or 2 or 3 byte checksums
	call	show_char
	call	putbuf
	cmp	chktype,chk1
	je	pa3

	mov	al,spacket.@check2		;2 or 3
	call	show_char
	call	putbuf
	cmp	chktype,chk2
	je	pa3

	mov	al,spacket.@check3		;3
	call	show_char
	call	putbuf

pa3:	call	cm_flush		;flush receive buffer
	mov	al,terminator
	call	putbuf

	call	show_char
	or	kflag,fexp_packet	  ;look for response

	call	wait_init

	cmp	spacket.@type,'D'       ;data packet?
	jne	pax
	mov	bl,'s'
	mov	ax,chatnum
	call	pr_chat 		;write status msg

pax:	pop	cx
	pop	si
	pop	ax
	ret
tx_packet endp

; *** OK ***
;------ ke_abort: abort current send or receive (panic button routine)
ke_abort proc	 near
	test	parm3,ptrans
	jz	ab3

	test	kflag,fpanic		;if panic button hit twice, quit now
	jz	ab2

	and	kflag,255-fpanic
	mov	state,a
	mov	msgnum,106
	jmp	ab3

ab2:	or	kflag,fpanic
ab3:
	ret
ke_abort endp

;*** OK ***
;------ ke_eof: send end-of-file packet and cleanup after send
ke_eof	proc	near

	test	parm3,ptrans
	jnz	eo1
	mov	msgnum,7		;internal error
	jmp	eox

	mov	state,sz		;don't send empty packet
	cmp	rpacket.@index,0
	je	eox

eo1:	; send in-progress data packet
	call	dlc_send_packet 	;yes -- send it (could be empty)
	call	packet_prepared
	mov	ack_rec_state,sz
	mov	state,ra
	or	parm3,pause			;stop sending
eox:	ret
ke_eof	endp

; *** OK ***
;------ ke_start: prepare for kermit send or receive
ke_start proc	 near
	push	ax
	test	parm3,ptrans
	jnz	st1
	mov	msgnum,7		;internal error
	jmp	stx

st1:
	mov	rd_exp,exp_mark
	mov	retries,0

	mov	seqnum,0
	mov	chktype,chk1
	mov	terminator,cr
	mov	bufsiz,80		;default host buffer size
	mov	npad,0
	mov	pad,nul
	mov	eol,cr
	mov	inquote,'#'
	mov	outquote,'#'
	mov	quote8,0
	mov	repeat,'~'
	mov	chatnum,0

	mov	rd_indx,0
	mov	rd_tail,0

	mov	kflag,ftime+fexp_packet

	call	ispar8
	jnz	st1a
	or	kflag,fpar8		;8-bit path available

st1a:	test	tflag,f1src		;sending?
	jz	st2			;no
	mov	state,s
	mov	superstate,s
	jmp	stx

st2:	mov	state,r 		;receiving
	mov	superstate,r
	jmp	stx

stx:	pop	ax
	ret
ke_start endp

;------ e_packet: display contents if error packet and set state=abort
;	if unknown packet type, just return
e_packet proc	near
	push	ax
	push	bx
	push	cx
	push	dx
	push	si
	push	di
	push	es


	cmp	rpacket.@type,'E'               ;error packet?
	jne	e_pc10				;no

;	display data in packet (includes unquoting)
	mov	cx,ds
	mov	es,cx
	mov	si,offset rpacket.@data
	sub	ch,ch
	mov	cl,rpacket.@chrcnt
	sub	cx,3			;account for seqnum, type, chk1
	cmp	chktype,chk1
	je	e_pc6
	dec	cx			;account for chk2
	cmp	chktype,chk2
	je	e_pc6
	dec	cx			;account for chk3

; *** this doesn't know about 8-bit quote  (should not matter)

e_pc6:	mov	bl,inquote
	mov	bh,bl
	or	bh,80h			;bh = quote w/8-bit

	jcxz	e_pc9
e_pc7:	lodsb
	cmp	al,bl			;quote character ?
	jne	e_pc8
	lodsb				;get quoted character
	dec	cx			;keep cnt correct (LOOP ins also dec's)
	cmp	al,bl			;is it quote
	je	e_pc8			;keep it
	cmp	al,bh			;high quote?
	je	e_pc8			;keep it
	ctl	al			;unquote it
e_pc8:	mov	ah,fromc1		;pretend char is from comm1
	call	window			;store char in read buffer and screen
	jcxz	e_pc9			;should never happen
	loop	e_pc7
e_pc9:
	; set state= abort
	mov	state,a
	mov	msgnum,106

e_pc10: pop	es
	pop	di
	pop	si
	pop	dx
	pop	cx
	pop	bx
	pop	ax
	ret
e_packet endp

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