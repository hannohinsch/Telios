	public	decode_emis

cm_data segment public 'code'

allocate = 0
include data.pub

emstate db	nostate
nostate equ	1
getfile equ	2
escstate equ	3

nameptr 	dw	0
filename	db	20 dup(?)

emflag	db	0		;local flags
gateway equ	1		;gateway active

bellcnt db	0

cm_data ends

cm_code segment public	'code'
assume	cs:cm_code
assume	ds:cm_data

extrn	cm_send:near,wrtclose:near,setupd:near,wrtsetup:near,nxchr:near
extrn	sc_beep:near

;------ check emis gateway sequences
;	char in al
;	on exit, clear zf iff char available
decode_emis proc near
	push	bx
	push	cx
	push	dx
	push	di
	push	si
	push	es

	push	ax
	and	al,not 128

	cmp	emstate,nostate
	jne	d1
	jmp	no_

d1:	cmp	emstate,escstate
	jne	d2
	jmp	esc_

d2:	cmp	emstate,getfile
	jne	d3
	jmp	get_

d3:
	mov	emstate,nostate 		;error condition
	jmp	yes_chr

;------
no_:	cmp	al,27		;esc?
	jne	no2
	mov	emstate,escstate
	jmp	no_chr

no2:	cmp	al,18		;dc2?
	jne	no3
	mov	emstate,getfile
	mov	nameptr,0
	jmp	no_chr

no3:	cmp	al,7
	jne	no4
	test	emflag,gateway
	jz	no4
	cmp	bellcnt,5	;allow only 5 bells during capture
	jae	no4

	mov	al,13		;send cr if bell during capture
	call	cm_send
	inc	bellcnt
	jmp	no_chr

no4:	jmp	yes_chr

;------
get_:
	mov	si,nameptr
	mov	filename[si],al
	inc	nameptr
	cmp	si,13			;14th char?
	je	get2			;go open file
	jmp	no_chr

get2:	mov	emstate,nostate
;	OPEN FILE HERE
	test	tflag,fcap		;is one already active?
	jz	com2a			;no
	call	wrtclose		;yes -- close it
	and	tflag,not fcap		;and switch off flag

com2a:	mov	camsg,54		;'no cap file' msg, changed by wrtsetup

;	save name of cap file for status display
	mov	si,nameptr
	mov	filename[si],0		;mark end of string
	lea	si,filename

	push	ds
	pop	es
	push	si
	mov	di,offset cfname
	sub	cx,cx
caplp:	call	nxchr			;get next char	(handles translations)
	or	al,al			;end of string if zero
	jz	caplp2
	stosb
	inc	cx
	jmp	caplp

caplp2: mov	cflen,cx		;store capfile name length
	pop	si

	call	wrtsetup		;set up new file (si points to name)
	or	al,al			;check rc
	jnz	cmcpx			;exit if not ok
	or	tflag,fcap		;indicate capture active
	or	emflag,gateway
	and	parmf,not capoff	;not toggled off
	call	setupd			;force status redisplay

	mov	al,13
	call	cm_send
	jmp	no_chr

cmcpx:
	mov	al,7
	jmp	yes_chr

;------
esc_:	mov	emstate,nostate

	cmp	al,5
	jne	e1
	jmp	prt2			;printer on

e1:	cmp	al,6
	jne	e2
	jmp	cap2		       ;printer and capfile off

e2:	cmp	al,7
	jne	e3
	call	sc_beep 		;beep
	jmp	no_chr

e3:	cmp	al,8			;beep--beep
	jne	e4
	call	sc_beep
	sub	cx,cx
e3a:	loop	e3a
	call	sc_beep
	jmp	no_chr

e4:	jmp	no_chr

;------
cap2:
	and	emflag,not gateway
;	CLOSE FILE HERE
	test	tflag,fcap		;is cap file open
	jnz	close1			;yes --
	jmp	close2			;no --

close1: call	wrtclose		;yes -- close it (resets msgnum, too
	and	tflag,not fcap		;and switch off flag
	mov	camsg,54		;'no cap file' msg
	call	setupd			;force update of status line

close2:
;	CLOSE PRT HERE
	test	parmf,prton
	jz	close3
	and	parmf,not prton
	mov	msgnum,61	;"printer stopped"
	mov	prmsg,61

close3: mov	bellcnt,0
	jmp	no_chr


;------
prt2:	; START PRT HERE
	or	emflag,gateway
	or	parmf,prton	; printer echo on
	mov	msgnum,60	;"printer started"
	mov	prmsg,60
	jmp	no_chr


;------ MUST exit through one of these two labels, so AX is popped
no_chr: pop	ax
	cmp	al,al
	jmp	emx

yes_chr: pop	ax
	mov	ah,fromc1
	or	ah,ah
emx:
	pop	es
	pop	si
	pop	di
	pop	dx
	pop	cx
	pop	bx
	ret
decode_emis endp

cm_code ends
end
