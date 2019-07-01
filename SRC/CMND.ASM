;------ cmnd: handle the command area

	public	cmcont
	public	cmndf2
	public	doinit
	public	cmndoff
	public	getkline

cm_data segment public 'code'

allocate = 0
include data.pub

cm_data ends

cm_code segment public 'code'
assume	cs:cm_code
assume	ds:cm_data

extrn	display:near,wswitch:near,pmsg:near,doread:near,rdkeyb:near,comproc:near
extrn	helpscrn:near,clrhelp:near,status:near,dofshow:near,pnum:near,showck:near
extrn	nattr:near,hilite:near,rdcrsr:near,altkeys:near
extrn	fsrefresh:near,window:near,qnxchr:near,doclose:near
extrn	csettle:near,crsron:near

;------ cmndoff: clear command active flags
cmndoff proc	near
	and	cmdflg,255-(doact+doproc+circ2+lbsrch+lbwrap)
	and	parm4,255-(qinact+trcmnd+trcomm)
	ret
cmndoff endp


;------ cmcont: process next command from command file, if active
cmcont	proc	near
	and	cmdflg,255-f2		;not called by f2
	test	cmdflg,doact		;active?
	jz	cmcnx			;
	call	command 		;do it
cmcnx:	ret				;nothing to do
cmcont	endp

;------ cmndf2: user pressed alt-c, so go into command mode
cmndf2	proc	near
	test	parm2,cmndm		;are we already in command mode?
	jnz	cmndfx			;yup -- ignore call
	or	cmdflg,f2+noret
	and	cmdflg,255-(doact+doproc)    ;push alt-c; file dies
	call	command
cmndfx: ret
cmndf2	endp

;------ command: process special sequences
command proc	near
	push	si

	or	parm2,cmndm	;enter command mode
	or	parm3,rtimer	;invalidate timer

	test	cmdflg,f2	;from file?
	jnz	cmdex1		;no
	call	getfline	;get line from file
	jmp	cmdex2

cmdex1: mov	msgnum,26	;ready for command
	call	pmsg
cmdex1a: call	 getkline	 ;get line from keyboard

cmdex2: and	cmdflg,255-cmderr
	call	comproc 	;process command string
	call	pmsg
	test	cmdflg,cmderr	;was command successful?
	jz	cmdex3		;yes
	test	cmdflg,doact	;from file?
	jnz	cmdex2a 	;yes --
	call	getkline2	;interactive -- don't erase command line
	jmp	cmdex2

cmdex2a: and	cmdflg,255-(doact+doproc) ;turn file off
	and	parm4,255-(trcmnd+trcomm)	;cancel pending transactions
	call	doclose
	jmp	cmdex5		;exit gracefully

cmdex3: test	cmdflg,noret	;delayed return?
	jz	cmdex4		;no
	call	fsrefresh	;possible refresh of status/fkey scrn
	jmp	cmdex1a 	;yes -- get ready for another command

cmdex4: call	clrhelp 	;redisplay page, cause HELP may have
				;screwed it up, and go back to window 1
	test	cmdflg,f2	;skip status redisplay if from file
	jz	cmdex5
	call	showck		;show status line

cmdex5: and	parm2,255-cmndm ;exit command mode

	pop	si
	ret
command endp


;	doinit: entry point to execute startup file
;	si points to string which contains starting filename
;	first element in string is number of chars in string
doinit	proc	near
	push	ax
	push	cx
	push	di
	push	si
	push	es

	sub	cx,cx
	mov	cl,[si]
	inc	si			;point si past length
	mov	cmdptr,cx
	add	cmdptr,3		;add 3 for "DO " prefix

	push	ds
	pop	es
	mov	di,offset cmdline
	mov	al,'d'
	stosb
	mov	al,'o'
	stosb
	mov	al,' '
	stosb
	rep	movsb			;move filename into command line

	sub	al,al			;terminator
	stosb

	call	comproc 	;process command string

	pop	es
	pop	si
	pop	di
	pop	cx
	pop	ax
	ret
doinit	endp

;------ getkline: get line from keyboard

getkline2 proc	near		;second entry point -- leaves line untouched
	push	ax
	push	cx
	push	di
	push	si
	push	es
	jmp	cmdoa

;------ getkline: get line from keyboard
getkline proc	 near
	push	ax
	push	cx
	push	di
	push	si
	push	es

	mov	al,6		;new window = command line
	call	wswitch

top:	mov	ax,0ff0ch	;clear and home cursor
	call	display

	call	hilite		;print hilited command prompt
	mov	al,62
	call	display
	call	nattr

;	initialize command line buffer
	mov	cmdptr,0	;initialize command line write pointer
	mov	di,offset cmdline
	mov	cx,cmdline_len
	sub	al,al		;initialize w/ nulls
	push	ds
	pop	es
	rep	stosb

	mov	al,1
	call	crsron		;show cursor

cmdoa:	call	csettle 	;settle cursor
cmdoab: call	rdkeyb
	jz	cmdoab

	cmp	ah,frompfk	;pf key?
	je	ca1		;yes
	cmp	al,9		;tab from kbd?
	jne	cmdob
	mov	al,' '          ;replace with blank (keyboard only)
	jmp	cmdob

