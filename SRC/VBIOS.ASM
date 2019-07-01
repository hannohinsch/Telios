;------ video bios interface routines

	public	rdcrsr
	public	setcrsr
	public	csettle
	public	crsron

	public	wrtchar
	public	rdchar

	public	scroll
	public	dscroll

	public	hilite
	public	nattr
	public	rvideo
	public	getattr
	public	setattr

	public	qwrite
	public	q80
	public	qwindow

	public	vid_init

;	public	veeol
;	public	veeop
;	public	vebol
;	public	vebop
;	public	veall


cm_data segment public 'code'

allocate = 0
include data.pub

crt_page	db	0	;hardware page number (c/g board only)
crt_cols	db	80
crt_crsr	dw	0	;current cursor position
regen_addr	dw	0
status_6845	dw	0
mode_6845	dw	0

crt_type	db	0
monochrome	equ	1	;monochrome adaptor in use
cursor_off	equ	2

qposition	dw	0

cm_data ends

cm_code segment public 'code'

assume	cs:cm_code
assume	ds:cm_data

;------ vid_init: initialize data fields for monochrome/graphics card
vid_init	proc	near
	push	ax
	push	bx

	mov	ah,15		;get current video state
	int	10h

	cmp	al,7
	je	mono

	mov	status_6845,03dah	;color/graphics card stsus reg
	mov	mode_6845,03d8h 	;mode select reg
	mov	regen_addr,0b800h	;regen buffer address

	and	crt_type,255-monochrome

	mov	ah,0		;set 25 by 80 color alpha mode
	mov	al,3
	int	10h

	mov	ah,11		;select pallette
	mov	bh,0		;border color id
	mov	bl,border_val	;get value
	int	10h		;video set

	jmp	vidx

mono:	mov	ax,03bah	;monochrome adaptor status reg
	mov	status_6845,ax
	mov	mode_6845,03b8h ;mode select reg
	mov	ax,0b000h	;regen buffer address
	mov	regen_addr,ax
	or	crt_type,monochrome

vidx:	pop	bx
	pop	ax
	ret
vid_init	endp


;------ getattr: return current attribute in al
getattr proc	near
	mov	al,wndc_attr
	ret
getattr endp

;------ setattr: set attribute from al
setattr proc	near
	mov	wndc_attr,al
	ret
setattr endp


;------ nattr: set normal character attribute
nattr	proc	near
	push	ax
	mov	al,bckgrnd_val
	shl	al,1
	shl	al,1
	shl	al,1
	shl	al,1
	add	al,nattr_val
	mov	wndc_attr,al
	pop	ax
	ret
nattr	endp

;------ hilite: set hilit attribute for future writes
hilite	proc	near
	push	ax
	mov	al,bckgrnd_val
	shl	al,1
	shl	al,1
	shl	al,1
	shl	al,1
	add	al,hilite_val
	mov	wndc_attr,al
	pop	ax
	ret
hilite	endp

;------ rvideo: set reverse video attribute for further writes
rvideo	proc	near
	push	ax
	mov	al,reverseb_val
	shl	al,1
	shl	al,1
	shl	al,1
	shl	al,1
	add	al,reverse_val
	mov	wndc_attr,al
	pop	ax
	ret
rvideo	endp

;------ rdcrsr: get surrent cursor position into dx
rdcrsr	proc	near
	mov	dx,crt_crsr
	ret
rdcrsr	endp


;------ setcrsr: set cursor to position in dx
setcrsr proc	near
	mov	crt_crsr,dx		;save cursor position
	ret
setcrsr endp

;------ csettle: set screen cursor to agree w/ crt_crsr
csettle proc	near
	push	ax
	push	bx
	push	dx

	mov	dx,crt_crsr		;get cursor position
	mov	bh,crt_page
	mov	ah,2			;cursor set subcode
	test	crt_type,cursor_off
	jz	crsron1
	mov	dx,0FFFFH		;waaay off screen
crsron1:int	10h

	pop	dx
	pop	bx
	pop	ax
	ret
csettle endp

;------ crsron: make cursor (in)visible
;	if al = 0, turn cursor off
crsron	proc	near

	and	crt_type,255-cursor_off ;assume on
	or	al,al
	jnz	crs1
	or	crt_type,cursor_off
crs1:

	ret
crsron	endp

