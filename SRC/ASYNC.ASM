;------ asynchronous adapter subroutines

	public	cm_enable
	public	cm_break
	public	cm_restore
	public	cm_send
	public	cm_rd

	public	cm_epar
	public	cm_opar
	public	cm_spar
	public	cm_mpar
	public	cm_paroff
	public	cm_8set
	public	cm_8restore

	public	cm_b110
	public	cm_b150
	public	cm_b300
	public	cm_b600
	public	cm_b1200
	public	cm_b2400
	public	cm_b4800
	public	cm_b9600

	public	isxonw
	public	ispar8
	public	isdsron
	public	dtroff
	public	clrxonw
	public	chk_cd			;set carrier msg, if change
	public	cm_cd			;set CF if offline
	public	cm_flush
	public	cm_setup
	public	cm_ring

	public	rtson
	public	rtsoff
	public	isctsw

cm_data segment  public 'code'

allocate = 0
include data.pub


;------------- current async port registers and definitions ----------------
pdefs	equ	this byte
rbr	dw	3f8h		;receiver buffer reg
thr	dw	3f8h		;transmitter holding reg
ier	dw	3f9h		;interrupt enable reg
iir	dw	3fah		;interrupt id reg
lcr_offset equ	(this byte) - pdefs	;for cm_setup hardware test
lcr	dw	3fbh		;line control reg
mcr	dw	3fch		;modem control reg
lsr	dw	3fdh		;line status reg
msr	dw	3feh		;modem status reg

intvecnum	db	0ch	;interrupt vector number
intvecaddr	dw	4*0ch	;absolute address of interrupt vector

intmask 	db	10h	;8259 interrupt mask
inteoi		db	64h	;8259 specific eoi for this line

pdefl	equ	(this byte) - pdefs

