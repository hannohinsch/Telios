;------ keyboard and pf-key string handler
;	(C) Copyright 1982  Hanno Hinsch

	public	rdkeyb
	public	define
	public	startpfk
	public	dstring
	public	putstring


cm_data segment public 'code'

allocate = 0
include data.pub

	xptr	dw	0		;pointer to next char to send (xmit
	pfknum	db	0		;number of pf key being sent

pfdeftab	db	255 dup(0)	;ring indicator
		db	255 dup(0)		;string (XSTR
		db	'^H',0,252 dup(0)       ;backspace key
		db	'^M',0,252 dup(0)       ;enter key
		db	255 dup(0)		;pf 3...
		db	255 dup(0)		;pf 4
		db	255 dup(0)
		db	255 dup(0)		;pfk 6
		db	255 dup(0)
		db	255 dup(0)		;pf 8
		db	255 dup(0)
		db	255 dup(0)		;pf 10
		db	255 dup(0)		;answerback
		db	'AT DT',0,249 dup(0)    ;dial prefix
		db	'^M',0,252 dup(0)       ;dial suffix
		db	255 dup(0)		;tel number
		db	255 dup(0)		;pf 1
		db	255 dup(0)		;pf 2
		db	255 dup(0)		;send prefix
		db	255 dup(0)		;send suffix
		db	255 dup(0)		;disconnect
		db	255 dup(0)		;connect
		db	255 dup(0)		;character error
		db	255 dup(0)		;command error
		db	255 dup(0)		;timeout
		db	255 dup(0)		;received break
		db	255 dup(0)		;protocol transfer abort
		db	255 dup(0)		;shift f-1
		db	255 dup(0)		;shift f-2
		db	255 dup(0)		;shift f-3
		db	255 dup(0)		;shift f-4
		db	255 dup(0)		;shift f-5
		db	255 dup(0)		;shift f-6
		db	255 dup(0)		;shift f-7
		db	255 dup(0)		;shift f-8
		db	255 dup(0)		;shift f-9
		db	255 dup(0)		;shift f-10

b255	db	255

cm_data ends

cm_code segment  public 'code'

assume	cs: cm_code
assume	ds: cm_data

extrn	kbread:near
extrn	display:near
extrn	isxonw:near
extrn	setupd:near
extrn	dopanic:near
extrn	unseq:near
extrn	cm_send:near


;------ rdkeyb: read char from keyboard
;	if no char, set zf.  char goes into al, ah gets source name
;	pf keys are decoded, others fromk or fromf1
;	certain keys cause immediate action, no result
;	xstr not sent if lwait,tdelay, or xonw
rdkeyb	proc	near
	push	dx

	test	parm3,ptrans+kblock
	jnz	rdkchk				;definite no-no
	test	cmdflg,doact
	jz	rdktop				;no file-- ok
	test	parm4,qinact			;qinput also ok
	jnz	rdktop
	test	tflag,xmita			;also allow dial, xstring
	jnz	kbr1

rdkchk: jmp	rdkxmod 	;protocol state (and keybd lock) are different

rdktop:
	call	kbread		;get keyboard character into al
	jnz	kbr2		;go process

	test	tflag,xmita	;get chr from string?
	jnz	kbr1		;yes
	jmp	rdkx		;no -- nothing available

kbr1:
	call	nxmit		;get the char
				; origin (ah) set by nxmit
	jz	nxmoff		;none available
	cmp	ah,frompfk	;fake pf key?
	je	rdk1		;process
	jmp	rdkx		;exit if normal (fake fromf1 or fromk

nxmoff: and	tflag,255-xmita ;turn off string sending flag
	cmp	ah,ah		;set zf (no char
	jmp	rdkx

kbr2:	cmp	al,0		;extended ascii char?
	je	rdk0		;yes -- value in ah
	cmp	ax,1c0dh	;enter key?
	jne	kbr3
	test	parm2,cmndm	;command mode?
	jnz	kbr4		;yes -- no string substitution
	mov	al,dpfent
	call	startpfk
	jmp	rdktop

kbr3:	cmp	ax,0e08h	;backspace?
	jne	kbr4
	test	parm2,cmndm	;command mode?
	jnz	kbr4		;yes -- no string substitution
	mov	al,dpfbs
	call	startpfk
	jmp	rdktop

kbr4:	mov	ah,fromk
	or	ah,ah		;clear zf (chr available
	jmp	rdkx

rdk0:	mov	al,ah		;get extended char
rdk1:

	cmp	al,3		;null?
	jne	rdk4
	mov	ah,fromk
	mov	al,0		;make it normal null
	or	ah,ah		;clr flag
	jmp	rdkx

rdk4:	cmp	al,59		;pf1?
	jne	rdk4a
	mov	al,dpf1
	call	startpfk
	jmp	rdktop

rdk4a:	cmp	al,60		;pf2?
	jne	rdk4b
	mov	al,dpf2
	call	startpfk
	jmp	rdktop

rdk4b:	cmp	al,61		;pf3?
	jne	rdk5		;nope --
	mov	al,dpf3
	call	startpfk
	jmp	rdktop

rdk5:	cmp	al,62		;pf4?
	jne	rdk6		;nope --
	mov	al,dpf4
	call	startpfk
	jmp	rdktop

rdk6:

rdk7:	cmp	al,63		;pf5?
	jne	rdk8
	mov	al,dpf5
	call	startpfk
	jmp	rdktop

rdk8:	cmp	al,64		;pf6?
	jne	rdk9
	mov	al,dpf6
	call	startpfk
	jmp	rdktop

rdk9:	cmp	al,65		;pf7?
	jne	rdk10
	mov	al,dpf7
	call	startpfk
	jmp	rdktop

rdk10:	cmp	al,66		;pf8?
	jne	rdk11
	mov	al,dpf8
	call	startpfk
	jmp	rdktop

rdk11:	cmp	al,67		;pf9?
	jne	rdk12
	mov	al,dpf9
	call	startpfk
	jmp	rdktop

rdk12:	cmp	al,68		;pf10?
	jne	rdk12a
	mov	al,dpf10
	call	startpfk
	jmp	rdktop

rdk12a: cmp	al,84		;s1
	jne	rdk12b
	mov	al,dpfs1
	call	startpfk
	jmp	rdktop

rdk12b: cmp	al,85		;s2
	jne	rdk12c
	mov	al,dpfs2
	call	startpfk
	jmp	rdktop

rdk12c: cmp	al,86		;s3
	jne	rdk12d
	mov	al,dpfs3
	call	startpfk
	jmp	rdktop

rdk12d:  cmp	 al,87		 ;s4
	jne	rdk12e
	mov	al,dpfs4
	call	startpfk
	jmp	rdktop

rdk12e:  cmp	 al,88		 ;s5
	jne	rdk12f
	mov	al,dpfs5
	call	startpfk
	jmp	rdktop

rdk12f:  cmp	 al,89		 ;s6
	jne	rdk12g
	mov	al,dpfs6
	call	startpfk
	jmp	rdktop

rdk12g:  cmp	 al,90		 ;s7
	jne	rdk12h
	mov	al,dpfs7
	call	startpfk
	jmp	rdktop

rdk12h:  cmp	 al,91		 ;s8
	jne	rdk12i
	mov	al,dpfs8
	call	startpfk
	jmp	rdktop

rdk12i:  cmp	 al,92		 ;s9
	jne	rdk12j
	mov	al,dpfs9
	call	startpfk
	jmp	rdktop

rdk12j:  cmp	 al,93		 ;s10?
	jne	rdk13
	mov	al,dpfs10
	call	startpfk
	jmp	rdktop

rdk13:

rdk16:	cmp	al,25		;alt-p
	jne	rdk17
	call	dopanic
	cmp	al,al
	jmp	rdkx

rdk17:	jmp	rdkpx

;	if protocol flag is set, we ignore everything except alt-P
;	same goes for keyboard lock state
;	and active command file ('cept if doing qinput)
rdkxmod:
	call	kbread		;get keyboard character into al
	jz	rdkx2		;none there

	mov	msgnum,96	;"Press alt-P to stop transfer"
	test	parm3,ptrans	;protocol transfer?
	jnz	rdkx3
	mov	msgnum,116	;kblock msg
	test	parm3,kblock	;locked keyboard?
	jnz	rdkx3		;no

	mov	msgnum,147	;assume cmnd file active, "press alt-p..."

rdkx3:	cmp	ax,1900h	;alt-p ?
	jne	rdkx2
	call	dopanic    ;clears protocol and kbd flag and resets msgnum
rdkx2:	cmp	al,al
	jmp	rdkx

rdkpx:	mov	ah,frompfk	;mark extended char
	or	ah,ah		;clear zf
rdkx:	pop	dx
	ret
rdkeyb	endp

;------ define: define pf key. number in al, si point to string
;	string delimited by cntrl char
define	proc	near
	push	ax
	push	cx
	push	di
	push	es
	push	si

;	address proper position in string table (al has index
	mul	b255
	mov	di,ax
	mov	ax,offset pfdeftab
	add	di,ax
	push	ds
	pop	es
	mov	cx,254		;max 255 chars in string (one for end marker

;	move string to table
deflp:	lodsb
	stosb
	cmp	al,32
	jb	deflp2
	loop	deflp

deflp2: sub	al,al
	stosb			;end marker

	pop	si
	pop	es
	pop	di
	pop	cx
	pop	ax
	ret
define	endp

;------ nxmit: return next chr in string for rdkeyb;
;	some cause immediate action
;	set zf if none available
nxmit	proc	near
	push	si

nxtop:	mov	si,xptr

;	get next char
	mov	al,[si]
	inc	xptr
;	if overrun, exit
	cmp	al,32		;end of string marked by cntrl chr
	jb	nxov

	cmp	al,'^'          ;escape (^) chr?
	je	nxtesc		;yes
	jmp	nxm1		;normal kb char

nxtesc: inc	xptr
	inc	si
	mov	al,[si] 	;get next char
;	if overrun, exit
	cmp	al,32		;end of string marked by cntrl chr
	jb	nxov

nxp2:	cmp	al,'1'
	jne	nxp3
	mov	al,46		;just like alt-c
	mov	ah,frompfk
	jmp	nxm3		;and return

nxp3:	cmp	al,'9'          ;immediate lf? (for ipsa)
	jne	nxp4
	push	ax
	mov	al,10
	call	cm_send
	pop	ax
	jmp	nxtop		;and get next char...

nxp4:	call	unseq		;decode char
	jc	nxp7		;not found
	jmp	nxm1

nxp7:	jmp	nxtop		;ignore unknown ^ char

nxov:	cmp	pfknum,dpfpr	;was that end of prefix?
	jne	nxov1
	mov	al,dpfnum
	call	startpfk	;yes-- then start sending number
	jmp	nxtop

nxov1:	cmp	pfknum,dpfnum	;was it end of number?
	jne	nxov2
	mov	al,dpfsuf
	call	startpfk	;yes -- then send suffix
	jmp	nxtop

nxov2:	and	parm2,255-diala ;no longer executing dial string
	mov	xptr,0
	cmp	al,al		;none available (cntrl chrs mark end of string
	jmp	nxex		;exit

nxm1:	mov	ah,fromk	;assume like from keyboard
	cmp	pfknum,dpfx	;are we sending xstring?
	je	nxm2
	test	parm2,diala	;dialing?
	jz	nxm3		;no
nxm2:	mov	ah,fromf1	;yes -- it's like from file
nxm3:	or	ah,ah		;clear zf

nxex:	pop	si
	ret
nxmit	endp

;------ startpfk: start sending pf key contents (number in al
startpfk	proc	near
	push	ax
	push	bx

	mov	pfknum,al		;remember which pf key

;	find offset of pf key string
	mul	b255
	mov	bx,offset pfdeftab
	add	ax,bx
	mov	xptr,ax 		;store start addr of pf key

	or	tflag,xmita		;flag indicates active pf key
	pop	bx
	pop	ax
	ret
startpfk	endp

;------ dstring: display contents of string, al contains number
dstring proc	near
	push	ax
	push	si

;	find offset of pf key string
	mul	b255
	mov	si,offset pfdeftab
	add	si,ax

dslp:	mov	al,[si]
	inc	si
	cmp	al,32
	jb	dsex
	call	display
	jmp	dslp

dsex:
	pop	si
	pop	ax
	ret
dstring endp


;------ putstring: put contents of string, al contains number
;	bx contains address of 'put' routine to use
putstring	proc	near
	push	ax
	push	si

;	find offset of pf key string
	mul	b255
	mov	si,offset pfdeftab
	add	si,ax

pdslp:	mov	al,[si]
	inc	si
	cmp	al,32
	jb	pdsex
	call	bx
	jmp	pdslp

pdsex:
	pop	si
	pop	ax
	ret
putstring	endp

cm_code ends
end