;------ wrtchar: write char in al to screen using "current attribute"
wrtchar proc	near
	push	ax
	push	bx
	push	dx
	push	di
	push	es

	mov	ah,wndc_attr	 ;write with current attribute
	push	ax		;save character

	mov	dx,crt_crsr	;get cursor position into dx

	sub	ax,ax
	mov	al,dh		;rows into al
	mov	bl,crt_cols
	mul	bl		;times number of physical columns
	sub	dh,dh		;forget rows
	add	ax,dx		;add columns
	sal	ax,1		;times 2 for attribute bytes
	mov	di,ax

	mov	ax,regen_addr
	mov	es,ax		;point extra segment at regen buffer

	test	crt_type,monochrome	;if monochrome,
	jnz	wrtlp1			; then skip wait

	mov	dx,status_6845
wrtlp0: in	al,dx
	test	al,1		;wait for video on
	jnz	wrtlp0

	cli
wrtlpa: in	al,dx
	test	al,1		;wait for video off
	jz	wrtlpa

wrtlp1:
	pop	ax
	stosw
	sti

	pop	es
	pop	di
	pop	dx
	pop	bx
	pop	ax
	ret
wrtchar endp


;------ rdchar: read char into al, current attr into ah
rdchar	proc	near
	push	bx
	push	dx
	push	si

	mov	dx,crt_crsr	;get cursor position into dx

	sub	ax,ax
	mov	al,dh		;rows into al
	mov	bl,crt_cols
	mul	bl		;times number of physical columns
	sub	dh,dh		;forget rows
	add	ax,dx		;add columns
	sal	ax,1		;times 2 for attribute bytes
	mov	si,ax


	test	crt_type,monochrome	;if monochrome,
	jnz	rdlp1			; then skip wait

	mov	dx,status_6845
rdlp0:	in	al,dx
	test	al,1		;wait for video on
	jnz	rdlp0

	cli
rdlpa:	in	al,dx
	test	al,1		;wait for video off
	jz	rdlpa

rdlp1:	push	ds
	mov	ax,regen_addr
	mov	ds,ax		;point data segment at regen buffer
	lodsw
	pop	ds
	sti

	pop	si
	pop	dx
	pop	bx
	ret
rdchar	endp

;------ veeol: video erase to end of line
veeol	proc	near
	push	dx
	push	cx
	push	bx
	push	ax

	mov	bh,wndc_attr	 ;store current attribute in bh
	sub	al,al		;al = 0 means clear

	mov	dx,crt_crsr
	cmp	dl,wndc_rc
	jae	vex		;already at margin

	mov	ch,dh		;upper left corner
	mov	cl,dl
;	mov	dh,dh		;lower right corner
	mov	dl,wndc_rc
	mov	ah,6		;scroll up
	int	10h		;video call

vex:
	pop	ax
	pop	bx
	pop	cx
	pop	dx

	ret
veeol	endp


;------ vebol: video erase to beginning of line
vebol	proc	near
	push	dx
	push	cx
	push	bx
	push	ax

	mov	bh,wndc_attr	 ;store current attribute in bh
	sub	al,al		;al = 0 means clear

	mov	dx,crt_crsr
	cmp	dl,wndc_lc
	jle	vbex		;already at margin

	mov	ch,dh		;upper left corner
	mov	cl,wndc_lc
;	mov	dh,dh		;lower right corner
;	mov	dl,dl
	mov	ah,6		;scroll up
	int	10h		;video call

vbex:
	pop	ax
	pop	bx
	pop	cx
	pop	dx

	ret
vebol	endp

;------ veeop: video erase to end of page
veeop	proc	near
	push	dx
	push	cx
	push	bx
	push	ax

	call	veeol		;erase to end of line

	mov	bh,wndc_attr	 ;store current attribute in bh
	sub	al,al		;al = 0 means clear

	mov	dx,crt_crsr
	cmp	dh,wndc_br	;on bottom row?
	jb	op1
	jmp	opx		;we're already at bottom; don't clear any more

op1:	inc	dh
	mov	ch,dh		;upper left corner
	mov	cl,wndc_lc
	mov	dh,wndc_br	;lower right corner
	mov	dl,wndc_rc
	mov	ah,6		;scroll up
	int	10h		;video call

opx:
	pop	ax
	pop	bx
	pop	cx
	pop	dx
	ret
veeop	endp

;------ vebop: video erase to beginning of page
vebop	proc	near
	push	dx
	push	cx
	push	bx
	push	ax

	call	vebol		;erase to begin of line

	mov	bh,wndc_attr	 ;store current attribute in bh
	sub	al,al		;al = 0 means clear

	mov	dx,crt_crsr
	cmp	dh,wndc_tr	;on top row?
	ja	bop1
	jmp	bopx		;we're already at top; don't clear any more

