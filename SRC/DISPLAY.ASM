	public	display
	public	wswitch

cm_data segment public 'code'

allocate = 0
include data.pub

window	struc
	id	db	0	;window id number
	tr	db	0	;top row
	lc	db	0	;left column
	br	db	23	;bottom row
	rc	db	79	;right column
	crsrow	db	0	;cursor row
	crscol	db	0	;cursor column
	scattr	db	7	;screen attribute
window	ends

wndc	equ	wndc_id


;save areas for non-active windows...
wnd1	window	<1>				;conversation display
wnd2	window	<2>				;unused
wnd3	window	<3,0,0,23,79,0,0,7>	  ;help screen
wnd4	window	<4,0,0,24,79,0,0,7>	  ;entire screen
wnd5	window	<5,24,45,24,79,0,0,7>	  ;msg line
wnd6	window	<6,24,0,24,44,0,0,7>	  ;command line

cntrlc	db	12	;clear
	db	10	;linefeed
	db	7	;bell
	db	13	;carriage return
	db	8	;backspace
	db	9	;tab
cntrle	db	?
cntlen	equ	cntrle-cntrlc	;length of control block

jmptab	dw	offset	u12	;12	;clear
	dw	offset	u10	;10	;linefeed
	dw	offset	u11	;7	;bell
	dw	offset	u13	;13	;carriage return
	dw	offset	u8	;8	;backspace
	dw	offset	u9	;9	;tab
jmptabe dw	?
jmplen	equ	jmptabe-jmptab		;length of control block

cm_data ends

cm_code segment  public 'code'
assume	cs:	cm_code
assume	ds:	cm_data

extrn	rdcrsr:near,setcrsr:near,wrtchar:near,scroll:near,sc_beep:near
extrn	getattr:near,setattr:near

;------ display: display char in window (no buffering)
display proc	near
	push	ax
	push	bx
	push	cx
	push	dx
	push	di
	push	si
	push	es


;------ check for cntrl chars...
	cmp	al,32				;else execute them
	jl	wcntrl

;------ write the char to the screen

writec: call	wrtchar

;------ get the current cursor position (into dx
	call	rdcrsr

;------ position the cursor for next char
	cmp	dl,wndc_rc	;test for col ovfl
	jz	wscrl		;cr-lf required
	inc	dl		;increment column pointer

wcset:	call	setcrsr 	;cursor set
	jmp	wret		;all done

;------ cr-lf required
wscrl:
	mov	dl,wndc_lc	;cursor at left hand of window
	cmp	dh,wndc_br	;are we at bottom?
	jz	wscrl2		;yup
	inc	dh		;no -- then increment row without scroll
	jmp	wcset		;...set cursor, and return

wscrl2:
	call	setcrsr 	;set cursor first

	mov	al,1		;scroll one line
	call	scroll
	jmp	wret


;------ execute cntrl character in al
wcntrl:

;------ get the current cursor position (into dx
	call	rdcrsr

	mov	cx,cntlen		;get length of character list
	mov	di,offset cntrlc	;and point to it
	push	ds
	pop	es
	repne	scasb
	jz	match
	jmp	writec		;char not found -- write rom char

match:	mov	si,cntlen	;get number of table entries
	sub	si,cx		;find offset of match
	dec	si
	sal	si,1		;make word offset
	mov	cx,offset jmptab	;get around assembler
	add	si,cx			;'offset' bug (hmh)
	mov	si,[si]
	jmp	si


;------ form feed (12) found -- clear entire window
u12:	sub	al,al
	call	scroll

;	move cursor home
	mov	dh,wndc_tr	;upper left corner
	mov	dl,wndc_lc
	jmp	cset		;set crsr

;------ backspace found
u8:	cmp	dl,wndc_lc	;are we at first pos?
	je	u81		;yup -- special treatment
	dec	dl
	jmp	u81c		;set cursor

u81:
	cmp	dh,wndc_tr	;are we on top line already?
	jne	u81b
	jmp	wret		;yes -- ignore backspace

u81b:	mov	dl,wndc_rc	;set cursor to right column
	dec	dh		;no -- move up one line
u81c:	call	setcrsr
;	push	ax
;	mov	al,32		;clear space
;	call	wrtchar
;	pop	ax
	jmp	wret

;------ cr found
u13:
	mov	dl,wndc_lc	;move to first col
	jmp	cset		;set crsr

;------ linefeed found
u10:
	cmp	dh,wndc_br	;bot of screen?
	je	u50		;yes -- scroll the screen
	inc	dh
	jmp	cset		;no -- just set cursr

u50:	mov	al,1		;scroll 1 line
	call	scroll
	jmp	wret

;------ bel found
u11:
	call	sc_beep
	jmp	wret


;------ tab
u9:	add	dl,8
	and	dl,11111000b
	cmp	dl,wndc_rc
	jle	cset

	cmp	dh,wndc_br
	jae	tbscrl
	mov	dl,wndc_lc
	inc	dh
	jmp	cset

tbscrl: mov	al,1			;scroll 1 line
	call	scroll
	mov	dl,wndc_lc		;left column
	jmp	cset

cset:	;set cursor (in dx)
	call	setcrsr

wret:
	pop	es
	pop	si
	pop	di
	pop	dx
	pop	cx
	pop	bx
	pop	ax
	ret			;procedure return
display endp

;------ wswitch: switch to window specified in al. save old window.
;	on exit, al = 0 iff all ok; al= 1 if window not found
wswitch proc	near
	push	bx
	push	cx
	push	dx
	push	di
	push	si
	push	es

	cmp	al,wndc_id
	jne	ws0
	jmp	ws5				;already have correct window

ws0:	;put cursor position into current blk
	call	rdcrsr
	mov	wndc_crsrow,dh
	mov	wndc_crscol,dl

	push	ds
	pop	es			;set up es for block moves

;	move current window back into its save block
	mov	bl,wndc_id		;get current block id
	call	wfind			;get address of save block into si
	or	si,si			;check for zero case
	jz	nogood			;bad window spec
	mov	di,si
	mov	si,offset wndc
	mov	cx,type window		;number of bytes in block
	rep	movsb			;move current window into save area

;	move new window into current block from save block
	mov	bl,al			;get new window id
	call	wfind			;get offset of new window into si
	or	si,si			;check for zero case
	jz	nogood			;bad window spec
	mov	di,offset wndc
	mov	cx,type window		;number of bytes in block
	rep	movsb

;	now set new screen cursor
	mov	dh,wndc_crsrow
	mov	dl,wndc_crscol
	call	setcrsr

	mov	al,wndc_attr		;set screen attribute
	call	setattr

ws5:	sub	al,al			;good return code
	jmp	wsex

nogood: mov	al,1			;window not found
wsex:	pop	es
	pop	si
	pop	di
	pop	dx
	pop	cx
	pop	bx
	ret
wswitch endp


;------ wfind: get address of window block
;	on entry, bl is block id; on exit si points to block
;	if si = 0 on exit, then id was unknown
wfind	proc near

	or	bl,bl
	jz	wsnotfnd

	mov	si,offset wnd1
	dec	bl
	jz	wsfnd

	mov	si,offset wnd2
	dec	bl
	jz	wsfnd

	mov	si,offset wnd3
	dec	bl
	jz	wsfnd

	mov	si,offset wnd4
	dec	bl
	jz	wsfnd

	mov	si,offset wnd5
	dec	bl
	jz	wsfnd

	mov	si,offset wnd6
	dec	bl
	jz	wsfnd

wsnotfnd:
	sub	si,si			;indicate unknown window spec
wsfnd:					;indicate window found
	ret
wfind	endp

cm_code ends
end
