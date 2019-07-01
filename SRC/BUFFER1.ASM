;------ write chars and control codes to main window
;	Copyright (c) 1984 Hanno Hinsch

	public	window

	public	wrtbuf
	public	bwrtattr
	public	brdchr

	public	clrbuf

	public	beeop
	public	beeol
	public	bebop
	public	bebol
	public	beall

	public	wsetcrsr
	public	wrdcrsr
	public	wcsettle
	public	wcrsron
;	public	wrapmode		;current kludge conflict

	public	bdscroll
	public	bscroll
	public	bpscroll

	public	chrinsert
	public	chrdelete

cm_data segment  public 'code'

allocate = 0
include data.pub
include buffer.pub

crt_cols	db	80
crt_rows	db	25

vcrsr	dw	0			;virtual cursor

crt_tr	equ	0
crt_lc	equ	0
crt_rc	equ	79
crt_br	equ	23

crt_ctrl	db	0	;control flag byte
	lnwrap	equ	1	;on if last char caused line wrap
	insert	equ	2	;on if in insert mode
	scrollf equ	4	;on if this call caused a scroll
	trans	equ	8	;on if 'transparent' mode, i.e. no ctrl chrs
	nowrap	equ	16	;on if 'no-wrap' mode (for display of last chr
	nocrsr	equ	32	;don't show cursor
	noscroll equ	64	;don't scroll on 24-80 line wrap

tmpflag 	db	0
visible 	equ	1	;current line is in window (used by bscroll)


cntrlc	db	12	;clear
	db	10	;linefeed
	db	7	;bell
	db	13	;carriage return
	db	8	;backspace
cntrle	db	?
cntlen	equ	cntrle-cntrlc	;length of control block

jmptab	dw	offset	u12	;12	;clear
	dw	offset	u10	;10	;linefeed
	dw	offset	u11	;7	;bell
	dw	offset	u13	;13	;carriage return
	dw	offset	u8	;8	;backspace
jmptabe dw	?
jmplen	equ	jmptabe-jmptab		;length of control block

windf	db	0			;local flags
	swrap	equ	1		;screen wrapped on last char

cm_data ends

cm_buffer segment public 'zzz'          ;defined globally
cm_buffer	ends

cm_code segment  public 'code'
assume	cs:	cm_code
assume	ds:	cm_data

extrn	filter:near,wswitch:near,getattr:near,dpage:near
extrn	rdcrsr:near,setcrsr:near,wrtchar:near,sc_beep:near
extrn	csettle:near,crsron:near,bufwindow:near

;------ window: display character in current window
window	proc	near
	push	ax

	call	filter		;endow problem chars w/ 'kill' attribute

	test	ah,kill+frompfk+fromctl
	jz	wind0
	jmp	windx

wind0:	test	ah,fromc1+fromt1	;always display
	jnz	wind6

;	assertion: character is fromk or fromf1
wind1:	test	parmf,hecho	;is host echo on?
	jz	wind6		;no -- we display
	jmp	windx

wind6:	push	ax					;***** PUSH AX ******
	test	parmf,prton
	jz	wind6a
	call	lptecho 	;possibly print it
wind6a:

;	don't display cr-lf after screen wrap
	cmp	al,' '
	jae	wind6b
	test	parm3,graph
	jnz	wind6b

	test	windf,swrap	;did we just wrap?
	jz	wind7		;no
	cmp	al,13
	je	wind9		;ignore cr
	cmp	al,10
	je	wind9		;ignore lf
	cmp	al,7		;bel gets "printed" but doesn't clear flag
	je	wind7
wind6b: and	windf,255-swrap ;clear wrap flag on all forward spacing chars

wind7:
	cmp	al,9		;special treatment for tabs
	jne	wind7a
	call	mvtab		;do settable tab
	jmp	wind9

wind7a:
	call	tdisplay
	or	al,al
	jz	wind9

	test	al,2		;did we wrap (rc=2)
	jz	wind9
	or	windf,swrap	;remember wrap
wind9:	pop	ax					;****** POP AX ******

	cmp	al,13		;was that cr?
	jne	windx		;no
	mov	al,10		;get a lf
	cmp	ah,fromt1	;display from file?
	je	windx		;then autolf doesn't matter
	test	parm3,graph	;graphics mode?
	jnz	windx		;no autolf, then
	test	parmf,autolf	;do we need to add lf?
	jnz	wind6		;yes we do

windx:	pop	ax
	ret
window	endp


;------ screen output: write character and handle scrolling, wrapping, etc.
;	character to be written is in al
;	on exit, al = 0 if no scroll occurred, 1 if screen scrolled up
;	2 if we wrapped, 3 if we wrapped and scrolled

;	the tdisplay routine is called only by the WINDOW routine
tdisplay	proc	near
	push	bx
	push	cx
	push	dx
	push	di
	push	si
	push	es

	and	crt_ctrl,255-(trans+nowrap+noscroll)
	test	parm3,graph
	jz	tdisp1
	or	crt_ctrl,trans

tdisp1: cmp	termtype,ansi	;vt100? 	**KLUDGE**
	jne	tdisp2		;		(this oughta be thru WRAPMODE)
	test	tkstate,decaw	;nowrap?
	jz	tdisp2
	or	crt_ctrl,nowrap ;yes -- so don't wrap
tdisp2:
	cmp	termtype,ti931		; *** KLUDGE ***
	jne	tdisp3
	or	crt_ctrl,noscroll	;scroll always off
tdisp3:

	and	crt_ctrl,255-(lnwrap+scrollf)	;clear line-wrap + scroll flags

;------ check for cntrl chars...
	test	crt_ctrl,trans			;transparent mode?
	jnz	writec				;yes
	cmp	al,32				;else execute them
	jl	wcntrl

;------ write the char to the screen

writec: call	writethru

;------ get the current cursor position (into dx
	mov	dx,vcrsr

;------ position the cursor for next char
	cmp	dl,crt_rc      ;test for col ovfl
	jz	wscrl		;cr-lf required
	inc	dl		;increment column pointer

wcset:	call	wsetcrsr	 ;cursor set
	jmp	wret		;all done

;------ cr-lf required
wscrl:
	test	crt_ctrl,nowrap ;line wrap not wanted?
	jz	wscrl1		;wrap ok
	jmp	wret		;nope -- leave cursor alone

wscrl1: or	crt_ctrl,lnwrap ;note the line wrap
	mov	dl,crt_lc      ;cursor at left hand of window
	cmp	dh,crt_br      ;are we at bottom?
	jz	wscrl2		;yup
	inc	dh		;no -- then increment row without scroll
	jmp	wcset		;...set cursor, and return

wscrl2:
	test	crt_ctrl,noscroll	;scroll or wrap?
	jz	wscrl3			; go scroll
	mov	dh,crt_tr	 ;(wrap) we were at last pos; move to first
	call	wsetcrsr
	jmp	wret

wscrl3: call	wsetcrsr	 ;set cursor first
	mov	al,1		 ;scroll one line
	call	bscroll
	or	crt_ctrl,scrollf	;note it
	jmp	wret


;------ execute cntrl character in al
wcntrl:

;------ get the current cursor position (into dx
	mov	dx,vcrsr

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
u12:
	call	beall

;	move cursor home
	mov	dh,crt_tr      ;upper left corner
	mov	dl,crt_lc
	jmp	cset		;set crsr

;------ backspace found
u8:	cmp	dl,crt_lc      ;are we at first pos?
	je	u81		;yup -- special treatment
	dec	dl
	jmp	u81c		;set cursor

u81:
	cmp	dh,crt_tr      ;are we on top line already?
	jne	u81b
	jmp	wret		;yes -- ignore backspace

u81b:	mov	dl,crt_rc      ;set cursor to right column
	dec	dh		;no -- move up one line
u81c:	call	wsetcrsr
;	push	ax
;	mov	al,32		;clear space
;	call	writethru
;	pop	ax
	jmp	wret

;------ cr found
u13:
	mov	dl,crt_lc	;move to first col
	jmp	cset		;set crsr

;------ linefeed found
u10:
	cmp	dh,crt_br	;bot of screen?
	je	u50		;yes -- scroll the screen
	inc	dh
	jmp	cset		;no -- just set cursr

u50:
	call	bscroll
	or	crt_ctrl,scrollf	;note it
	jmp	wret

;------ bel found
u11:
	call	sc_beep
	jmp	wret


cset:	;set cursor (in dx)
	call	wsetcrsr

wret:	sub	ax,ax
	test	crt_ctrl,scrollf+lnwrap
	jz	wretx

	test	crt_ctrl,scrollf
	jz	wret1			;no scroll occurred
	add	al,1
wret1:	test	crt_ctrl,lnwrap 	;line wrap?
	jz	wretx
	add	al,2
wretx:
	pop	es
	pop	si
	pop	di
	pop	dx
	pop	cx
	pop	bx
	ret
tdisplay	endp

;------ writethru: write char in al to buffer, and screen if necessary
writethru proc	near
	push	bx
	push	dx

	call	wrtbuf

;	now check to see if we should write thru to screen

	call	pgdif
	cmp	dx,-1
	je	wrx
	call	setcrsr
	call	wrtchar
wrx:
	pop	dx
	pop	bx
	ret
writethru endp

;------ wrtbuf: write char in al into buffer at current cursor
wrtbuf	proc	near
	push	ax
	push	bx
	push	cx
	push	dx
	push	es

	mov	cl,al			;save char

	mov	dx,vcrsr		;get cursor into dx
	mov	al,dh			;rows
	sub	al,crt_tr		;window relative
	mul	parlnb			;# of paragraphs (in ax)
	add	ax,pageptr
	cmp	ax,bufend		;past buffer?
	jb	st3			;yes --
	sub	ax,bufend
	add	ax,bufstart
st3:	mov	es,ax

	sub	bx,bx
	mov	bl,dl			;cols
	sal	bl,1			;shift for attributes

	call	getattr
	mov	ch,al
	mov	es:[bx],cx		;write char/attr into buffer

	pop	es
	pop	dx
	pop	cx
	pop	bx
	pop	ax
	ret
wrtbuf	endp

;------ bwrtattr: write attr in ah into buffer at current cursor
bwrtattr  proc	  near
	push	ax
	push	bx
	push	cx
	push	dx
	push	es

	mov	ch,ah			;save attr

	mov	dx,vcrsr		;get cursor into dx
	mov	al,dh			;rows
	sub	al,crt_tr		;window relative
	mul	parlnb			;# of paragraphs (in ax)
	add	ax,pageptr
	cmp	ax,bufend		;past buffer?
	jb	bw3			;yes --
	sub	ax,bufend
	add	ax,bufstart
bw3:	mov	es,ax

	sub	bx,bx
	mov	bl,dl			;cols
	sal	bl,1			;shift for attributes

	mov	es:[bx+1],ch		;write attr into buffer

	pop	es
	pop	dx
	pop	cx
	pop	bx
	pop	ax
	ret
bwrtattr  endp

;------ brdchr: read char at current cursor into al
brdchr	proc	near
	push	bx
	push	cx
	push	dx
	push	es

	mov	dx,vcrsr		;get cursor into dx
	mov	al,dh			;rows
	sub	al,crt_tr		;window relative
	mul	parlnb			;# of paragraphs (in ax)
	add	ax,pageptr
	cmp	ax,bufend		;past buffer?
	jb	br3			;yes --
	sub	ax,bufend
	add	ax,bufstart
br3:	mov	es,ax

	sub	bx,bx
	mov	bl,dl			;cols
	sal	bl,1			;shift for attributes

	mov	ax,es:[bx]		;read char/attr into buffer

	pop	es
	pop	dx
	pop	cx
	pop	bx
	ret
brdchr	endp


;------ mvtab: move to next tab stop, using global tabarray
mvtab	proc	near
	sub	bx,bx
	mov	dx,vcrsr
mvlp:	cmp	dl,crt_rc
	jae	mvs			;don't tab past right margin
	inc	dl
	mov	bl,dl
	cmp	tabarray[bx],1
	jne	mvlp			;didn't find tab stop -- look at next

mvs:	call	wsetcrsr
	ret
mvtab	endp

;------ lptecho: echo char in al to lpt1 if printer flag is on
;	change this to use file function (so crit errors are caught)
lptecho proc	near
	push	ax
	push	dx
	test	parmf,prton
	jz	lptx
	mov	dl,al
	mov	ah,5		;printer call
	int	21h		;dos int
lptx:	pop	dx
	pop	ax
	ret
lptecho endp

;------ clrbuf: clear chr buffer
clrbuf	proc	near
	push	ax
	push	bx
	push	dx

	mov	bl,wndc_id
	mov	al,1
	call	wswitch 	;switch to main window

	mov	ax,cm_buffer
	mov	scrnptr,ax
	mov	homeptr,ax
	mov	bufstart,ax
	mov	pageptr,ax

	call	bufwindow	;set endptr

	mov	dh,crt_tr      ;move cursor home
	mov	dl,crt_lc
	call	wsetcrsr

	call	beall
	call	dpage

	mov	al,bl
	call	wswitch 	;restore old window

	pop	dx
	pop	bx
	pop	ax
	ret
clrbuf	endp


;------ bclear: subroutine to clear window in buffer (current screen)
;	ch,cl = top left corner
;	dh,dl = bottom right corner
bclear	proc	near
	push	ax
	push	bx
	push	cx
	push	dx
	push	di
	push	es

	mov	al,ch			;top row to clear
	mul	parlnb
	add	ax,pageptr		;point to first row

	cmp	ax,bufend		;past buffer?
	jb	bc3			;no  --
	sub	ax,bufend
	add	ax,bufstart
bc3:	mov	es,ax			;point to first line

	sub	bx,bx
	mov	bl,cl			;first col
	add	bx,bx			;correct for attribute

	sub	dh,ch			;make dh = number of rows
	inc	dh
	sub	dl,cl			;make dl = number of cols
	inc	dl

	sub	cx,cx
	mov	cl,dh			;save number of rows in cx

	sub	dh,dh			;make dx (dl) = number of cols

bclp:	call	getattr
	mov	ah,al
	mov	al,' '

	push	cx
	mov	cx,dx			;get line length
	mov	di,bx			;point to first column
	cld
	rep	stosw			;write to es:di
	pop	cx

	mov	ax,es
	add	ax,parln		;point to next line
	cmp	ax,bufend
	jne	bc2
	mov	ax,bufstart
bc2:	mov	es,ax

	loop	bclp

bcx:	call	dpage

	pop	es
	pop	di
	pop	dx
	pop	cx
	pop	bx
	pop	ax
	ret
bclear	endp

;------ beeol: buffer erase to end of line
beeol	proc	near
	push	dx
	push	cx

	mov	dx,vcrsr
	cmp	dl,crt_rc
	jae	vex		;already at margin

	mov	ch,dh		;upper left corner
	mov	cl,dl
;	mov	dh,dh		;lower right corner
	mov	dl,crt_rc
	call	bclear

vex:
	pop	cx
	pop	dx
	ret
beeol	endp


;------ bebol: buffer erase to beginning of line
bebol	proc	near
	push	dx
	push	cx

	mov	dx,vcrsr
	cmp	dl,crt_lc
	jle	vbex		;already at margin

	mov	ch,dh		;upper left corner
	mov	cl,crt_lc
;	mov	dh,dh		;lower right corner
;	mov	dl,dl
	call	bclear

vbex:
	pop	cx
	pop	dx
	ret
bebol	endp


;------ beeop: buffer erase to end of page
beeop	proc	near
	push	dx
	push	cx

	call	beeol		;erase to end of line

	mov	dx,vcrsr
	cmp	dh,crt_br      ;on bottom row?
	jb	op1
	jmp	opx		;we're already at bottom; don't clear any more

op1:	inc	dh
	mov	ch,dh		;upper left corner
	mov	cl,crt_lc
	mov	dh,crt_br      ;lower right corner
	mov	dl,crt_rc
	call	bclear

opx:
	pop	cx
	pop	dx
	ret
beeop	endp


;------ bebop: buffer erase to beginning of page
bebop	proc	near
	push	dx
	push	cx

	call	bebol		;erase to begin of line

	mov	dx,vcrsr
	cmp	dh,crt_tr      ;on top row?
	ja	bop1
	jmp	bopx		;we're already at top; don't clear any more

bop1:	dec	dh
	mov	ch,crt_tr      ;upper left corner
	mov	cl,crt_lc
;	mov	dh,dh		;lower right corner
	mov	dl,crt_rc
	call	bclear

bopx:
	pop	cx
	pop	dx
	ret
bebop	endp


;------ beall: buffer erase whole screen
beall	proc	near
	push	dx
	push	cx

	mov	ch,crt_tr      ;upper left corner
	mov	cl,crt_lc
	mov	dh,crt_br      ;lower right corner
	mov	dl,crt_rc
	call	bclear

	pop	cx
	pop	dx
	ret
beall	endp


;------ bpscroll: scroll specified window in buffer up or down
;	al = 0 iff scroll up
;	bh = top margin, bl = bottom margin of scrolling region

bpscroll proc	 near
	push	ax
	push	bx
	push	cx
	push	dx
	push	si
	push	di
	push	bp
	push	es
	pushf


	cld
	sub	cx,cx				;get count of rows
	mov	cl,bl
	sub	cl,bh				; cx = row count

	or	al,al
	jnz	scr0

	mov	dx,parln		;scroll up
	mov	ax,bufend		; ax = buffer limit
	mov	bp,bufstart		; bp = other side of limit
	jmp	scr1

scr0:
	mov	dx,parln		;scroll down
	neg	dx			; dx = line increment
	mov	bh,bl			;start at bottom row
	mov	ax,bufstart		; ax = buffer limit
	sub	ax,parln
	mov	bp,bufend		; bp = other side of limit
	sub	bp,parln

;	calculate first buffer offset from row
;	(bh contains row ptr)
scr1:
	push	ax
	sub	ax,ax
	mov	al,bh			;rows into al
	mul	parlnb			;times length of line
	add	ax,pageptr
	cmp	ax,bufend
	jb	scr1a
	sub	ax,bufend
	add	ax,bufstart
scr1a:	mov	es,ax
	sub	di,di
	pop	ax

;	es:di now points to first char, first line to scroll

	sub	bx,bx				;get column count
	mov	bl,crt_rc
	sub	bl,crt_lc
	inc	bl				; bx = column count
	jcxz	scr4				;no lines to scroll
						;...so just clear this one

	push	ds

	mov	si,es				;ptr to dest line
	add	si,dx				;add offset (mebbe neg)
	mov	ds,si
	assume	ds:nothing
	sub	si,si

nrow1:	push	cx
	push	si
	push	di
	mov	cx,bx				;get col count
	rep	movsw				;shift row


	mov	di,ds
	add	di,dx				;point to next row
	cmp	di,ax
	jne	scr2
	mov	di,bp
scr2:	mov	ds,di

	mov	si,es
	add	si,dx
	cmp	si,ax
	jne	scr3
	mov	si,bp
scr3:	mov	es,si

	pop	di
	pop	si
	pop	cx
	loop	nrow1

	pop	ds
	assume ds:cm_data

scr4:	call	getattr 			;clear final row
	mov	ah,al
	mov	al,' '
	mov	cx,bx
	rep	stosw

	call	dpage

	popf
	pop	es
	pop	bp
	pop	di
	pop	si
	pop	dx
	pop	cx
	pop	bx
	pop	ax
	ret
bpscroll endp

;------ bscroll: increment the pageptr by one logical line,
;	cause a lf was printed on the screen, causing a scroll
bscroll proc	near
	push	ax
	push	bx
	push	cx
	push	di
	push	es

;	if cursor is on last line of physical screen, then increment scrnptr
;	in effect, the cursor "drags" the window along
	and	tmpflag,not visible	;assume not in window
	call	pgdif
	cmp	dx,-1
	je	lf3
	cmp	dh,crt_br
	jne	lf3

	or	tmpflag,visible 	;assumption incorrect
	mov	ax,scrnptr
	add	ax,parln
	cmp	ax,bufend
	jne	lf3a
	mov	ax,bufstart
lf3a:	mov	scrnptr,ax
lf3:

	mov	ax,pageptr
	add	ax,parln
	cmp	ax,bufend
	jne	lf0
	mov	ax,bufstart
lf0:	mov	pageptr,ax

	mov	ax,endptr
	add	ax,parln
	cmp	ax,bufend
	jne	lf00
	mov	ax,bufstart
lf00:	mov	endptr,ax

   ;	find beginning of last row
	mov	al,crt_br
	sub	al,crt_tr
	mul	parlnb			;get number of paragraphs

	add	ax,pageptr		;recover value
	cmp	ax,bufend
	jb	lf1
	sub	ax,bufend
	add	ax,bufstart
lf1:	mov	es,ax			;point to it

;	clear last row
	sub	di,di
	mov	cx,80
	call	getattr
	mov	ah,al
	mov	al,' '
	rep	stosw			;blank 80 cols at es:di

	mov	ax,es			;recover pointer to last row
	cmp	ax,homeptr
	jne	lfx			;don't move it
	add	ax,parln		;move forward one line
	cmp	ax,bufend
	jne	lf2
	mov	ax,bufstart
lf2:	mov	homeptr,ax

lfx:	test	tmpflag,visible
	jz	lfx2
	call	dpage
lfx2:

	pop	es
	pop	di
	pop	cx
	pop	bx
	pop	ax
	ret
bscroll endp

;------ bdscroll: decrement the pageptr by one logical line,
;	cause a reverse lf was printed on the screen, causing a scroll down
bdscroll proc	 near
	push	ax
	push	bx
	push	cx
	push	dx
	push	di
	push	es

;	if cursor is on top line of physical screen, then decrement scrnptr
;	in effect, the cursor "drags" the window along
	call	pgdif
	cmp	dx,-1
	je	rf2
	cmp	dh,crt_tr
	jne	rf2

	mov	ax,scrnptr
	cmp	ax,bufstart
	jne	rf2a
	mov	ax,bufend
rf2a:	sub	ax,parln
	mov	scrnptr,ax
rf2:

	mov	ax,pageptr		;point to last screen
	cmp	ax,bufstart
	jne	rf0
	mov	ax,bufend
rf0:	sub	ax,parln

	mov	bx,homeptr		;was last screen also first screen?
	cmp	bx,pageptr
	jne	rf1			;no --
	mov	homeptr,ax		;yes -- move first screen back
rf1:	mov	pageptr,ax

	mov	es,ax			;point to top row

	mov	ax,endptr
	cmp	ax,bufstart
	jne	rf00
	mov	ax,bufend
rf00:	sub	ax,parln
	mov	endptr,ax


;	clear top row
	sub	di,di
	mov	cx,80
	call	getattr
	mov	ah,al
	mov	al,' '
	rep	stosw			;blank 80 cols at es:di

	call	dpage

	pop	es
	pop	di
	pop	dx
	pop	cx
	pop	bx
	pop	ax
	ret
bdscroll endp

;------ chrdelete: delete character (shift left)
;	ah = fill attr, al = fill char
;	ch,cl = row,col of char to delete
;	dh,dl = row,col that defines end of shift (where fill char goes)
chrdelete proc	near
	push	ax
	push	bx
	push	cx
	push	dx
	push	es

di2:	push	ax
	mov	al,dh			;last row
	sub	al,crt_tr		;window relative
	mul	parlnb			;# of paragraphs (in ax)
	add	ax,pageptr
	cmp	ax,bufend		;past buffer?
	jb	di3			;yes --
	sub	ax,bufend
	add	ax,bufstart
di3:	mov	es,ax			;es --> first row
	pop	ax

	cmp	dh,ch
	ja	di4			;multiple rows
	call	delsub			;shift final row
	jmp	di5

;	start w/ last row and move up, so deleted chr can be inserted in
;	above row

di4:	push	cx
	mov	ch,dh			;shift to start of last row
	mov	cl,crt_lc
	call	delsub
	mov	ax,bx			;deleted chr becomes fill chr
	pop	cx

	dec	dh			;do next row up
	mov	dl,crt_rc		;starting at right column
	jmp	di2

di5:
	pop	es
	pop	dx
	pop	cx
	pop	bx
	pop	ax
	ret
chrdelete endp

; shift row left
; es --> start of row; cl = first col; dl = last col; ax = fill attr,chr
; on exit, bx contains attr,chr of "lost" position
delsub	proc	near
	push	cx
	push	dx
	push	di
	push	si
	pushf

	cld

	sub	ch,ch		;we don't care about rows
	sal	cx,1
	sub	dh,dh
	sal	dx,1

	mov	di,cx		;dest
	mov	si,cx		;source
	add	si,2

	sub	dx,cx		;get count (in bytes, cause we shifted)
	mov	cx,dx

	mov	bx,word ptr es:[di]	;get deleted char

	push	ds
	push	es
	pop	ds
	rep	movsb
	pop	ds

	stosw			;blast in fill chr and attr

	popf
	pop	si
	pop	di
	pop	dx
	pop	cx
	ret
delsub	endp


;------ chrinsert: insert character (shift right)
;	ah = fill attr, al = fill char
;	ch,cl = row,col of char to open (where fill char goes)
;	dh,dl = row,col that defines end of shift (where char is deleted)
chrinsert proc	near
	push	ax
	push	bx
	push	cx
	push	dx
	push	es

ci2:	push	ax
	mov	al,ch			;first row
	sub	al,crt_tr		;window relative
	mul	parlnb			;# of paragraphs (in ax)
	add	ax,pageptr
	cmp	ax,bufend		;past buffer?
	jb	ci3			;yes --
	sub	ax,bufend
	add	ax,bufstart
ci3:	mov	es,ax			;es --> first row
	pop	ax

	cmp	dh,ch
	ja	ci4			;multiple rows
	call	insub			;shift final row
	jmp	ci5

ci4:	push	dx
	mov	dh,ch			;shift to end of current row
	mov	dl,crt_rc
	call	insub
	mov	ax,bx			;deleted chr becomes fill chr
	pop	dx

	inc	ch			;do next row
	mov	cl,crt_lc		;starting at left column
	jmp	ci2

ci5:
	pop	es
	pop	dx
	pop	cx
	pop	bx
	pop	ax
	ret
chrinsert endp

; move row right.
; es --> start of row; cl = first col; dl = last col; ax = fill attr,chr
; on exit, bx contains attr,chr of "lost" position
insub	proc	near
	push	cx
	push	dx
	push	di
	push	si
	pushf

	std

	sub	ch,ch		;we don't care about rows
	sal	cx,1		;words
	sub	dh,dh
	sal	dx,1		;words

	inc	dx		;point to attr byte
	mov	di,dx		;dest
	mov	si,dx		;source
	sub	si,2

	mov	bx,word ptr es:[di-1]	    ;get last attr,chr

	sub	dx,cx		;get count  (in bytes, cause we shifted)
	mov	cx,dx

	push	ds
	push	es
	pop	ds
	rep	movsb
	pop	ds

	stosw			;blast in fill chr and attr

	popf
	pop	si
	pop	di
	pop	dx
	pop	cx
	ret
insub	endp

;------ wrapmode: set wrapmode iff al = 0
wrapmode proc	near
	and	crt_ctrl,255-nowrap	;assume wrap
	or	al,al
	jnz	wrmx
	or	crt_ctrl,nowrap
wrmx:	ret
wrapmode endp


;------ wsetcrsr: set virtual cursor
wsetcrsr proc	near
	mov	vcrsr,dx
	ret
wsetcrsr endp

;------ wrdcrsr: read virtual cursor
wrdcrsr proc	near
	mov	dx,vcrsr
	ret
wrdcrsr endp

;------ wcrsron: set cursor on flag
;	(acted upon by wcsettle)
wcrsron proc	near
	and	crt_ctrl,255-nocrsr	;assume cursor on
	or	al,al
	jnz	wcr_set
	or	crt_ctrl,nocrsr 	;cursor off
wcr_set:
	ret
wcrsron endp

;------ wcsettle: settle virtual cursor if on real screen
wcsettle proc	near
	push	ax
	push	dx

	call	pgdif
	cmp	dx,-1
	je	wcsx0
	call	setcrsr 		;phys crsr in dx

	test	crt_ctrl,nocrsr 	;cursor is off
	jnz	wcsx0

	mov	al,1
	call	crsron
	jmp	wcsx

wcsx0:	sub	al,al
	call	crsron

wcsx:	call	csettle
	pop	dx
	pop	ax
	ret
wcsettle endp

;------ pgdif: return screen cursor in dx, iff virtual cursor on screen
;	dx = -1 iff cursor not on screen
pgdif	proc	near
	push	ax
	push	bx

	mov	ax,scrnptr		;check screen = page special case
	cmp	ax,pageptr
	jne	pgd0
	mov	dx,vcrsr
	add	dh,wndc_tr
	cmp	dh,wndc_br
	jbe	pgdx1			;correct cursor in dx
	jmp	pgdno

pgdx1:	jmp	pgdx

pgd0:	mov	dx,vcrsr		;get local cursor
	sub	ax,ax
	mov	al,dh			;row
	mul	parlnb			;# of pars
	add	ax,pageptr

	cmp	ax,bufend		;normalize
	jb	pgd1
	sub	ax,bufend
	add	ax,bufstart
pgd1:	mov	bx,ax			;bx contains row offset into buffer

	cmp	bx,scrnptr
	jb	pgd2
	; check if cursor is within window (this side of bufend)
	sub	ax,ax
	mov	al,wndc_br
	sub	al,wndc_tr
	mul	parlnb			;window size in paragrphs
	add	ax,scrnptr		;ax is now last line on screen

	mov	dx,bx			;difference
	sub	dx,scrnptr

	cmp	ax,bx
	jae	pgdok			;yup -- it's in window
	jmp	pgdno

pgd2:	sub	ax,ax
	mov	al,wndc_br
	sub	al,wndc_tr
	mul	parlnb			;window size in pars
	add	ax,scrnptr
	cmp	ax,bufend		;might have gone past bufend
	jbe	pgdno			; crsr not in window
	sub	ax,bufend
	add	ax,bufstart		;adjust for wrap

	cmp	ax,bx
	jb	pgdno
	mov	dx,bx			;calculate row difference
	sub	dx,bufstart		;  ... in paras
	add	dx,bufend
	sub	dx,scrnptr

	jmp	pgdok


pgdok:	mov	ax,dx
	div	parlnb			;get difference in rows
	add	al,wndc_tr		;make window relative
	mov	dx,vcrsr
	mov	dh,al
	jmp	pgdx

pgdno:	mov	dx,-1			;note not in window

pgdx:
	pop	bx
	pop	ax
	ret
pgdif	endp

cm_code ends
end
