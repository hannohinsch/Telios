;------ miscellaneous subfunctions
;	(C) Copyright 1982  Hanno Hinsch

	public	prtog
	public	dopanic
	public	fcaptog

	public	delay
	public	tadd
	public	tadd_sec
	public	dly1000

	public	endchk
	public	scanb
	public	cisit
	public	numscan
	public	nxchr
	public	unseq

	public	emisint

	public	pcntrl
	public	crlf
	public	pnum



cm_data segment public 'code'

allocate = 0
include data.pub

ten	db	10
sixty	db	60
hundred db	100

delayc	dw	0
delayd	dw	0

cm_data ends

cm_code segment  public 'code'

assume	cs: cm_code
assume	ds: cm_data

extrn	setupd:near
extrn	clrxonw:near,chktime:near,display:near
extrn	pr_abort:near,cmndoff:near,rdfclose:near


;------ fcaptog: file capture toggle
fcaptog proc	near

	mov	msgnum,54	;no open cap file
	test	tflag,fcap	;file open?
	jz	fctx		;nope -- error

	xor	parmf,capoff	;toggle cap file switch
	mov	msgnum,56	;"data capture resumed"
	mov	camsg,56

	test	parmf,capoff	;zat rite?
	jz	fctx		;yup
	mov	msgnum,57	;"data capture suspended"
	mov	camsg,57

fctx:	call	setupd		;force clock redisplay

	ret
fcaptog endp


;------ dopanic: turn off send, clear waits
dopanic proc	near
	and	tflag,255-(tdelay+lwait+xmita+cmsleep+t1src)
	call	cmndoff 	;turn off possibly active command file
	call	clrxonw 	;clear xon wait
	and	parm3,255-kblock    ;clear keyboard lock

	test	parm3,ptrans
	jz	pan1
	call	pr_abort	;abort (possible) protocol transfer
	jmp	pan2

pan1:	and	tflag,255-f1src ;don't turn off if protocol active
	call	rdfclose	;close (possibly open) read files
pan2:	mov	msgnum,40
	ret
dopanic endp

;------ prtog: toggle printer
prtog	proc	near
	xor	parmf,prton	;toggle printer echo
	mov	msgnum,60	;"printer started"
	mov	prmsg,60
	test	parmf,prton	;zat rite?
	jnz	prtx		;yup
	mov	msgnum,61	;"printer stopped"
	mov	prmsg,61
prtx:	ret
prtog	endp

;------ delay: wait for time (in tenths of a second)
;	time in al
delay	proc	near
	push	ax
	push	cx
	push	dx
	push	si

	call	tadd		;get stop value into cx,dx
	mov	delayc,cx
	mov	delayd,dx
	mov	si,offset delayc
dlp:	call	chktime
	jz	dlp		;loop until time is up

	pop	si
	pop	dx
	pop	cx
	pop	ax
	ret
delay	endp