;saved 8250 regs (saved by cm_enable, restored by cm_restore
svier	db	?		;interrupt enable reg
svlcr	db	?		;line control reg
svmcr	db	?		;modem control reg
svdll	db	?		;baud rate divisor, least signif byte
svdlm	db	?		;baud rate divisor, most signif byte

sv8259	db	?		;saved 8259 interrupt mask
svinto	dw	?		;offset of old int handler
svints	dw	?		;segment of old int handler

inilcr	db	26		;initial lcr to use when enabling port
inibaud dw	384		;initial baud rate divisor
;------------------- end of current port definitions ----------------------

; definitions for port 1
p1def	equ	this byte
   dw	   3f8h 	;rbr		 receiver buffer reg
   dw	   3f8h 	;thr		 transmitter holding reg
   dw	   3f9h 	;ier		 interrupt enable reg
   dw	   3fah 	;iir		 interrupt id reg
   dw	   3fbh 	;lcr		 line control reg
   dw	   3fch 	;mcr		 modem control reg
   dw	   3fdh 	;lsr		 line status reg
   dw	   3feh 	;msr		 modem status reg
			;
   db	   0ch		;intvecnum	 interrupt vector number
   dw	   4*0ch	;intvecaddr	 absolute address of interrupt vector
			;
   db	   10h		;intmask	 8259 interrupt mask
   db	   64h		;inteoi 	 8259 specific eoi for this line

; definitions for port 2
p2def	equ	this byte
   dw	   2f8h 	;rbr		 receiver buffer reg
   dw	   2f8h 	;thr		 transmitter holding reg
   dw	   2f9h 	;ier		 interrupt enable reg
   dw	   2fah 	;iir		 interrupt id reg
   dw	   2fbh 	;lcr		 line control reg
   dw	   2fch 	;mcr		 modem control reg
   dw	   2fdh 	;lsr		 line status reg
   dw	   2feh 	;msr		 modem status reg
			;
   db	   0bh		;intvecnum	 interrupt vector number
   dw	   4*0bh	;intvecaddr	 absolute address of interrupt vector
			;
   db	   08h		;intmask	 8259 interrupt mask
   db	   63h		;inteoi 	 8259 specific eoi for this line

;------ equates for async registers
lsr_thre	equ	32	;transmitter holding register empty
msr_cd	equ	128		;carrier detect
msr_ring equ	64		;ring indicator
msr_dsr equ	32		;data set ready
msr_cts equ	16		;clear to send
msr_dcd equ	8		;delta carrier detect

mcr_dtr equ	1		;data terminal ready
mcr_rts equ	2		;request to send
mcr_out2 equ	8		;OUT2

lcr_dlab equ	80h		;divisor latch access bit

aflgs	db	0		;asynchronous card status flags
xoffsent	equ	1	;waiting for buffer to clear;xoff was sent
xonwait 	equ	2	;waiting for xon char
queue_xon	equ	4	;tell SENDIT to send xon chr asap
queue_xoff	equ	8	;tell SENDIT to send xoff chr asap

;	NOTE: buffer size must be power of two for queue algorithm to work
rdbuff	struc	;large buffer for receiving
	db	2048 dup	(?)
rdbuff	ends

rdbufmask dw	  07ffh 	  ;"and" mask for buffer pointer

rdhead	 dw	 0		 ;write pointer
rdtail	 dw	 0		 ;read pointer

readbuf rdbuff	<>

rdbufcnt dw	0		;count of chars currently in buffer
saved8	db	0		;saved value of lcr for temporary 8-bit mode

cm_data ends

cm_code segment  public 'code'
assume	cs:	cm_code
assume	ds:	cm_data

extrn	dly1000:near

;------ input & output: the 8250 is slow; using these calls insures nothing
;	important happens before it has time to react
input	proc	near
	in	al,dx
	ret
input	endp

output	proc	near
	out	dx,al
	ret
output	endp

;------ setup: select a port (cm_enable does the enabling)
;	new port num is in AL ( 1 or 2 )
;	set carry flag if port does not exist
cm_setup proc	 near
	push	ax
	push	bx
	push	cx
	push	dx
	push	di
	push	si
	push	es

	mov	bl,al			;save for "commport"
	push	ds
	pop	es
	mov	cx,pdefl		;data area length
	mov	di,offset pdefs 	       ;data area

	mov	msgnum,114
	mov	si,offset p1def
	cmp	al,1
	je	setmove

	mov	msgnum,115
	mov	si,offset p2def
	cmp	al,2
	je	setmove

	mov	msgnum,21		;internal error
	jmp	setx

setmove:
	mov	dx,[si+lcr_offset]	;check that hardware is there
	call	input
	xor	al,lcr_dlab		;switch dlab (harmless)
	call	output
	mov	ah,al			;save old
	push	ax
	pop	ax			;waste time
	call	input
	cmp	ah,al			;did bit stick?
	je	setm1
	mov	msgnum,11		;specified com adaptor not installed
	stc				;note error
	jmp	setx

setm1:	xor	al,lcr_dlab		;restore dlab
	call	output

setm2:	mov	commport,bl
	rep	movsb
	mov	bx,msgnum
	mov	cpmsg,bx
	clc				;no error
setx:
	pop	es
	pop	si
	pop	di
	pop	dx
	pop	cx
	pop	bx
	pop	ax
	ret
cm_setup endp


;------ setup everything for interrupt driven async comm
cm_enable	proc	near
	push	ax
	push	bx
	push	dx
	push	es
	push	si

;------ decouple board from system
	mov	dx,mcr		;modem ctrl reg
	call	input
	mov	svmcr,al
	and	al,255-mcr_out2 ;turn off OUT2
	call	output

;------ reset 8250
	mov	dx,ier		;intrpt enable reg
	call	input
	mov	svier,al
	sub	al,al
	call	output

;------ save additional 8250 regs/ set new ones
	mov	dx,lcr
	call	input
	mov	svlcr,al
	mov	al,inilcr

	or	al,80h		;set dlab
	call	output

	mov	bx,inibaud
	mov	dx,rbr		;low order divisor
	call	input
	mov	svdll,al

	mov	al,bl		;low order
	call	output

	mov	dx,ier		;high order divisor
	call	input
	mov	svdlm,al

	mov	al,bh		;high order
	call	output

	mov	dx,lcr		;lcr again
	call	input
	and	al,0ffh-80h	;clear dlab
	call	output

;------ enable data available and line status intrpts on 8250
	mov	dx,ier		;interrupt enable register
	mov	al,00000101b
	call	output		 ;set 8250 intrpt enable reg
	call	output		 ;second time for quirky 8250s

;------ read iir, msr, lsr, rbr to clear pending intrpts on 8250
	mov	dx,iir		;iir
	call	input
	mov	dx,lsr		;line status reg
	call	input
	mov	dx,msr		;modem status reg
	call	input
	mov	dx,rbr		;receiver buffer reg
	call	input

;------ mask irq3/4 intrpt (comm) in 8259
	in	al,21h
	mov	sv8259,al		;save for restore
	or	al,intmask
	out	21h,al

;------ save current interrupt handler
	mov	si,intvecaddr	     ;absolute address of intrpt handler
	sub	ax,ax
	mov	es,ax
	mov	ax,es:[si]	;get offset
	mov	svinto,ax
	mov	ax,es:2[si]	;get segment
	mov	svints,ax

;------ set interrupt vector
	mov	al,intvecnum
	mov	ah,25h
	mov	dx,offset cm_code:cm_int	;offset of interrupt handler
	mov	bx,cs				;segment of int handler
	push	ds
	mov	ds,bx
	int	21h				;dos call (set intrpt handler
	pop	ds

;------ initialize buffer pointers
	sub	ax,ax
	mov	rdhead,ax		 ;initialize write ptr
	mov	rdtail,ax		 ;initialize read ptr
	mov	rdbufcnt,0

;------ clear pending comm intrpts in 8259
	mov	al,inteoi	;specific eoi 8259 OCW2 command
	out	20h,al

;------ enable comm interrupts (irq3/4) on 8259
	in	al,21h		;get intrpt mask register
	mov	dl,intmask
	not	dl
	and	al,dl		;enable 3/4
	out	21h,al

;------ finally, set OUT2, dtr and rts on comm card to enable card
	mov	dx,mcr
	mov	al,mcr_out2+mcr_rts+mcr_dtr
	call	output

	pop	si
	pop	es
	pop	dx
	pop	bx
	pop	ax
	ret
cm_enable	endp

;------ comm interrupt handler
cm_int	proc	far
	push	ax
	push	bx
	push	ds
	push	dx
	push	si

	mov	ax,cm_data	;establish addressibility
	mov	ds,ax

	mov	dx,mcr
	call	input
	and	al,255-mcr_out2 ;turn off intrpt link
	call	output

	mov	dx,iir		;interrupt ident register
	call	input
	test	al,1		;interrupt pending?
	jz	int_top 	;yup
	jmp	int_unx 	;nope

;------ figure out what sort of interrupt we're handling
int_top:and	al,00000110b	;high order bits should be zero; clr to make sure
	cmp	al,4
	je	chrin		;received data available
	cmp	al,6
	je	lnstat		;line status

int_unx:
;	mov	msgnum,66	;unexpected intrpt (happens from time to time)
	mov	dx,msr		;clear all to make sure
	call	input		;should not be necessary, but something is wrong
	mov	dx,lsr
	call	input
	jmp	cominx

lnstat: mov	dx,lsr		;line status register
	call	input
	mov	msgnum,8
	test	al,16		;received break?
	jnz	cminx0
	mov	msgnum,13
	test	al,8		;framing error?
	jnz	cminx0
	mov	msgnum,12
	test	al,4		;parity error?
	jnz	cminx0
	mov	msgnum,14	;character overrun
	test	al,2		;overrun?
	jnz	cminx0
	mov	msgnum,21	;internal error #2 (async
cminx0: jmp	cominx


chrin:	mov	dx,rbr		;address of receive buffer reg
	call	input		;get char
	mov	si,rdhead
	mov	bx,offset readbuf
	mov	[si+bx],al	;write char into buffer

;	now check for received xon/xoff and set flag
	test	parmf,protxont	;do we care about xon/xoff?
	jz	chrx2		; no

	cmp	al,19		;xoff?
	jne	chrx1		;no
	or	aflgs,xonwait	;yes -- then wait for xon char
	jmp	chrx2

chrx1:	cmp	al,17		;xon?
	jne	chrx2		;no
	and	aflgs,255-xonwait	;no more xonwait

chrx2:	; now increment read buffer pointer to next position
	inc	si
	and	si,rdbufmask	;account for buffer wrap
	cmp	si,rdtail	 ;are we at read ptr?
	jne	chrx4
	mov	msgnum,10	;note buffer overflow
	jmp	cominx

chrx4:	mov	rdhead,si	;remember advanced head
	inc	rdbufcnt

;	check read buffer and make sure it doesn't overflow
	mov	ax,rdbufcnt	;check if buffer getting full
	cmp	ax, 3 * (type rdbuff)/4
	jb	cominx		;less than 3/4 full

	mov	msgnum,9	;"buffer nearly full"
	test	parmf,protxon	;xon protocol available?
	jz	cominx		;nope

	or	aflgs,xoffsent
	mov	msgnum,74		;buffer nearly full -- xoff sent

chrx5:	sti				;allow other interrupts here
	nop
	nop
	cli

	mov	dx,lsr			;get line status reg
	call	input
	test	al,lsr_thre		;transmitter ready?
	jz	chrx5			;wait for it

	mov	al,19
	mov	dx,thr			;send xoff
	call	output
	jmp	cominx


cominx: mov	dx,iir		;interrupt ident register
	call	input
	test	al,1		;interrupt pending?
	jnz	cominx3 	;nope

	sti
	nop			;allow other interrupts here
	nop
	cli

	jmp	int_top 	;yup

cominx3:mov	al,20h		;eoi
	out	20h,al

	mov	dx,mcr	       ;turn on board again
	call	input
	or	al,mcr_out2
	call	output

	pop	si
	pop	dx
	pop	ds
	pop	bx
	pop	ax
	iret			;return

cm_int	endp

;------ read char from comm buffer into al; set zf if no char available
;	note bx, si destroyed
cm_rd	proc	near

	cli				;run disabled
	cmp	rdbufcnt,0
	jz	comrx3			;exit if ptrs match
	mov	si,rdtail
	mov	bx,offset readbuf
	mov	al,[bx+si]		;get char
	inc	si
	and	si,rdbufmask
	mov	rdtail,si
	dec	rdbufcnt

comrdx: test	aflgs,xoffsent		;was buffer full?
	jz	comrx2
	mov	dx,rdbufcnt
	cmp	dx,(type rdbuff)/4	;is it now less than 1/4 full?
	jg	comrx2

	sti
	and	aflgs,255-xoffsent
	mov	msgnum,75		;buffer ok -- xon sent

	push	ax
comrd2: mov	dx,lsr			;get line status reg
	call	input
	test	al,lsr_thre		;transmitter ready?
	jz	comrd2			;no -- keep waiting
	mov	al,17			;send xon
	mov	dx,thr
	call	output
	pop	ax

comrx2: or	si,1			;clear zero flag (char available)
comrx3: sti				;return
	ret
cm_rd	endp

;------ send char in al down the line
;	this version does not use interrupt driven transmission

cm_send proc	near
	push	dx

	test	parmf,protxont		;are we obeying xon/xoff?
	jz	send0			;no
	test	aflgs,xonwait		;are we waiting for xon?
	jnz	a5			;yes -- then don't send anything

send0:	mov	dx,lsr			;get line status reg
	push	ax
	call	input
	test	al,lsr_thre		;transmitter really empty?
	pop	ax
	jz	send0			;no -- wait for it

				;send character
	mov	dx,thr		;transmit buf reg
	call	output

a5:	pop	dx
	ret
cm_send endp

;------ restore interrupt control vector
cm_restore	proc	near
	push	si
	push	dx
	push	ax

;------ zero OUT2 to decouple board from system
	mov	dx,mcr		;modem cntrl reg
	call	input
	and	al,255-mcr_out2 ;turn off OUT2
	call	output

;------ restore regs on 8250
	mov	al,0		;disable for a bit
	mov	dx,ier		;intrpt enable reg
	call	output

	mov	dx,lcr
	call	input
	or	al,lcr_dlab	;set dlab
	call	output

	mov	dx,rbr		;low order divisor
	mov	al,svdll
	call	output

	mov	dx,ier		;high order divisor
	mov	al,svdlm
	call	output

	mov	al,svlcr	;this (if it wasn't set) clears dlab
	mov	dx,lcr		;lcr again
	call	output

	mov	al,svier
	mov	dx,ier		;intrpt enable reg
	call	output
	call	output

;------ read iir, msr, lsr, rbr to clear pending intrpts on 8250
	mov	dx,iir		;iir
	call	input
	mov	dx,lsr		;line status reg
	call	input
	mov	dx,msr		;modem status reg
	call	input
	mov	dx,rbr		;receiver buffer reg
	call	input

;------ restore intrpt vector
	mov	al,intvecnum
	mov	ah,25h
	mov	dx,svinto	;get old offset
	mov	si,svints	;get old segment
	push	ds
	mov	ds,si
	int	21h		;dos set intrpt
	pop	ds

;------ restore IRQ3/4 mask in 8259
	mov	ah,sv8259	;original IMR mask
	and	ah,intmask	;select our bit

	in	al,21h		;get IMR
	or	al,ah
	out	21h,al

;------ restore MCR on 8250, which may have OUT2 on (e.g. recouple board-system)
	mov	al,svmcr
	or	al,mcr_dtr+mcr_rts	;we leave these on, regardless
	mov	dx,mcr
	call	output

	pop	ax
	pop	dx
	pop	si
	ret
cm_restore	endp

;------ signal a break
cm_break	proc near
	push	dx
	push	cx
	push	bx
	push	ax

	and	aflgs,255-xonwait	;clear xonwait

	mov	dx,lcr		;addr of line ctrl register
	call	input		;get contents
	or	al,01000000b	;set break on
	call	output

	mov	ax,250
	call	dly1000 	;wait 250 ms (approx

	mov	dx,lcr		;get line ctrl reg
	call	input		;get contents
	and	al,10111111b	;turn line break off
	call	output

	pop	ax
	pop	bx
	pop	cx
	pop	dx
	ret			;procedure return
cm_break	endp


cm_spar proc	near	;space parity
	push	ax
	mov	al,58
	call	cm_setpar
	pop	ax
	ret
cm_spar endp

cm_mpar proc	near	;mark parity
	push	ax
	mov	al,42
	call	cm_setpar
	pop	ax
	ret
cm_mpar endp

cm_epar proc	near	;even parity
	push	ax
	mov	al,26
	call	cm_setpar
	pop	ax
	ret
cm_epar endp

cm_opar proc	near	;odd parity
	push	ax
	mov	al,10
	call	cm_setpar
	pop	ax
	ret
cm_opar endp

cm_paroff	proc	near	;parity off
	push	ax
	mov	al,3
	call	cm_setpar
	pop	ax
	ret
cm_paroff	endp

;------ cm_setpar: set parity and data bits from value in al
;	AL    PARITY   DATA BITS
;	3	off	8
;	10	odd	7
;	26	even	7
;	42	mark	7
;	58	space	7

cm_setpar	proc	near
	push	ax
	push	bx
	push	dx

	mov	bl,al
	and	bl,00111011b	;strip all but parity and data size
	mov	dx,lcr		;line control register
	call	input
	and	al,11000100b	;leave all but parity and data size
	or	al,bl		;combine 'em
	call	output		 ;set it
	mov	inilcr,al	;save for subsequent cm_enable

	pop	dx
	pop	bx
	pop	ax
	ret
cm_setpar	endp

cm_8set proc	near		;switch to 8 data bits, saving current state
	push	ax
	push	dx

	mov	dx,lcr		;line control register
	call	input
	mov	saved8,al
	and	al,11000100b	;leave all but parity and data size
	or	al,3		;set 8 data bits, no parity
	call	output		 ;set it

	pop	dx
	pop	ax
	ret
cm_8set endp


cm_8restore proc near		;switch back to save parity state
	push	ax
	push	dx

	mov	dx,lcr		;line control register
	mov	al,saved8
	call	output		 ;set it

	pop	dx
	pop	ax
	ret
cm_8restore endp


cm_b110 proc	near
	push	ax
	mov	ax,1047
	call	cm_bset
	pop	ax
	ret
cm_b110 endp

cm_b150 proc	near
	push	ax
	mov	ax,768
	call	cm_bset
	pop	ax
	ret
cm_b150 endp

cm_b300 proc	near
	push	ax
	mov	ax,384
	call	cm_bset
	pop	ax
	ret
cm_b300 endp

cm_b600 proc	near
	push	ax
	mov	ax,192
	call	cm_bset
	pop	ax
	ret
cm_b600 endp

cm_b1200	proc	near
	push	ax
	mov	ax,96
	call	cm_bset
	pop	ax
	ret
cm_b1200	endp

cm_b2400	proc	near
	push	ax
	mov	ax,48
	call	cm_bset
	pop	ax
	ret
cm_b2400	endp

cm_b4800	proc	near
	push	ax
	mov	ax,24
	call	cm_bset
	pop	ax
	ret
cm_b4800	endp

cm_b9600	proc	near
	push	ax
	mov	ax,12
	call	cm_bset
	pop	ax
	ret
cm_b9600	endp

;------ cm_bset: set baud rate and stop bits from value in ax
;	ax contains divisor for clock; set 1 stop bit except for
;	divisor=1047, which is 110 baud which needs 2 stop bits
cm_bset proc	near
	push	ax
	push	bx
	push	dx

	mov	bx,ax
	mov	inibaud,ax	;save for cm_enable

	mov	dx,lcr		;line ctrl reg
	call	input
	or	al,80h		;set dlab
	and	al,0ffh-4	;set 1 stop bit
	cmp	bx,1047 	;110 baud?
	jne	bs1		; no
	or	al,4		;set 2 stop bits
bs1:	call	output

	mov	dx,rbr		;low order divisor
	mov	al,bl
	call	output

	mov	dx,ier		;high order divisor
	mov	al,bh
	call	output

	mov	dx,lcr		;lcr again
	call	input
	and	al,0ffh-80h	;clear dlab
	call	output
	mov	inilcr,al	;save for cm_enable

	pop	dx
	pop	cx
	pop	ax
	ret
cm_bset endp

;------ isxonw: clear zf if we're waiting for xon
isxonw	proc	near
	test	parmf,protxont		;are we listening for xon?
	jz	isx			;no
	test	aflgs,xonwait
isx:	ret
isxonw	endp


;------ isdsron: clear zf if data set ready is on
isdsron proc	 near
	push	ax
	push	dx

	mov	dx,msr
	call	input
	test	al,msr_dsr	      ;test dsr

	pop	dx
	pop	ax
	ret
isdsron endp


;------ ispar8: clear zf if 8-bit data path available
ispar8	proc	near
	push	ax
	push	dx

	mov	dx,lcr		;line control register
	call	input
	and	al,00111011b	;leave only parity and data size
	cmp	al,3		;is it 8 data bits, no parity?

	pop	dx
	pop	ax
	ret
ispar8	endp

;------ dtroff: turn off data terminal ready (and request to send)
;	then turn them back on
dtroff	proc	near
	push	ax
	push	cx
	push	dx

	mov	dx,mcr
	call	input
	and	al,255-00000011b	;turn off dtr and rts
	call	output

	sub	cx,cx
wait2:	loop	wait2		;wait 400 ms (approx
wait3:	loop	wait3

	mov	dx,mcr
	call	input
	or	al,00000011b	;turn on dtr and rts
	call	output

	pop	dx
	pop	cx
	pop	ax
	ret
dtroff	endp


;------ clrxonw: clear "waiting for xon" state
clrxonw proc	near
	and	aflgs,255-xonwait
	ret
clrxonw endp


;------ cm_cd: check carrier detect state, and set cf if offline
cm_cd	proc	near
	push	ax
	push	dx

	mov	dx,msr
	call	input

	test	al,msr_cd	;online?
	clc			; (assume true)
	jnz	cd2		;yup

	stc			;nope
cd2:
	pop	dx
	pop	ax
	ret
cm_cd	endp

;------ chk_cd: check carrier detect state change, and set msg if necessary
chk_cd	proc	near
	push	ax
	push	dx

	mov	dx,msr
	call	input

	mov	dx,15		;line connected msg
	test	al,msr_cd	;sdat true?
	jnz	chkcde		;yup
	mov	dx,16		;no -- line disconnected msg
	and	aflgs,255-xonwait	;don't wait anymore


chkcde: cmp	dx,lastcdmsg
	je	chkcdex 		;don't repeat msg
	mov	lastcdmsg,dx
	mov	msgnum,dx		;set msg

chkcdex:
	pop	dx
	pop	ax
	ret
chk_cd	endp

;------ cm_flush: get rid of chars in receive buffer
cm_flush  proc	  near
	push	ax
	cli
	mov	rdbufcnt,0
	mov	ax,rdhead
	mov	rdtail,ax
	sti
	pop	ax
	ret
cm_flush  endp

;------ cm_ring: if ring indicator, set CF
cm_ring proc	near
	push	ax
	push	dx

	mov	dx,msr
	call	input

	test	al,msr_ring	;ringing?
	jnz	ring1		;yup
	clc			;no ring
	jmp	ringx

ring1:	stc
ringx:
	pop	dx
	pop	ax
	ret
cm_ring endp

;------ isctsw: clear zf if waiting for clear to send
isctsw	proc	 near
	push	ax
	push	dx

	test	parm4,protrts		;cts/rts enabled?
	jz	ctsx			;no

	mov	dx,msr
	call	input
	and	al,msr_cts		;isolate cts bit
	xor	al,msr_cts		; zf if bit was on

ctsx:
	pop	dx
	pop	ax
	ret
isctsw	endp


;------ rtson: turn on data set ready	(if rts/cts enabled)
rtson	proc	near
	push	ax
	push	dx

	test	parm4,protrts
	jz	rtonx

	mov	dx,mcr
	call	input
	or	al,mcr_rts    ;turn on rts
	call	output

rtonx:	pop	dx
	pop	ax
	ret
rtson	endp

;------ rtsoff: turn off request-to-send (if rts/cts enabled)
rtsoff	proc	near
	push	ax
	push	dx

	test	parm4,protrts
	jz	rtofx

	mov	dx,mcr
	call	input
	and	al,255-mcr_rts	  ;turn off rts
	call	output
rtofx:
	pop	dx
	pop	ax
	ret
rtsoff	endp


cm_code ends
end