bop1:	dec	dh
	mov	ch,wndc_tr	;upper left corner
	mov	cl,wndc_lc
;	mov	dh,dh		;lower right corner
	mov	dl,wndc_rc
	mov	ah,6		;scroll up
	int	10h		;video call

bopx:
	pop	ax
	pop	bx
	pop	cx
	pop	dx
	ret
vebop	endp

;------ veall: video erase whole screen
veall	proc	near
	push	ax

	sub	al,al
	call	scroll

	pop	ax
	ret
veall	endp


;------ scroll: scroll current window up <al> lines. al = 0 means clear window.
scroll	proc	near
	push	dx
	push	cx
	push	bx
	push	ax

	mov	bh,wndc_attr	 ;store current attribute in bh

	mov	ch,wndc_tr	;upper left corner
	mov	cl,wndc_lc
	mov	dh,wndc_br	;lower right corner
	mov	dl,wndc_rc
	mov	ah,6		;scroll up
	int	10h		;video call

	pop	ax
	pop	bx
	pop	cx
	pop	dx
	ret
scroll	endp


;------ dscroll: scroll current window down <al> lines. al = 0 means clear window.
dscroll proc	near
	push	dx
	push	cx
	push	bx
	push	ax

	mov	bh,wndc_attr	 ;store current attribute in bh
du3:
	mov	ch,wndc_tr	;upper left corner
	mov	cl,wndc_lc
	mov	dh,wndc_br	;lower right corner
	mov	dl,wndc_rc
	mov	ah,7		;scroll down
	int	10h		;video call

	pop	ax
	pop	bx
	pop	cx
	pop	dx
	ret
dscroll endp

;the Qwrite routine allows a very fast string write to the
; screen.  The routine	assume
;	-- si points to string (count word, characters) at entry
;	-- no cursor wrap
;	-- no scroll
;	-- <cr> moves cursor to column 0
;	-- tabs are set every 8 positions (same as DOS)
;	-- no control chars except cr,lf,tab,clr, and attr flags

qwrite	proc	near		;calculate first buffer position
	push	ax
	push	bx
	push	cx
	push	dx
	push	di
	push	si
	push	es

	call	nattr		;always start w/ normal attributes

	cld

;	calculate first qposition
	mov	dx,crt_crsr	;get cursor position into dx

	sub	ax,ax
	mov	al,dh		;rows into al
	mov	bl,crt_cols
	mul	bl		;times number of physical columns
	sub	dh,dh		;forget rows
	add	ax,dx		;add columns
	sal	ax,1		;times 2 for attribute bytes
	mov	di,ax		;di --> position in buffer

	mov	ax,regen_addr
	mov	es,ax		;es --> regen buffer

	mov	dx,crt_crsr	;dx = current cursor


	mov	cx,[si]
	add	si,2		;si --> current char

;	write char
	or	cx,cx
	jnz	qlod
	jmp	qwx		;nothing to do

qlod:	lodsb			;next char into al
	cmp	al,13		;ctrl char?
	jbe	qctrl

qchar:
	mov	ah,wndc_attr
	inc	dx		;increment cursor position

qlpb:	push	dx
	mov	bx,ax		;remember al still contains char

	test	crt_type,monochrome
	jnz	qlp1		;monochrome doesn't need wait

	mov	dx,status_6845
qlpa:	in	al,dx
	test	al,1		;wait for video on
	jnz	qlpa

	cli
qlp0:	in	al,dx
	test	al,1		;wait for video off
	jz	qlp0

qlp1:	mov	ax,bx		;recover char

	stosw			;write char

qlp2:	sti
	pop	dx		;recover cursor

qdix:	loop	qlod		;do next character
	jmp	qwx


qctrl:
	cmp	al,9		;do control chars
	je	tab
	cmp	al,10
	je	lf
	cmp	al,13
	je	cr
	cmp	al,nattrf
	je	qnat
	cmp	al,rvideof
	je	qrvid
	cmp	al,hilitef
	je	qhilite
	cmp	al,12
	je	qclr
	jmp	qchar		;not ctrl after all - go print it

cr:	sub	dl,dl			;column 0
	sub	ax,ax
	mov	al,dh		;rows into al
	mov	bl,crt_cols
	mul	bl		;times number of physical columns
	sal	ax,1		;times 2 for attribute bytes
	mov	di,ax
	jmp	qdix

lf:	add	di,160
	inc	dh		;move cursor
	jmp	qdix

tab:	add	dl,8
	and	dl,11111000b

	add	di,16
	and	di,0fff0h
	jmp	qdix

