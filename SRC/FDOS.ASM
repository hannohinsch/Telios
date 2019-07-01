;	file system support routines

	public	fenable
	public	frestore

	public	fsetmsg

	public	fparse
	public	apptls
	public	appfname
	public	appstar
	public	qdriveno
	public	qstarstar
	public	fbackup

cm_data segment public 'code'

allocate = 0
include b:data.pub

int24o	dw	?		;offset of int 24h handler
int24s	dw	?		;segment of int 24h handler

tempflg db	0		;tempname parse flags
fnexist equ	1
fxexist equ	2

driveno db	0		;drive indicated in parsed filename
fnptr	dw	0		;pointer to filename in tempname
tempname db	80 dup (?)

temp2	db	80 dup (?)

cm_data ends

cm_code segment public 'code'
assume	cs:cm_code
assume	ds:cm_data


;------ fsetmsg: given error code in ax (from file fn), set msgnum
fsetmsg proc	near

	cmp	ax,2
	jne	m3
	mov	msgnum,2	;file not found
	jmp	fsetx
m3:
	cmp	ax,3		;path not found
	jne	m4
	mov	msgnum,28
	jmp	fsetx
m4:
	cmp	ax,4		;too many open files
	jne	m5
	mov	msgnum,51
	jmp	fsetx
m5:
	cmp	ax,5		;access denied
	jne	m6
	mov	msgnum,52
	jmp	fsetx
m6:
	cmp	ax,8		;insufficient memory
	jne	m7
	mov	msgnum,53
	jmp	fsetx
m7:
	cmp	ax,15		;invalid drive
	jne	m8
	mov	msgnum,68
	jmp	fsetx
m8:
	cmp	ax,18		;no more files --> file not found
	jne	m9
	mov	msgnum,2
	jmp	fsetx

m9:	cmp	ax,17
	jne	m10
	mov	msgnum,132	;not same device
	jmp	fsetx

m10:	cmp	ax,critrc	;critical error?
	je	fsetx		;msgnum already set

	mov	msgnum,59	;unexpected error

fsetx:
	ret
fsetmsg endp


;------ fenable: steal int 24, the critical file error handler
fenable proc	near
	push	ax
	push	dx
	push	es
	push	si

;------ save current interrupt handler
	mov	si,4*024h	;absolute address of intrpt handler
	sub	ax,ax
	mov	es,ax
	mov	ax,es:[si]	;get offset
	mov	int24o,ax
	mov	ax,es:2[si]	;get segment
	mov	int24s,ax