ca1:	call	altkeys 	;process pfkeys
	call	pmsg		;print possible msg
	jmp	cmdoa		;ignore it (and all others

;	process characters
cmdob:
	cmp	al,13		;carriage return?
	je	cmdox		;yes --exit

	cmp	al,8			;backspace?
	je	cmdoa00 		;yes

	cmp	al,9			;tab?
	je	cmdoa1			;yes -- accept it

cmdob2: cmp	al,27			;esc?
	jne	cmdob3
	jmp	top			;yes -- clear command line

cmdob3: cmp	al,32
	jb	cmdoa			;ignore other control characters
	jmp	cmdoa1

cmdoa00:dec	cmdptr			;handle backspace editing
	jns	cmdoa0
	mov	cmdptr,0		;don't backspace past beginning
	jmp	cmdoa

cmdoa0: mov	si,offset cmdline
	add	si,cmdptr
	mov	byte ptr [si],0
	push	ax
	mov	al,8
	call	display 		;backspace
	mov	al,32
	call	display
	mov	al,8
	call	display
	pop	ax
	jmp	cmdoa			;and get next chr

cmdoa1: mov	si,offset cmdline	;address command line buffer
	add	si,cmdptr

	cmp	cmdptr,(cmdline_len)-2	     ;are we at buffer end?
					     ; (keep one null at end)
	jae	cmdoa3			;yes -- skip increment
	push	ax
	sub	ax,ax
	mov	al,wndc_rc
	sub	al,wndc_lc		;get length of command line
	sub	ax,1			;keep one space open
	cmp	ax,cmdptr
	pop	ax
	jbe	cmdoa3			;make sure it doesn't go too far

cmdoa4: mov	[si],al 		;store char
	call	display
	inc	cmdptr

cmdoa3: jmp	cmdoa

cmdox:
	pop	es
	pop	si
	pop	di
	pop	cx
	pop	ax
	ret
getkline endp
getkline2 endp


;------ getfline: get line from file
getfline proc	 near
	push	ax
	push	cx
	push	di
	push	si
	push	es

	call	softcrlf	;cr-lf iff not already at margin

;	initialize command line buffer
	mov	cmdptr,0	;initialize command line write pointer
	mov	di,offset cmdline
	mov	cx,cmdline_len
	sub	al,al		;initialize w/ nulls
	push	ds
	pop	es
	rep	stosb


fmdlp:
;	get char from file
	call	doread		;get char
	or	ah,ah		;error?
	jnz	fdofoff 	 ;yes -- turn it off
	jmp	fmdob

fdofoff: and	 cmdflg,255-doact	 ;turn off "do active" flag
	jmp	fmdex			;fake final cr(some files end w/^z)

;	process characters
fmdob:
	cmp	al,13		;carriage return?
	jne	fmdo9
	jmp	fmdex		;yes --exit

fmdo9:	cmp	al,9			;tab?
	je	fmdoa1			;yes -- accept it

fmdob3: cmp	al,32
	jb	fmdlp			;ignore other control characters

fmdoa1: mov	si,offset cmdline	;address command line buffer
	add	si,cmdptr

	cmp	cmdptr,(cmdline_len)-2		;are we at buffer end?
						;(keep one null at end)
	jae	fmdoa3			;yes -- skip increment

fmdoa4: test	cmdflg,lbsrch		;label search?
	jnz	fmdoa6			;don't process ^2 during search
	cmp	al,'^'
	jne	fmdoa5
	or	cmdflg,circ2
	jmp	fmdoa3

fmdoa5: test	cmdflg,circ2
	jz	fmdoa6
	cmp	al,'2'
	jne	fmdoa5a

;	get next word from queue, not file
fmdo5b: call	qnxchr
	jc	fmdo5c			;error
	cmp	al,32
	jbe	fmdo5b			;skip leading delimiters
	jmp	fmdo5bc 		;process char

fmdo5bb:call	qnxchr
	jc	fmdo5c			;error
	cmp	al,32
	jbe	fmdo5c			;end of word
fmdo5bc:mov	[si],al
	call	cdisp			;display it
	inc	si
	inc	cmdptr
	cmp	cmdptr,(cmdline_len)-2		;are we at buffer end?
	jb	fmdo5bb 			;no -- get next char

fmdo5c: and	cmdflg,255-circ2
	jmp	fmdoa3

fmdoa5a: mov	byte ptr [si],'^'       ;do the previously suppressed '^'
	push	ax
	mov	al,'^'
	call	cdisp
	pop	ax
	inc	cmdptr
	inc	si		;and do the current character

fmdoa6: and	cmdflg,255-circ2
	mov	[si],al 		;store char
	call	cdisp
	inc	cmdptr

fmdoa3: jmp	fmdlp

fmdex:	call	softcrlf

	pop	es
	pop	si
	pop	di
	pop	cx
	pop	ax
	ret
getfline endp

;------ cdisp: display char (in al) in main window (for file)
cdisp	proc	near
	push	ax

	test	parm2,nolist		;suppress listing?
	jnz	cdispx
	test	cmdflg,lbsrch
	jnz	cdispx

	mov	ah,fromt1		;just like typing
	call	window

cdispx: pop	ax
	ret
cdisp	endp


;------ softcrlf: display cr-lf iff cursor not at left margin
softcrlf	proc	near
	push	ax
	push	dx

	test	parm2,nolist
	jnz	softx
	test	cmdflg,lbsrch
	jnz	softx

	call	rdcrsr
	cmp	dl,wndc_lc	;left col?
	je	softx
	mov	ah,fromt1
	mov	al,13
	call	window
	mov	al,10
	call	window

softx:	pop	dx
	pop	ax
	ret
softcrlf	endp

cm_code ends
end