qnat:	call	nattr
	jmp	qdix

qrvid:	call	rvideo
	jmp	qdix

qhilite: call	hilite
	jmp	qdix

qclr:	mov	al,0
	call	scroll
	sub	di,di
	sub	dx,dx
	jmp	qdix


qwx:	call	setcrsr 	;finished

	pop	es
	pop	si
	pop	di
	pop	dx
	pop	cx
	pop	bx
	pop	ax
	ret
qwrite	endp

;------ q80: display 80 chars pointed to by ax (a segment)
;	display w/ attributes
q80	proc	near
	push	ax
	push	bx
	push	cx
	push	dx
	push	di
	push	si
	push	bp
	push	es
	push	ds

	cld

	mov	es,ax		;save segment register

;	calculate first qposition
	mov	dx,crt_crsr	;get cursor position into dx

	sub	ax,ax
	mov	al,dh		;rows into al
	mov	bl,crt_cols
	mul	bl		;times number of physical columns
	sal	ax,1		;times 2 for attribute bytes
	mov	di,ax		;di --> position in buffer

	mov	dx,status_6845

	mov	cx,80

	mov	bl,crt_type

	push	bx			;es has to point to regen
	mov	ax,regen_addr
	mov	bx,es

	assume	ds:nothing, es:nothing
	mov	es,ax
	mov	ds,bx
	pop	bx

	sub	si,si

q8lod:	lodsw			;get next
	mov	bp,ax		;save over in/out

	test	bl,monochrome
	jnz	q8lp1		;monochrome doesn't need wait

q8lpa:	in	al,dx
	test	al,1		;wait for video on
	jnz	q8lpa

	cli
q8lp0:	in	al,dx
	test	al,1		;wait for video off
	jz	q8lp0

q8lp1:	mov	ax,bp
	stosw			;write char

	sti
	loop	q8lod


	pop	ds
	pop	es
	pop	bp
	pop	si
	pop	di
	pop	dx
	pop	cx
	pop	bx
	pop	ax
	ret
	ret
q80	endp

assume	ds:cm_data

;------ qwindow: display window
;	ax = start of region 1
;	bx = stop 1
;	cx = start 2
;	dx = stop 2
;	if start = stop for region 2, then don't do it
qwindow proc	near
	push	ax
	push	bx
	push	cx
	push	dx
	push	di
	push	si
	push	bp
	push	es
	push	ds

	cld

	push	dx
	push	cx
	push	bx
	push	ax

;	calculate first qposition (set es:di)
	mov	dl,wndc_lc
	mov	dh,wndc_tr

	sub	ax,ax
	mov	al,dh		;rows into al
	mov	bl,crt_cols
	mul	bl		;times number of physical columns
	sal	ax,1		;times 2 for attribute bytes
	mov	di,ax		;di --> position in buffer

	mov	ax,regen_addr
	mov	es,ax

	pop	ax		;set up for first region
	pop	bx

	sub	bx,ax		;difference in paragraphs
	shl	bx,1
	shl	bx,1
	shl	bx,1		;difference in words
	mov	cx,bx

	call	qwrsub

	pop	ax		;second region
	pop	bx

	cmp	ax,bx		;nothing to do
	je	qwinx

	sub	bx,ax		;difference in paragraphs
	shl	bx,1
	shl	bx,1
	shl	bx,1		;difference in words
	mov	cx,bx

	call	qwrsub

qwinx:
	pop	ds
	pop	es
	pop	bp
	pop	si
	pop	di
	pop	dx
	pop	cx
	pop	bx
	pop	ax
	ret
	ret
qwindow endp


;------ write cx words from ax:si to es:di
;	note REGISTER SLAUGHTER
qwrsub	proc	near
	push	ds

	test	crt_type,monochrome
	jz	qwlod

	assume	ds:nothing, es:nothing
	mov	ds,ax
	sub	si,si

	rep	movsw		;monochrome does not need wait
	jmp	qwrex		;all done

qwlod:
	assume	ds:cm_data
	push	ax

	mov	dx,status_6845	;wait for vertical retrace
qwlod2: in	al,dx
	test	al,8
	jnz	qwlod2

	mov	dx,mode_6845
	mov	al,25h		;disable video
	out	dx,al

	assume	ds:nothing, es:nothing
	pop	ds
	sub	si,si

	rep	movsw		;move text

	mov	al,8+1+32	;video on -- 80x25 -- blink enable
	out	dx,al

qwrex:	pop	ds
	ret
qwrsub	endp

cm_code ends
end