;------ set interrupt vector (024h)
	push	ds
	mov	ax,cs
	mov	ds,ax
	mov	dx,offset cm_code:ferror	;offset of interrupt handler
	mov	al,024h
	mov	ah,25h
	int	21h			;dos call (set intrpt handler
	pop	ds

	pop	si
	pop	es
	pop	dx
	pop	ax
	ret
fenable endp

;------ frestore: restore int 24, dos critical file error handler
frestore	proc	near
	push	dx
	push	ax

;------ restore intrpt vector
	push	ds
	mov	dx,int24o	;get old offset
	mov	ax,int24s	;get old segment
	mov	ds,ax
	mov	al,024h 	;reset intrpt 24h
	mov	ah,25h
	int	21h		;dos set intrpt
	pop	ds

	pop	ax
	pop	dx
	ret
frestore endp

;------ ferror: handle dos critical file errors (set msg and ignore error)
;	returns directly to int 21 caller, not to dos
ferror	proc	far

	pop	ax		;cut int 24 return address and flags off stack
	pop	ax
	pop	ax

	mov	ax,cm_data	;address data segment
	mov	ds,ax

	mov	ax,di		;get error code

	cmp	al,0		;write protect error
	jne	fer1
	mov	msgnum,77
	jmp	ferx

fer1:	cmp	al,2		;drive not ready
	jne	fer2
	mov	msgnum,78
	jmp	ferx

fer2:	cmp	al,4		;crc error
	jne	fer3
	mov	msgnum,79
	jmp	ferx

fer3:	cmp	al,6		;seek error
	jne	fer4
	mov	msgnum,80
	jmp	ferx

fer4:	cmp	al,8		;sector not found
	jne	fer5
	mov	msgnum,81
	jmp	ferx

fer5:	cmp	al,10		;write fault
	jne	fer6
	mov	msgnum,82
	jmp	ferx

fer6:	cmp	al,1		;unknown unit
	jne	fer7
	mov	msgnum,132
	jmp	ferx

fer7:	cmp	al,9		;printer out of paper
	jne	fer8
	mov	msgnum,129
	jmp	ferx

fer8:	cmp	al,11		;read fault
	jne	fer9
	mov	msgnum,130
	jmp	ferx

fer9:
	mov	msgnum,131	;unexpected critical error

ferx:	pop	ax		;restore int 21 regs
	pop	bx
	pop	cx
	pop	dx
	pop	si
	pop	di
	pop	bp
	pop	ds
	pop	es

	mov	ax,critrc	;local error code

	push	bp
	mov	bp,sp
	or	word ptr [bp]+6,1	 ;set carry flag to indicate error
	pop	bp

	iret			;return to int 21 'issuer'
ferror	endp

;------ fparse: parse alleged filename, stuffing it into tempname
;	on entry, ds:dx point to filename
fparse	proc	near
	push	ax
	push	bx
	push	cx
	push	dx
	push	si
	push	di
	push	es

	mov	si,dx		;point to source

	push	ds
	pop	es
	mov	di,offset tempname
	mov	fnptr,di

	sub	bl,bl		;flag for empty string
	mov	driveno,bl
	mov	tempflg,bl

cmlp1:	lodsb
	stosb			;move into tempname
	cmp	al,' '          ;terminator
	jb	cmlp3
	je	cmlp1a
	or	bl,1		;note filename (or something like it) found

cmlp1a: cmp	al,':'          ;drive sep?
	je	cmlp2
	cmp	al,'\'
	je	cmlp2b
	cmp	al,'/'
	je	cmlp2b
	cmp	al,'.'
	je	cmlp2c
	mov	ah,al		;remember last char
	jmp	cmlp1

cmlp2:	sub	ah,'@'          ;convert 'A' to 1
	cmp	ah,26		;was it upper case?
	jb	cmlp2a		;yes
	sub	ah,32		;no -- must have been lowercase
cmlp2a: mov	driveno,ah	;found ':'; last char was drive
cmlp2b: sub	bl,bl		;reset filename flag
	mov	fnptr,di	;remember pointer to next char
	jmp	cmlp1

cmlp2c: or	tempflg,fxexist ;note existence of extension
	jmp	cmlp1

cmlp3:	or	bl,bl		;--terminator
	jz	cmlp4		;no filename found
	or	tempflg,fnexist ;note existence of filename

cmlp4:
	pop	es
	pop	di
	pop	si
	pop	dx
	pop	cx
	pop	bx
	pop	ax

	ret
fparse	endp

;------ appfname: append filename pointed to by dx to tempname
;	return w/ ds:dx pointing to tempname
appfname proc	near
	push	ax
	push	si
	push	di
	push	es

	push	ds
	pop	es
	mov	di,fnptr
	mov	si,dx

apfnlp: lodsb
	stosb
	or	al,al
	jnz	apfnlp

	mov	dx,offset tempname

	pop	es
	pop	di
	pop	si
	pop	ax
	ret
appfname endp

;------ appstar: append *.* to path prefix in tempname, if no filename exists
;	return w/ ds:dx pointing to tempname
appstar proc	near
	push	ax
	push	di
	push	es

	test	tempflg,fnexist
	jnz	apstx

	push	ds
	pop	es
	mov	di,fnptr	;point at terminator byte

	mov	al,'*'          ;add *.* suffix
	stosb
	mov	al,'.'
	stosb
	mov	al,'*'
	stosb
	mov	al,0
	stosb			;new terminator byte

apstx:	mov	dx,offset tempname
	pop	es
	pop	di
	pop	ax
	ret
appstar endp


;------ apptls: fill in default filename extension (.tls)
;	on exit ds:dx points to new (altered) filename
apptls	proc near
	push	ax
	push	di
	push	si
	push	es

	test	tempflg,fnexist 	;file must be there
	jz	aptlx

	test	tempflg,fxexist 	;...and extension absent
	jnz	aptlx

	push	ds
	pop	es
	mov	si,fnptr		;point at first byte of filename

aptlp:	lodsb				;find end of string
	or	al,al
	jnz	aptlp

	mov	di,si
	dec	di			;point to terminator

	mov	al,'.'                  ;add default extension
	stosb
	mov	al,'t'
	stosb
	mov	al,'l'
	stosb
	mov	al,'s'
	stosb
	mov	al,0
	stosb

aptlx:	mov	dx,offset tempname

	pop	es
	pop	si
	pop	di
	pop	ax
	ret
apptls	endp

;------ qdriveno: return drive number (from parsed string) in al
;	0 = none specified, 1 = A, etc.
qdriveno proc	near
	mov	al,driveno
	ret
qdriveno endp

;------ qstarstar: set carry flag if file name, extension is *.*
qstarstar proc near
	push	si
	clc				;clear carry flag
	test	tempflg,fnexist
	jz	qstx

	mov	si,fnptr
	cmp	byte ptr [si],'*'
	jne	qstx
	cmp	byte ptr 1+[si],'.'
	jne	qstx
	cmp	byte ptr 2+[si],'*'
	jne	qstx

	stc				;set carry flag
qstx:
	pop	si
	ret
qstarstar endp

;------ fbackup: rename file pointed to by dx, starting extension w/ '~'
;	ignore errors
fbackup proc	near
	push	ax
	push	dx
	push	di
	push	si
	push	es

	mov	si,dx
	push	ds
	pop	es
	mov	di,offset temp2

fba1:	lodsb				;move string to temp2
	stosb
	cmp	al,32
	jb	fba2
	cmp	al,'.'
	je	fba3
	jmp	fba1

fba2:	dec	di			;backup to string terminator
	mov	al,'.'
	stosb				;there wasn't an extension
	mov	al,'~'
	stosb				;blast in new extension prefix
	mov	al,0
	stosb
	jmp	fba5

fba3:	mov	al,'~'
	stosb				;blast in new extension prefix
	lodsb				;check out old prefix
	cmp	al,32
	jae	fba4
	stosb				;preserve old terminator
	jmp	fba5

fba4:	lodsb
	stosb
	cmp	al,32
	jae	fba4			;transfer rest of string

fba5:	mov	di,offset temp2 	;point to new string

	push	dx
	mov	dx,offset temp2 	;point to new name
	mov	ah,41h			;erase current backup
	int	21h
	pop	dx			;ignore errors

	mov	ah,56h			;"rename"
	int	21h			;remember dx still points to original
					;ignore errors
	pop	es
	pop	si
	pop	di
	pop	dx
	pop	ax
	ret
fbackup endp

cm_code ends
end