;------ tadd: add time in al ( tenths of seconds) to current tod
;	and return the result in cx:dx in dos format
tadd	proc	near
	push	ax

	push	ax
	mov	ah,2ch		;"get time" dos function
	int	21h		;get it into cx:dx
	pop	ax

	sub	ah,ah
	mul	ten		;make it hundredths (byte multiply
	div	hundred 	;split out whole seconds
;				ah=hundredths, al=seconds
	add	dl,ah
	cmp	dl,100
	jb	tax1
	sub	dl,100
	inc	dh		;seconds

tax1:	add	dh,al
	cmp	dh,60
	jb	tax
	sub	dh,60

	inc	cl		;minutes
	cmp	cl,60
	jb	tax
	sub	cl,60

	inc	ch		;hours
	cmp	ch,24
	jb	tax
	sub	ch,ch

tax:	pop	ax
	ret
tadd	endp

;------ tadd_sec: add time in ax (seconds) to current tod
;	and return the result in cx:dx in dos format
tadd_sec proc	 near
	push	ax

	push	ax
	mov	ah,2ch		;"get time" dos function
	int	21h		;get it into cx:dx
	pop	ax

	or	ax,ax
	jz	stax
	div	sixty
				;al= minutes, ah = seconds
				; assume less than one hour (3600 seconds)

stax1:	add	dh,ah		;add seconds
	cmp	dh,60
	jb	stax2
	sub	dh,60

	inc	cl		;minutes
stax2:	add	cl,al
	cmp	cl,60
	jb	stax
	sub	cl,60

	inc	ch		;hours
	cmp	ch,24
	jb	stax
	sub	ch,ch

stax:	pop	ax
	ret
tadd_sec    endp


;------ iowait: subfn for dly1000
iowait	proc	near
	jmp	short $+2
	jmp	short $+2
	ret
iowait	endp

;------ dly1000: hi-res busy wait, in thousandths of a second
;	time to wait in ax
dly1000 proc	near
	push	dx
	push	cx
	push	ax

	mov	cx,ax

	mov	al,10110110b	;select channel 2,lsb,msb,mode 3,binary
	out	43h,al		;write the timer mode reg
	call	iowait

	mov	ax,1193 	;yields 1000hz square wave
	out	42h,al		;write timer 2 cnt - lsb
	call	iowait
	mov	al,ah
	out	42h,al		;write timer 2 cnt - msb
	call	iowait

	in	al,61h		;get current setting of port
	call	iowait
	mov	ah,al		;save for later
	or	al,1		;start timer countdown
	out	61h,al
	call	iowait

	mov	dx,62h		;PC family TIMER 2 found on this port
	in	al,dx
	cmp	al,0ffh 	;PC's won't ever have 0ffh here
	jne	b2
	mov	dx,61h		;PS/2 family has TIMER 2 bit here

b2:	in	al,dx
	call	iowait
	test	al,20h		;timer 2 output bit
	jz	b2		;wait for high

b3:	in	al,dx
	call	iowait
	test	al,20h
	jnz	b3		;wait for low

	loop	b2		;next cycle

	mov	al,ah		;restore saved value
	and	al,0fch 	;zero bits 0,1
	out	61h,al

	pop	ax
	pop	cx
	pop	dx
	ret
dly1000 endp

;------ nxchr: get next char from command line into al.
;	last char in command line assumed to be null
;	convert upper case to lower while we're at it
nxchr	proc	near

;	get next char
	mov	al,[si]

	or	al,al
	jz	nx2			;don't increment after terminator

	cmp	al,65			;upper case A
	jb	nx1
	cmp	al,90			;upper case Z
	ja	nx1
	add	al,32			;convert to lower case

nx1:	inc	si
nx2:
	ret
nxchr	endp

;------ scanb: scan till blanks, then point past them to first non-blank
;	if no blank, set zf.  if no char past blanks, set zf.
scanb	proc	near
	push	ax

scan1:	cmp	byte ptr [si],0
	jne	scan2
scaner: cmp	si,si			;set zf
	jmp	scan4

;	get next char
scan2:
	mov	al,[si]
	cmp	al,32			;find first blank
	je	scan3
	cmp	al,9
	je	scan3
	inc	si
	jmp	scan1

;	si points to blank (or tab)

scan3:	cmp	byte ptr [si],0
	je	scaner
	mov	al,[si]
	cmp	al,32			;scan till end of blanks
	je	scani
	cmp	al,9
	je	scani
	jmp	scan4

scani:	inc	si
	jmp	scan3

scan4:	pop	ax
	ret
scanb	endp


;------ numscan: scan alleged numeric string and convert it to integer in al
;	if we see eol, or it isn't numeric, or is bigger than 256, set zf
numscan proc	near
	push	bx

num0:	call	nxchr
	cmp	al,32
	je	num0		;strip leading blanks
	cmp	al,9
	je	num0

	or	al,al		;terminator?
	jnz	num0a
	jmp	numerr

num0a:	mov	bl,al
	sub	ax,ax		;ax is running count
	jmp	num1		;skip top of loop (we already have char)

numlp:	push	ax
	call	nxchr
	mov	bl,al
	pop	ax

num1:	cmp	bl,32		;control chars terminate number
	jbe	numend
	cmp	bl,48		;digit 0
	jb	numerr		;too low
	cmp	bl,57		;digit 9
	ja	numerr		;too high
	sub	bl,48		;make number

	mul	ten		;multiply al by 10
	jo	numerr		;byte overflow -- number too large
	add	al,bl		;add current number
	jc	numerr		;overflow
	jmp	numlp

numerr: cmp	al,al		;set zero flag
	jmp	numx

numend: or	bl,bl		;al = terminator
	jz	numend2 	; (si not advanced over null)
	dec	si		;point to terminator again
numend2:or	bl,ten		;non-zero for sure
;	note zf is cleared if we fall through here
numx:
	pop	bx
	ret
numscan endp

;------ endchk: check command line for non-blank chars
;	clear zero flag if non-blank chars left on line
endchk	proc	near
	push	ax
zchk1:	call	nxchr
	or	al,al
	jz	zchk2
	cmp	al,32
	je	zchk1
	cmp	al,9
	je	zchk1
zchk2:	pop	ax
	ret
endchk	endp


;------ cisit: check if string pointed to by si is valid abbreviation for
;	string pointed to by di. set zf if yes.
cisit	proc near
	push	ax
	push	bx
	push	di

	push	si				;sometimes thrown away

	sub	bx,bx				;match count

chrlp:	mov	al,[si]
	cmp	al,32
	jbe	cis2
	xor	al,cs:[di]
	jz	cis1
	cmp	al,32				;upper/lower case difference?
	je	cis1
	jmp	notok

cis1:	inc	bx				;increase match count
	inc	di
	inc	si
	cmp	byte ptr cs:[di],0
	jne	chrlp

	mov	al,[si]
	cmp	al,32
	jbe	cis2		       ;was that end of string?
	jmp	notok		       ;no -- supplied string too long

cis2:	cmp	bx,2			;at least 2 chrs must have matched
	jb	notok
	pop	ax			;throw away saved si
	cmp	ax,ax			;set zero flag to indicate match
	jmp	ok

notok:	pop	si			;restore si for next guy
	or	al,1			;clear zero flag

ok:	pop	di
	pop	bx
	pop	ax
	ret
cisit	endp

;------ unseq: decode ^ sequence
;	set CF if unknown; else put decoded char into al
unseq	proc	near
	cmp	al,64		;if @ or bigger
	jl	un0
	cmp	al,95		;and smaller than `
	jg	un0
	sub	al,64		;make into cntrl char (0-32)
	jmp	unfnd		 ;and store

un0:	cmp	al,97		;if bigger than 'a'
	jl	un0a
	cmp	al,122		;and smaller than 'z'
	ja	un0a
	sub	al,96		;make into cntrl chrs
	jmp	unfnd

un0a:	cmp	al,'-'
	jne	un0b
	mov	al,31		;just like '_'
	jmp	unfnd

un0b:	cmp	al,'$'
	jne	un1
	mov	al,32		;alternative blank
	jmp	unfnd

un1:	cmp	al,'!'
	jne	un6
	mov	al,'^'          ;^!=real ^
	jmp	unfnd

un6:	cmp	al,'#'
	jne	un7
	mov	al,127		;^#=delete (127
	jmp	unfnd

un7:	stc			;unknown char
	jmp	unpx

unfnd:	clc			;found
unpx:
	ret
unseq	endp


;------ emisint: pass control to emis handler
;	registers set up by caller (ax,bx,cx,dx)
;	emis handler does NOT pass values back
;	set carry flag if handler not available
emisint proc	near
	push	ax

	test	parm4,emis
	jz	emisx

;	check for installed routine
	push	ax
	push	bx
	mov	al,67h		;get current int67 vector (into es:bx)
	mov	ah,35h
	int	21h
	cmp	word ptr es:[bx]+2,'ME'         ;byte reversal, of course
	jne	emisp
	cmp	word ptr es:[bx]+4,'SI'
	jne	emisp

	pop	bx
	pop	ax
	int	67h			;emis interrupt

	clc				;all ok
	jmp	emisx

emisp:	stc				;indicate handler not available
	pop	bx
	pop	ax

emisx:	pop	ax
	ret
emisint endp


;------ pnum: print decimal number currently in al
;	number positive and less then 999
pnum	proc	near
	push	ax
	push	bx
	push	cx
	push	dx

	sub	ah,ah
	div	ten
	mov	bl,ah		;get remainder
	add	bl,48		;make ascii

	sub	ah,ah
	div	ten
	mov	cl,ah
	add	cl,48

	sub	ah,ah
	div	ten
	mov	dl,ah
	add	dl,48

	cmp	dl,48		;strip leading zeros
	jne	pn3
	cmp	cl,48
	jne	pn2
	jmp	pn1		;always print last digit

pn3:	mov	al,dl
	call	display
pn2:	mov	al,cl
	call	display
pn1:	mov	al,bl
	call	display
	pop	dx
	pop	cx
	pop	bx
	pop	ax
	ret
pnum	endp

;------ pcntrl: print character in al, converting to ^ format if necessary
pcntrl	proc	near
	push	ax
	push	bx

	cmp	al,127
	je	pcnt
	cmp	al,32
	jbe	pcnt
	jmp	pcnt1		;display without ado

pcnt:	push	ax
	mov	al,'^'          ;escape prefix
	call	display
	pop	bx		;recover chr

	mov	al,'#'
	cmp	bl,127		;del
	je	pcnt1

	mov	al,'$'
	cmp	bl,32		;blank
	je	pcnt1

	mov	al,'!'
	cmp	bl,'^'          ;esc (^)
	je	pcnt1

	mov	al,'-'
	cmp	bl,'_'          ;ctrl-minus
	je	pcnt1

	add	bl,64		;ascii 1-->'A',etc.
	mov	al,bl
pcnt1:	call	display

	pop	bx
	pop	ax
	ret
pcntrl	endp

;------ crlf: display cr-lf
crlf	proc	near
	mov	al,13
	call	display
	mov	al,10
	call	display
	ret
crlf	endp
cm_code ends
end

