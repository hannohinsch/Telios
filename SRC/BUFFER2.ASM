;------ store and retrieve characters
	public	bufinit
	public	bufwindow

	public	pageup
	public	pagedn
	public	pgend
	public	pghome
	public	linedn
	public	lineup

	public	dpage

	public	stobuf


scrnlenw equ	24*80		;words on screen

cm_data segment public 'code'

allocate = 0
include data.pub
include buffer.pub

cm_data ends


cm_buffer segment public 'zzz'          ;defined globally
cm_buffer	ends


cm_code segment public 'code'
assume	cs:cm_code
assume	ds:cm_data

extrn	scroll:near,dscroll:near,setcrsr:near,wswitch:near,csettle:near
extrn	rdcrsr:near,display:near,q80:near,getattr:near,qwindow:near
extrn	stosetup:near,stowrite:near,stoclose:near


;------ bufinit: initialize buffer and pointers
;	on entry, ax contains paragraph address of upper memory bound
bufinit proc	near
	push	ax
	push	bx
	push	cx
	push	dx
	push	di
	push	es


	mov	bx,cm_buffer
	mov	es,bx			;for screen clear
	mov	scrnptr,bx
	mov	pageptr,bx
	mov	homeptr,bx
	mov	bufstart,bx

;	calculate maximum size of buffer (use all of memory)

	mov	bufend,ax		;assume full use of memory
	sub	ax,bx			;upper memory - buffer start
	sub	dx,dx			;ax extension
	div	parlnw			;must be integral number of lines
					;remainder in dx
	sub	bufend,dx		;trim by remainder (make modulo PARLN)

	call	bufwindow		;initialize endptr

;	clear first screen

	call	getattr
	mov	ah,al
	mov	al,' '
	mov	cx,scrnlenw		;clear first screen
	sub	di,di
	cld
	rep	stosw			;write to es:di

	pop	es
	pop	di
	pop	dx
	pop	cx
	pop	bx
	pop	ax
	ret
bufinit endp

;------ bufwindow: initialize endptr, given window size and pageptr
; also, scrnptr should be decremented if necessary on window size increase
bufwindow proc	near
	push	ax
	push	bx
	push	cx

	mov	ax,23*parln		;lines on virtual screen (org 0)
	add	ax,pageptr		;furthest possible boundary

	cmp	ax,bufend
	jb	bfw1
	sub	ax,bufend
	add	ax,bufstart
bfw1:
	sub	bx,bx			;"crossed scrnptr" flag

;	now decrement ax to proper size, dragging back scrnptr if we
;	cross it

	sub	cx,cx
	mov	cl,wndc_br
	sub	cl,wndc_tr
	jcxz	bfw8

bfw2:
	sub	ax,parln		;back up one line

	cmp	ax,bufstart
	jae	bfw3
	mov	ax,bufend
	sub	ax,parln
bfw3:
	cmp	ax,scrnptr
	jne	bfw4
	mov	bx,1			;remember hit

bfw4:	loop	bfw2

;	Ax now contains value of new endptr.
bfw8:	mov	endptr,ax
	or	bx,bx			;crossed scrnptr?
	jz	bfw9
	mov	scrnptr,ax		;yup

bfw9:
	pop	cx
	pop	bx
	pop	ax
	ret
bufwindow endp

;------ lineup: roll the screen up one line
lineup	proc	near
	push	ax
	push	dx
	mov	dx,scrnptr
	call	upln		;move scrnptr up one line
	cmp	dx,scrnptr
	je	lup

	call	rdcrsr
	push	dx			;save for exit
	mov	dh,wndc_tr
	mov	dl,wndc_lc
	call	setcrsr

	mov	al,1
	call	dscroll 	;scroll screen down one line
	mov	ax,scrnptr
	call	q80		;display new top line
	pop	dx		;restore cursor
	call	setcrsr

lup:
	pop	dx
	pop	ax
	ret
lineup	endp


;------ linedn: roll the screen down one line
linedn	proc	near
	push	ax
	push	dx

	mov	dx,scrnptr
	call	dnln		;move scrnptr down one line
	cmp	dx,scrnptr
	je	ldn

	call	rdcrsr
	push	dx			;save for exit
	mov	dh,wndc_br
	mov	dl,wndc_lc
	call	setcrsr

	mov	al,1
	call	scroll		;scroll screen up one line

	mov	dx,scrnptr

   ;	find beginning of last row
	mov	al,wndc_br
	sub	al,wndc_tr
	mul	parlnb		;get number of paragraphs
	add	dx,ax

	cmp	dx,bufend
	jb	ld1
	sub	dx,bufend
	add	dx,bufstart
ld1:	mov	ax,dx			;point to it
	call	q80			;display bottom line

	pop	dx		;restore cursor
	call	setcrsr

ldn:
	pop	dx
	pop	ax
	ret
linedn	endp

;------ pgend: roll screen to last page
pgend	proc	near
	push	ax
	mov	ax,endptr
	cmp	ax,scrnptr
	je	pgex
	mov	scrnptr,ax
	call	dpage
pgex:
	pop	ax
	ret
pgend	endp

;------ pghome: roll screen to first page
pghome	proc	near
	push	ax
	mov	ax,homeptr
	cmp	ax,scrnptr
	je	pghx
	mov	scrnptr,ax
	call	dpage
pghx:
	pop	ax
	ret
