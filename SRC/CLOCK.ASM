	public	showck			;display status line
	public	setck			;zero connect time
	public	qckch			;check if we should redisplay
	public	setupd			;force redisplay

cm_data segment public 'code'

allocate = 0
include b:data.pub

stimec	dw	0			;first word of start time
stimed	dw	0			;second word of start time

ctimec	dw	0			;first word of displayed time
ctimed	dw	0			;second word of displayed time

etimec	dw	0			;first word of currently displayed time

cm_data ends


cm_code segment public 'code'
	assume	cs:cm_code,ds:cm_data

extrn	display:near,wswitch:near,rvideo:near,nattr:near,rdcrsr:near

;------ setupd: force redisplay
setupd	proc	near
	mov	ctimec,0ffffh
	ret
setupd	endp

;------ display status line (command line)
showck	proc	near
	push	ax
	push	cx
	push	dx
	push	si


	mov	ah,2ch
	int	21h		;get time
	mov	ctimec,cx	;save to indicate status line updated
	mov	ctimed,dx

	mov	al,wndc_id	;get current window id
	push	ax		;save for exit
	mov	al,6		;switch to command line
	call	wswitch

	test	parm2,clkoff		;suppress clock?
	jz	sc0			;no

	mov	al,12
	call	display 		;clear window
	jmp	stx


sc0:	call	rvideo
	mov	al,12
	call	display

sc1:	mov	al,' '
	call	wdisplay

	mov	al,'t'
	call	wdisplay
	call	showtime

	mov	al,' '
	call	wdisplay

	mov	al,'e'
	call	wdisplay
	call	showctime

	mov	al,' '
	call	wdisplay

	test	tflag,fcap		;active cap file?
	jz	st2

	mov	al,'+'
	test	parmf,capoff		;toggle
	jz	st0
	mov	al,'-'
st0:	call	wdisplay

	mov	cx,cflen		;get length of filename
	mov	si,offset cfname	;point to filename
st1a:	lodsb				;char into al
	call	wdisplay
	loop	st1a

st2:
	test	parm3,screen
	jnz	st3
	mov	al,' '                  ;indicate suppressed screen display
	call	wdisplay
	mov	al,'['
	call	wdisplay
	mov	al,'m'
	call	wdisplay
	mov	al,'u'
	call	wdisplay
	mov	al,'t'
	call	wdisplay
	mov	al,'e'
	call	wdisplay
	mov	al,']'
	call	wdisplay

st3:	test	shift_state,shift_numlk
	jz	stx
	mov	al,' '                  ;indicate numlock toggle
	call	wdisplay
	mov	al,'['
	call	wdisplay
	mov	al,'N'
	call	wdisplay
	mov	al,'u'
	call	wdisplay
	mov	al,'m'
	call	wdisplay
	mov	al,'L'
	call	wdisplay
	mov	al,'k'
	call	wdisplay
	mov	al,']'
	call	wdisplay

stx:	call	nattr
	pop	ax
	call	wswitch

	pop	si
	pop	dx
	pop	cx
	pop	ax
	ret
showck	endp

ten	db	10		;divisor
;------ pnum2: print decimal number currently in al
;	number positive and less then 99
pnum2	proc	near
	push	ax
	push	bx
	push	cx
	push	dx


	sub	ah,ah
	div	ten
	mov	cl,ah
	add	cl,48

	sub	ah,ah
	div	ten
	mov	dl,ah
	add	dl,48

	mov	al,dl
	call	wdisplay
	mov	al,cl
	call	wdisplay
	pop	dx
	pop	cx
	pop	bx
	pop	ax
	ret
pnum2	endp


;------ showtime: show current time in command area
showtime	proc	near
	push	ax
	mov	ah,2ch
	int	21h		;get time
	mov	al,ch
	call	pnum2
	mov	al,':'
	call	wdisplay
	mov	al,cl
	call	pnum2
	pop	ax
	ret
showtime	endp

;------ showctime: show connect time in command area
showctime	proc	near
	push	ax
	push	cx
	push	dx

	mov	ah,2ch
	int	21h		;get time
	mov	ctimec,cx
	mov	ctimed,dx

;	now subtract start time
	sub	dl,byte ptr stimed+lobyte
	jns	sh1
	dec	dh		;carry from dh

sh1:	sub	dh,byte ptr stimed+hibyte
	jns	sh2
	dec	cl		;carry from cl

sh2:	sub	cl,byte ptr stimec+lobyte
	jns	sh3
	dec	ch		;carry from ch
	add	cl,60		;adjust for carry

sh3:	sub	ch,byte ptr stimec+hibyte
	jns	sh4
	add	ch,24		;adjust for 24 hour roll


sh4:	mov	etimec,cx
	mov	al,ch
	call	pnum2
	mov	al,':'
	call	wdisplay
	mov	al,cl
	call	pnum2

	pop	dx
	pop	cx
	pop	ax
	ret
showctime	endp

;------ qckch: check if clock needs to be redisplayed (zf means no change)
qckch	proc	near
	push	ax
	push	cx
	push	dx

	cmp	ctimec,0ffffh		;update flag?
	jne	qsh0
	cmp	ctimec,0		;clear zf
	jmp	qckex			; and exit

qsh0:	test	parm2,clkoff		; no display?
	jz	qsh00
	cmp	al,al			;set zf
	jmp	qckex			;and exit

qsh00:	mov	ah,2ch
	int	21h
	cmp	cx,ctimec		;hours, minutes the same?
	jnz	qckex			;no -- go update


;	now subtract start time, to see if elapsed needs to be updated
	sub	dl,byte ptr stimed+lobyte
	jns	qsh1
	dec	dh		;carry from dh

qsh1:	sub	dh,byte ptr stimed+hibyte
	jns	qsh2
	dec	cl		;carry from cl

qsh2:	sub	cl,byte ptr stimec+lobyte
	jns	qsh3
	dec	ch		;carry from ch
	add	cl,60		;adjust for carry

qsh3:	sub	ch,byte ptr stimec+hibyte
	jns	qsh4
	add	ch,24		;adjust for 24 hour roll

;	cx now contains updated, elapsed time
qsh4:	cmp	cx,etimec	;is it ok?

qckex:	pop	dx
	pop	cx
	pop	ax
	ret
qckch	endp

;------ setck: reset connect timer
setck	proc	near
	push	ax
	push	cx
	push	dx

	mov	ah,2ch
	int	21h
	mov	stimec,cx
	mov	stimed,dx

	pop	dx
	pop	cx
	pop	ax
	ret
setck	endp

;------ wdisplay: display in window, making sure we don't pass right margin
wdisplay proc	near
	push	dx
	call	rdcrsr
	cmp	dl,wndc_rc
	jae	wdisx
	call	display
wdisx:	pop	dx
	ret
wdisplay endp

cm_code ends
end
