;	TI emulation

	public	decode_931

cm_data segment public	'code'

allocate = 0
include data.pub

esc	equ	27

crt_tr	equ	0
crt_lc	equ	0
crt_br	equ	23
crt_rc	equ	79

state	db	exp_esc
exp_esc equ	1
exp_lead equ	2
exp_parm equ	3

;  states related to TI parsing string sequences:
tistate db	tis_st0
tis_st0 equ	0			;not working w/ string
tis_st1 equ	1			;string start (lead
tis_st2 equ	2			;string start (esc
tis_st3 equ	3			;string start ('('
tis_st4 equ	4			;string chars (wait for esc
tis_st5 equ	5			;string end, looking for ')'


; parameter tables for TI emulation
parm_cnt	dw	0
parm_inx	dw	0
parm_tab	db	10 dup (0)
parm_go 	dw	0

; terminal state
titerm	db	0
crwrap	equ	1		;cursor wrap
bellon	equ	2		;ring bell on ctrl-g
grphon	equ	4		;graphics character set
crmode	equ	8		;cursor not blinking
edmode	equ	16		;character editing extent enable

ti_attr db	0		;screen attribute  (ti style)

fill_chr db	32		;fill char
fill_attr db	0		; (ti style)

ceb_rr	db	23		;char editing boundary (row)
ceb_cc	db	79		;char editing boundary (col)

leb_rr	db	23		;line editing boundary (row)

stat_string	dw	stat_stringz - this byte	;response to 36h
		db	01h,1bh,28h,40h,40h,40h,40h,42h
		db	40h,40h,40h,40h,40h,40h,40h,40h
		db	1bh,29h
stat_stringz	equ	this byte

cm_data ends

cm_code segment public 'code'
assume	cs:cm_code
assume	ds:cm_data

extrn	cm_send:near
extrn	wrdcrsr:near,wsetcrsr:near
extrn	beall:near,beeol:near,beeop:near
extrn	bpscroll:near,bscroll:near,bdscroll:near
extrn	nattr:near,getattr:near,setattr:near
extrn	bwrtattr:near,wrtbuf:near,brdchr:near
extrn	dpage:near,wcrsron:near,chrinsert:near,chrdelete:near

;------ emulate a TI 931 terminal
;	set zf if char available
decode_931 proc near
	push	bx
	push	cx
	push	dx
	push	si
	push	ax

	and	al,7fh			;strip parity bit

	cmp	state,exp_esc
	jne	slead
	jmp	t9esc

slead:	cmp	state,exp_lead
	jne	sparm
	jmp	t9lead

sparm:	cmp	state,exp_parm
	jne	t9esc
	jmp	t9parm

t9esc:	cmp	al,esc
	je	start_seq
	jmp	tixa			;normal char

start_seq:
	mov	state,exp_lead
	mov	parm_cnt,0
	mov	parm_inx,0
	jmp	tix			;no char

t9parm:
	cmp	tistate,tis_st0 	;are we processing string?
	jne	t9strng 		;yes -- go do it
	mov	si,parm_inx
	mov	byte ptr parm_tab[si],al
	inc	si
	cmp	si,parm_cnt		;do we have all parms?
	jb	t9parm2 		;no
	mov	si,parm_go		;execute stored routine
	call	si
	mov	state,exp_esc
	jmp	tix

t9parm2:
	mov	parm_inx,si
	jmp	tix

;	string processing
t9strng:
;	(we ignore all strings in this version)
	cmp	tistate,tis_st1 	;expecting lead
	jne	t9s1
	mov	tistate,tis_st2
	jmp	tix

t9s1:	cmp	tistate,tis_st2 	;expecting start esc
	jne	t9s2
	mov	tistate,tis_st3
	jmp	tix

t9s2:	cmp	tistate,tis_st3 	;expecting start (
	jne	t9s3
	mov	tistate,tis_st4
	jmp	tix

t9s3:	cmp	tistate,tis_st4 	; string (expecting final esc)
	jne	t9s4
	cmp	al,esc
	je	t9s3a
	jmp	tix

t9s3a:	mov	tistate,tis_st5
	jmp	tix

t9s4:	cmp	tistate,tis_st5 	;expecting final )
	mov	tistate,tis_st0 	;all done
	mov	state,exp_esc
	jmp	tix


t9lead:
	cmp	al,021h 		;fill chr and attr
	jne	t9d2
	mov	parm_go,offset ti_21
	mov	parm_cnt,2
	jmp	t9lpx

t9d2:	cmp	al,022h 		;chr editing boundary
	jne	t9d3
	mov	parm_go,offset ti_22
	mov	parm_cnt,2
	jmp	t9lpx

t9d3:	cmp	al,023h 		;line editing boundary
	jne	t9d4
	mov	parm_go,offset ti_23
	mov	parm_cnt,1
	jmp	t9lpx

t9d4:	cmp	al,024h 		;en/disable chr editing
	jne	t9d5
	mov	parm_go,offset ti_24
	mov	parm_cnt,1
	jmp	t9lpx

t9d5:	cmp	al,025h 		;rep attr to addr
	jne	t9d6
	mov	parm_go,offset ti_25
	mov	parm_cnt,3
	jmp	t9lpx

t9d6:	cmp	al,034h 		;set attr
	jne	t9d7
	mov	parm_go,offset ti_34
	mov	parm_cnt,1
	jmp	t9lpx

t9d7:	cmp	al,036h 		;read status
	jne	t9d8
	call	ti_36
	jmp	t9lex

t9d8:	cmp	al,039h 		;set control	(nop)
	jne	t9d9
	mov	parm_go,offset ti_null
	mov	parm_cnt,3
	jmp	t9lpx

t9d9:	cmp	al,03eh 		;clr to address
	jne	t9d10
	mov	parm_go,offset ti_3e
	mov	parm_cnt,2
	jmp	t9lpx

t9d10:	cmp	al,03fh 		;repeat to address
	jne	t9d11
	mov	parm_go,offset ti_3f
	mov	parm_cnt,3
	jmp	t9lpx

t9d11:	cmp	al,040h 		;read to address
	jne	t9d12
	mov	parm_go,offset ti_40
	mov	parm_cnt,2
	jmp	t9lpx

t9d12:	cmp	al,041h 		;cursor up
	jne	t9d13
	call	ti_41
	jmp	t9lex

t9d13:	cmp	al,042h 		;cursor down
	jne	t9d14
	call	ti_42
	jmp	t9lex

t9d14:	cmp	al,043h 		;crsr right
	jne	t9d15
	call	ti_43
	jmp	t9lex

t9d15:	cmp	al,044h 		;chr editing boundary
	jne	t9d16
	call	ti_44
	jmp	t9lex

t9d16:	cmp	al,046h 		;start transparent print
	jne	t9d17
	mov	tistate,tis_st1
	jmp	t9lpx

t9d17:	cmp	al,047h 		;string sequences
	jne	t9d18
	mov	tistate,tis_st1
	jmp	t9lpx

t9d18:	cmp	al,048h 		;cursor home
	jne	t9d19
	call	ti_48
	jmp	t9lex

t9d19:	cmp	al,049h 		;eeol
	jne	t9d20
	call	ti_49
	jmp	t9lex

t9d20:	cmp	al,04ah 		;eeop
	jne	t9d21
	call	ti_4a
	jmp	t9lex

t9d21:	cmp	al,04ch 		;clr screen
	jne	t9d22
	call	ti_4c
	jmp	t9lex

t9d22:	cmp	al,04dh 		;cursor on
	jne	t9d23
	call	ti_4d
	jmp	t9lex

t9d23:	cmp	al,04eh 		;insert line
	jne	t9d24
	call	ti_4e
	jmp	t9lex

t9d24:	cmp	al,04fh 		;delete line
	jne	t9d25
	call	ti_4f
	jmp	t9lex

t9d25:	cmp	al,050h 		;insert char
	jne	t9d26
	call	ti_50
	jmp	t9lex

t9d26:	cmp	al,051h 		;delete character
	jne	t9d27
	call	ti_51
	jmp	t9lex

t9d27:	cmp	al,052h 		;crsr off
	jne	t9d28
	call	ti_52
	jmp	t9lex

t9d28:	cmp	al,056h 		;set crsr mode
	jne	t9d29
	mov	parm_go,offset ti_56
	mov	parm_cnt,1
	jmp	t9lpx

t9d29:	cmp	al,058h 		;position cursor
	jne	t9d30
t9d29a:
	mov	parm_go,offset ti_58
	mov	parm_cnt,2
	jmp	t9lpx

t9d30:	cmp	al,059h 		;position cursor
	jne	t9d31
	jmp	t9d29a

t9d31:	cmp	al,061h 		;scroll up one
	jne	t9d32
	call	ti_61
	jmp	t9lex

t9d32:	cmp	al,062h 		;scroll down one
	jne	t9d33
	call	ti_62
	jmp	t9lex

t9d33:	cmp	al,06ah 		;rep attr n times
	jne	t9d34
	mov	parm_go,offset ti_6a
	mov	parm_cnt,2
	jmp	t9lpx

t9d34:	cmp	al,06bh 		;rep char n times
	jne	t9d35
	mov	parm_go,offset ti_6b
	mov	parm_cnt,2
	jmp	t9lpx

t9d35:	cmp	al,070h 		;80 col mode (clr scrn
	jne	t9d36
	call	ti_4c
	jmp	t9lex

t9d36:	cmp	al,078h 		;move box
	jne	t9d37
	mov	parm_go,offset ti_78
	mov	parm_cnt,4
	jmp	t9lpx

t9d37:	cmp	al,079h 		;enable graphics
	jne	t9d38
	mov	parm_go,offset ti_79
	mov	parm_cnt,1
	jmp	t9lpx

t9d38:	cmp	al,07bh 		;attr 'or'
	jne	t9d39
	mov	parm_go,offset ti_7b
	mov	parm_cnt,1
	jmp	t9lpx

t9d39:	cmp	al,07dh 		;attr 'and'
	jne	t9d40
	mov	parm_go,offset ti_7d
	mov	parm_cnt,1
	jmp	t9lpx

t9d40:

t9lex:	mov	state,exp_esc
	jmp	tix

t9lpx:	mov	state,exp_parm
	jmp	tix

tixa:	pop	ax			;restore char
	mov	ah,fromc1		;char available
	or	ah,ah
	jmp	tix2

tix:	pop	ax			;restore char
	cmp	al,al			;no char available
tix2:
	pop	si
	pop	dx
	pop	cx
	pop	bx
	ret
decode_931 endp

;------ ti_null:
ti_null proc	near
	ret
ti_null endp

;------ ti_21: select fill char and attr
ti_21	proc	near
	mov	al,parm_tab[0]
	mov	fill_chr,al
	mov	al,parm_tab[1]
	mov	fill_attr,al
	ret
ti_21	endp

;------ ti_22: select char editing boundary
ti_22	proc	near
	mov	al,parm_tab[0]
	sub	al,20h				;bias
	mov	ceb_rr,al
	mov	al,parm_tab[1]
	sub	al,20h				;bias
	mov	ceb_cc,al
	ret
ti_22	endp

;------ ti_23: select line editing boundary
ti_23	proc	near
	mov	al,parm_tab[0]
	sub	al,20h				;bias
	mov	leb_rr,al
	ret
ti_23	endp

;------ ti_24: enable/disable char editing boundary
ti_24	proc	near
	mov	al,parm_tab[0]
	and	titerm,255-edmode	;disable
	cmp	al,30h
	je	ti_24x
	or	titerm,edmode
	cmp	al,31h
	je	ti_24x
	; unrecognized parm, but who cares
ti_24x:
	ret
ti_24	endp

;------ ti_25: rep attr to address
ti_25	proc	near

	mov	ah,parm_tab[0]		;attr
	call	cnv_attr

	mov	ch,parm_tab[1]		;row
	sub	ch,20h
	mov	cl,parm_tab[2]		;col
	sub	cl,20h

	call	wrdcrsr 		;crsr into dx
	push	dx

lp25:	call	bwrtattr
	mov	bx,dx
	call	inc_crsr		;inc and set crsr
	cmp	bx,dx
	je	t25x			;must have hit end
	cmp	dx,cx
	jbe	lp25

t25x:	pop	dx
	call	wsetcrsr

	call	dpage
	ret
ti_25	endp

;------ ti_34: set attr
ti_34	proc	near
	mov	ah,parm_tab[0]
	mov	ti_attr,ah
	call	cnv_attr
	mov	al,ah		;*j# parameter screwup
	call	setattr
	ret
ti_34	endp

;------ ti_36: read status
ti_36	proc	near
	push	cx
	push	si

	mov	cx,stat_string
	lea	si,stat_string
	add	si,2			;skip over length
ti_36lp:
	lodsb
	call	cm_send
	loop	ti_36lp

	pop	si
	pop	cx
	ret
ti_36	endp

;------ ti_3e: clear to address
ti_3e	proc	near

	mov	ch,parm_tab[0]		;row
	sub	ch,20h
	mov	cl,parm_tab[1]		;col
	sub	cl,20h

	call	wrdcrsr 		;crsr into dx
	push	dx

	call	getattr
	mov	ah,al
	mov	al,' '                  ;fill w/blank

lp3e:	call	wrtbuf
	mov	bx,dx
	call	inc_crsr		;inc and set crsr
	cmp	bx,dx
	je	t3ex			;must have hit end
	cmp	dx,cx
	jbe	lp3e

t3ex:	pop	dx
	call	wsetcrsr
	call	dpage
	ret
ti_3e	endp

;------ ti_3f: repeat to address
ti_3f	proc	near

	mov	ch,parm_tab[1]		;row
	sub	ch,20h
	mov	cl,parm_tab[2]		;col
	sub	cl,20h

	call	wrdcrsr 		;crsr into dx
	push	dx

	call	getattr
	mov	ah,al
	mov	al,parm_tab[0]		;char

lp3f:	call	wrtbuf
	mov	bx,dx
	call	inc_crsr		;inc and set crsr
	cmp	bx,dx
	je	t3fx			;must have hit end
	cmp	dx,cx
	jbe	lp3f

t3fx:	pop	dx
	call	wsetcrsr
	call	dpage
	ret
ti_3f	endp

;------ ti_40: read to address
ti_40	proc	near

	mov	ch,parm_tab[0]		;row
	sub	ch,20h
	mov	cl,parm_tab[1]		;col
	sub	cl,20h

	call	wrdcrsr 		;crsr into dx
	push	dx

lp40:	call	brdchr			;read into al
	call	cm_send 		;send it

	mov	bx,dx
	call	inc_crsr		;inc and set crsr
	cmp	bx,dx
	je	t40x			;must have hit end
	cmp	dx,cx
	jbe	lp40

t40x:	pop	dx
	call	wsetcrsr
	ret
ti_40	endp

;------ ti_41: cursor up
;	**** adjust for wrap flag
ti_41	proc	near
	call	wrdcrsr
	cmp	dh,crt_tr
	jne	ti_41a
	mov	dh,crt_br
	jmp	ti_41x

ti_41a: dec	dh
ti_41x:
	call	wsetcrsr
	ret
ti_41	endp

;------ ti_42: cursor down
;	**** adjust for wrap flag
ti_42	proc	near
	call	wrdcrsr
	cmp	dh,crt_br
	jne	ti_42a
	mov	dh,crt_tr
	jmp	ti_42x

ti_42a: inc	dh
ti_42x:
	call	wsetcrsr
	ret
ti_42	endp

;------ ti_43: cursor right
;	***** adjust for wrap flag
ti_43	proc	near
	call	wrdcrsr
	cmp	dl,crt_rc
	jne	ti_43a
	mov	dl,crt_lc		;first col

	cmp	dh,crt_br		;inc row number
	jne	ti_43c
	mov	dh,crt_tr
	jmp	ti_43d

ti_43c: inc	dh
ti_43d: jmp	ti_43x

ti_43a: inc	dl
ti_43x:
	call	wsetcrsr
	ret
ti_43	endp

;------ ti_44: cursor left
;	**** adjust for wrap flag
ti_44	proc	near
	call	wrdcrsr
	cmp	dl,crt_lc
	jne	ti_44a
	mov	dl,crt_rc		;wrap up one line

	cmp	dh,crt_tr		;dec row number
	jne	ti_41b
	mov	dh,crt_br
	jmp	ti_41c

ti_41b: dec	dh
ti_41c: jmp	ti_44x

ti_44a: dec	dl
ti_44x:
	call	wsetcrsr
	ret
ti_44	endp

;------ ti_46: start transparent print
ti_46	proc	near
	ret
ti_46	endp

;------ ti_47: define options
ti_47	proc	near
	ret
ti_47	endp

;------ ti_48: cursor home
ti_48	proc	near
	mov	dh,crt_tr
	mov	dl,crt_lc
	call	wsetcrsr
	ret
ti_48	endp

;------ ti_49: erase to end of line
ti_49	proc	near
	call	beeol
	ret
ti_49	endp

;------ ti_4a: erase to end of screen
ti_4a	proc	near
	call	beeop
	ret
ti_4a	endp

;------ ti_4c: clear screen
ti_4c	proc	near
	call	beall
	sub	dx,dx
	call	wsetcrsr
	ret
ti_4c	endp

;------ ti_4d: cursor on
ti_4d	proc	near
	mov	al,1
	call	wcrsron
	ret
ti_4d	endp

;------ ti_4e: insert line
ti_4e	proc	near
	call	wrdcrsr
	mov	bh,dh
	mov	bl,leb_rr

	mov	al,1
	call	bpscroll
	ret
ti_4e	endp

;------ ti_4f: delete line
ti_4f	proc	near
	call	wrdcrsr
	mov	bh,dh
	mov	bl,leb_rr

	mov	al,0
	call	bpscroll
	ret
ti_4f	endp

;------ ti_50: insert character
ti_50	proc	near
	mov	ah,fill_attr
	call	cnv_attr
	mov	al,fill_chr

	call	wrdcrsr
	mov	cx,dx			;current row,col

	mov	dl,crt_rc		;assume no editing extent
	test	titerm,edmode
	jz	t50a
	mov	dh,ceb_rr		;use editing extent
	mov	dl,ceb_cc

t50a:	call	chrinsert
	call	dpage
	ret
ti_50	endp

;------ ti_51: delete character
ti_51	proc	near
	mov	ah,fill_attr
	call	cnv_attr
	mov	al,fill_chr

	call	wrdcrsr
	mov	cx,dx			;current row,col

	mov	dl,crt_rc		;assume no editing extent
	test	titerm,edmode
	jz	t51a
	mov	dh,ceb_rr		;use editing extent
	mov	dl,ceb_cc

t51a:	call	chrdelete
	call	dpage
	ret
ti_51	endp

;------ ti_52: cursor off
ti_52	proc	near
	sub	al,al
	call	wcrsron
	ret
ti_52	endp

;------ ti_56: set cursor mode (nop)
ti_56	proc	near
	ret
ti_56	endp

;------ ti_58: position cursor
ti_58	proc	near
	mov	dh,parm_tab[0]
	sub	dh,20h
	mov	dl,parm_tab[1]
	sub	dl,20h
	call	wsetcrsr
	ret
ti_58	endp

;------ ti_61: scroll up one
ti_61	proc	near
	mov	bh,crt_tr
	mov	bl,crt_br

	mov	al,0
	call	bpscroll
	ret
ti_61	endp

;------ ti_62: scroll down one
ti_62	proc	near
	mov	bh,crt_tr
	mov	bl,crt_br

	mov	al,1
	call	bpscroll
	ret
ti_62	endp

;------ ti_6a: repeat attr n times
ti_6a	proc	near

	mov	cl,parm_tab[1]		;count
	sub	cl,1fh			;bias
	sub	ch,ch

	call	wrdcrsr 		;crsr into dx
	push	dx

	mov	ah,parm_tab[0]		;attr
	call	cnv_attr

lp6a:	call	bwrtattr		;write attr
	call	inc_crsr		;inc and set crsr
	loop	lp6a

	pop	dx
	call	wsetcrsr
	call	dpage
	ret
ti_6a	endp

;------ ti_6b: repeat char n times
ti_6b	proc	near

	mov	cl,parm_tab[1]		;count
	sub	cl,1fh			;bias
	sub	ch,ch

	call	wrdcrsr 		;crsr into dx
	push	dx

	call	getattr
	mov	ah,al
	mov	al,parm_tab[0]		;char

lp6b:	call	wrtbuf
	call	inc_crsr		;inc and set crsr
	loop	lp6b

	pop	dx
	call	wsetcrsr
	call	dpage
	ret
ti_6b	endp

;------ ti_78: move box (not implemented)
ti_78	proc	near
	ret
ti_78	endp

;------ ti_79: enable graphics (not implemented)
ti_79	proc	near
	ret
ti_79	endp

;------ ti_7b: attribute or
ti_7b	proc	near
	mov	ah,ti_attr
	or	ah,parm_tab[0]
	mov	ti_attr,ah
	call	cnv_attr
	mov	al,ah
	call	setattr
	ret
ti_7b	endp

;------ ti_7d: attribute and
ti_7d	proc	near
	mov	ah,ti_attr
	and	ah,parm_tab[0]
	mov	ti_attr,ah
	call	cnv_attr
	mov	al,ah
	call	setattr
	ret
ti_7d	endp

;------ cnv_attr: take ti attr in ah and return equivalent telios attr
;
;	ti	pc
; blink 16	128
; dark	8	0
; undln 4	not implemented
; inv	2	(switch foreground,background)
; hili	1	8
cnv_attr proc	near
	push	bx
	push	cx
	push	dx

	call	getattr
	mov	dl,al		;save current attr

	call	nattr		;set normal attribute
	call	getattr 	; and get it into al

	test	ah,8		;dark?
	jz	cn1
	and	al,11111000b
	jmp	cn4

cn1:	test	ah,16		;blink?
	jz	cn2
	or	al,128

cn2:	test	ah,1		;hilite?
	jz	cn3
	or	al,8

cn3:	test	ah,2		;inverse?
	jz	cn4
	mov	cl,al
	and	cl,00000111b
	shl	cl,1
	shl	cl,1
	shl	cl,1
	shl	cl,1

	mov	ch,al
	and	ch,01110000b
	shr	ch,1
	shr	ch,1
	shr	ch,1
	shr	ch,1
	shr	ch,1

	and	al,10001000b
	or	al,ch
	or	al,cl

cn4:	push	ax
	mov	al,dl			;restore old attr
	call	setattr
	pop	ax			;get back converted attr (in al)

	mov	ah,al
	pop	dx
	pop	cx
	pop	bx
	ret
cnv_attr endp

;------ inc_crsr: advance cursor one position
;	cursor value in dx, both before and after call
inc_crsr proc	near
	inc	dl
	cmp	dl,crt_rc
	jbe	icx
	mov	dl,crt_lc
	inc	dh
	cmp	dh,crt_br
	jbe	icx
	mov	dh,crt_tr
icx:	call	wsetcrsr
	ret
inc_crsr endp

cm_code ends
end