pghome	endp

;------ pageup: roll the screen up one page
pageup	proc	near
	push	dx
	push	cx

	mov	dx,scrnptr		;remember it

;	get count of lines to roll
	sub	ch,ch
	mov	cl,wndc_br
	sub	cl,wndc_tr
	inc	cx			;zero origin

pguplp: call	upln
	loop	pguplp

	cmp	dx,scrnptr		;has it changed?
	je	pgux			;no
	call	dpage

pgux:
	pop	cx
	pop	dx
	ret
pageup	endp

;------ pagedn: roll the screen down one page
pagedn	proc	near
	push	dx
	push	cx

	mov	dx,scrnptr

;	get count of lines to roll
	sub	ch,ch
	mov	cl,wndc_br
	sub	cl,wndc_tr
	inc	cx			;zero origin

pgdnlp: call	dnln
	loop	pgdnlp

	cmp	dx,scrnptr		;has it changed?
	je	pgdx
	call	dpage

pgdx:

	pop	cx
	pop	dx
	ret
pagedn	endp

;------ dpage: subroutine to display current page.
;	scrnptr points to beginning of page to display.
;	routine writes number of logical lines in current window.
dpage	proc	near
	push	ax
	push	bx
	push	cx
	push	dx


	cmp	termtype,dost		;no screen redisplay w/ term dos
	jne	dplp1
	jmp	dpax

dplp1:

;	print number of lines in current window
	mov	al,wndc_br		;number of lines
	sub	al,wndc_tr
	inc	al
	sub	ah,ah
	mul	parlnb			;ax = number of paragraphs

	mov	bx,scrnptr		;point to first line
	add	bx,ax			; bx --> last line

	cmp	bx,bufend
	jbe	dplp2			;blast away -- not over buffer end

	sub	bx,bufend
	add	bx,bufstart
	mov	dx,bx			;stop2
	mov	cx,bufstart		;start2
	mov	bx,bufend		;stop1
	mov	ax,scrnptr		;start1
	call	qwindow

	jmp	dpax

dplp2:	mov	ax,scrnptr
	; bx is set to last line
	sub	cx,cx
	sub	dx,dx			;start2/stop2 not needed
	call	qwindow

dpax:	pop	dx
	pop	cx
	pop	bx
	pop	ax
	ret
dpage	endp


;------ upln: roll the screen up one line
upln	proc	near
	push	ax

	mov	ax,scrnptr
	cmp	ax,homeptr
	je	uplnx

	cmp	ax,bufstart
	jne	upln1
	mov	ax,bufend			;roll across buffer end

upln1:	sub	ax,parln			;back up one line
	mov	scrnptr,ax

uplnx:

	pop	ax
	ret
upln	endp

;------ dnln: roll the screen down one line
dnln	proc	near
	push	ax

	mov	ax,scrnptr		;don't roll past end of logical screen
	cmp	ax,endptr
	je	dpex			;already at end

dpe1:	add	ax,parln

	cmp	ax,bufend
	jne	dpe2
	mov	ax,bufstart			;roll across buffer end
dpe2:	mov	scrnptr,ax

dpex:

	pop	ax
	ret
dnln	endp


;------ stobuf: store contents of buffer, from scrnptr to end
;	si --> file name to use
stobuf	proc	near
	push	ax
	push	bx
	push	cx
	push	dx
	push	si
	push	es

	call	stosetup
	or	al,al
	jz	sto0
	jmp	stoerx			;error

sto0:	mov	bx,scrnptr
	mov	dx,endptr

	mov	al,wndc_id		;switch to main window
	push	ax
	mov	al,1
	call	wswitch
	mov	al,wndc_br		;get number of lines on screen
	sub	al,wndc_tr
	inc	al
	mul	parlnb			;number of paragraphs
	add	dx,ax			;add in last screen
	pop	ax
	call	wswitch 		;back to previous window

	cmp	dx,bufend
	jb	sto1
	sub	dx,bufend		;account for buffer wrap
	add	dx,bufstart

sto1:	cmp	bx,dx
	je	sto10			;normal exit

	mov	cx,80			;do line
	mov	si,158
	mov	es,bx

;	find last non-blank
sto1a:	cmp	byte ptr es:[si],32		 ;blank?
	jne	sto1b
	sub	si,2
	loop	sto1a
	jmp	sto3			;all blanks

sto1b:	sub	si,si			;point to first char

sto2:	mov	al,es:[si]
	call	stowrite
	or	ah,ah
	jnz	stoer9			;close on error
	add	si,2
	loop	sto2

sto3:	mov	al,13			;write cr-lf
	call	stowrite
	or	ah,ah
	jnz	stoer9

	mov	al,10
	call	stowrite
	or	ah,ah
	jnz	stoer9

	add	bx,parln		;do next line
	cmp	bx,bufend		;handle buffer wraparound
	jne	sto4
	mov	bx,bufstart
sto4:	jmp	sto1



sto10:	call	stoclose
	or	al,al
	jnz	stoerx
	jmp	stox

stoer9: call	stoclose		;we already had error; close anyway
stoerx: stc				;note error
	jmp	stox2

stox:	clc				;no error
	mov	msgnum,95		;saved ok
stox2:
	pop	es
	pop	si
	pop	dx
	pop	cx
	pop	bx
	pop	ax
	ret
stobuf	endp

cm_code ends
end
