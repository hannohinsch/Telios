	public	wrtsetup	;setup writefile from command string
	public	fwrite		;write char to file
	public	wrtclose	;close write file

	public	sfsetup
	public	sfwrite
	public	savclose

	public	stosetup
	public	stowrite
	public	stoclose

cm_data segment public 'code'

allocate = 0
include data.pub

capstruc	fstruc<>
savstruc	fstruc<>
stostruc	fstruc<>

crlf_status	db	0		;remember cr-lf status
lastcr		equ	1		;last char was cr
lastcrlf	equ	2		;last 2 chars were cr-lf

sferror 	db	0		;remember save errors
cm_data ends

cm_code segment public 'code'
assume	cs: cm_code
assume	ds: cm_data

extrn	fsetmsg:near,fparse:near,apptls:near,fbackup:near

;------ setup capture file:
;	on entry, ds:si points to filename string
;	on exit, al contains return code 0 -- ok; 1 -- create error
wrtsetup	proc	near
	push	dx

	mov	dx,si
	call	fbackup
	mov	si,offset capstruc
	call	fcreate
	or	al,al
	jnz	wrx
	mov	msgnum,19		;capture file active
	mov	camsg,19

wrx:	sub	ah,ah
	pop	dx
	ret
wrtsetup	endp

;------ write char to file
;	char in al. ah = 0 if all ok, ah = 1 if error on write
fwrite	proc	near
	push	si

	mov	si,offset capstruc

	call	fwrite2
	or	ah,ah
	jz	wrtchr1
	jmp	wrtchr4

wrtchr1:
;	update crlf_status
	test	crlf_status,lastcr	;did we just see cr?
	je	wrtchr2 		;yes -- check for lf
	cmp	al,13			;no -- but is this cr?
	jne	wrtchr3 		;no -- clear status flag
	or	crlf_status,lastcr	;yes -- remember that
	jmp	wrtchr4 		; and go on

wrtchr2: cmp	al,10			;we saw cr, now is this lf?
	jne	wrtchr3 		;no -- clear crlf_status
	or	crlf_status,lastcrlf	;yes -- mark seen crlf
	jmp	wrtchr4 		; and go on


wrtchr3: and	crlf_status,255-(lastcrlf+lastcr)
wrtchr4:

	pop	si
	ret
fwrite	endp


;------ wrtclose: close write file (this should check BINARY flag)
wrtclose	proc	near
	push	ax
	push	si

	test	parm4,binfile
	jnz	wrtcl2			;don't add jazz if binary file

	test	crlf_status,lastcrlf	;if we just wrote cr-lf, then
	jnz	wrtcl			;don't add null line at end
	mov	al,13			;write cr
	call	fwrite
	mov	al,10			;write lf
	call	fwrite

wrtcl:	mov	al,26			;dos end-of-file char
	call	fwrite			;write it

wrtcl2: mov	si,offset capstruc
	call	fclose

	or	al,al
	jnz	closex			;leave error msg in msgnum
	mov	msgnum,20		;capture file closed

closex: pop	si
	pop	ax
	ret
wrtclose	endp

;------ sfsetup: setup save file
;	si points to filename to use
sfsetup proc	near
	push	ax
	push	dx
	push	si

	mov	dx,si
	call	fparse
	call	apptls			;add .tls extension, if needed
	call	fbackup

	mov	si,offset savstruc
	call	fcreate
	mov	sferror,al		;remember if error

	pop	si
	pop	dx
	pop	ax
	ret
sfsetup endp

;------ write char to file
;	char in al.
sfwrite  proc	 near
	push	ax
	push	si

	cmp	sferror,0		;ignore call if we had error
	jne	sfwx

	mov	si,offset savstruc
	call	fwrite2
	mov	sferror,ah		;store error

sfwx:
	pop	si
	pop	ax
	ret
sfwrite  endp


;------ savclose: close save file
savclose	proc	near
	push	ax
	push	si

	mov	al,26			 ;dos end-of-file char
	call	sfwrite 		 ;write it

	mov	si,offset savstruc
	call	fclose

	or	al,al
	jnz	savclx
	cmp	sferror,0
	jne	savclx
	mov	msgnum,95		;saved ok

savclx: pop	si
	pop	ax
	ret
savclose	endp


;------ stosetup: setup for buffer store
;	si points to filename to use
;	on exit, al = 0 iff ok
stosetup proc	 near
	push	dx
	push	si

	mov	dx,si
	call	fbackup

	mov	si,offset stostruc
	call	fcreate

	pop	si
	pop	dx
	ret
stosetup endp

;------ write char to file
;	char in al.
;	on exit ah = 0 iff written ok
stowrite  proc	  near
	push	si

	mov	si,offset stostruc
	call	fwrite2

	pop	si
	ret
stowrite  endp


;------ stoclose: close buffer store file
;	on exit, al = 0 iff all ok
stoclose	proc	near
	push	si

	mov	si,offset stostruc

	call	isdevice
	jc	stoc1			;don't write ctrl-z to devices
	mov	al,26
	call	fwrite2

stoc1:	call	fclose

	pop	si
	ret
stoclose	endp


;------ fcreate: create file
;	si --> fstruc
;	ds:dx --> file name
;	on exit, al = 0 if successful
fcreate proc	near
	push	cx

	mov	ah,3ch		;create file
	mov	cx,0		;new file attribute
	int	21h
	jc	foperr		;go check out error

	mov	[si].fhandle,ax
	mov	[si].fptr,0
	sub	al,al
	jmp	wsetx


foperr: call	fsetmsg
	mov	al,1
	jmp	wsetx		;nope - exit

	; What prevents the creation of screwy filenames????

wsetx:	sub	ah,ah
	pop	cx
	ret
fcreate endp

;------ fwrite2: write char to file
;	char in al
;	si --> fstruc
;	at exit, ah = 0 if successful
;	note char in al preserved over call
fwrite2 proc	near
	push	di


	push	ax
	cmp	[si].fptr,buflength  ;any room left in buffer?
	jb	wrtchr		;yes
	call	fwrbuf		;no -- write this buffer
	or	al,al		;any errors?
	jz	wrtchr		;no -- go write char
	pop	ax		;throw away saved char
	mov	ah,1		;bad return code
	jmp	fwrtex

wrtchr: pop	ax		;recover chr

	lea	di,[si].fbuf	;point to buffer
	add	di,[si].fptr	;add offset to current chr
	mov	[di],al 	;and write it
	inc	[si].fptr
	sub	ah,ah		;all ok

fwrtex:
	pop	di
	ret
fwrite2 endp

;------ fwrbuf: write buffer to file
;	si --> fstruc
;	on exit, al = 0 if successful
fwrbuf	proc	near
	push	bx
	push	cx
	push	dx

	mov	bx,[si].fhandle
	mov	cx,[si].fptr
	lea	dx,[si].fbuf

	sub	al,al
	jcxz	wrtbex		;don't write empty buffer

	mov	ah,40h		;write record (sequential
	int	21h		;al contains return code
	jc	wrberr
	cmp	ax,[si].fptr	;did we write them all?
	jne	wfdful		;no -- disk full

	mov	[si].fptr,0	;point to first chr in buffer
	sub	al,al
	jmp	wrtbex

wfdful: mov	msgnum,4
	mov	al,1
	jmp	wrtbex

wrberr: call	fsetmsg
	mov	al,1
	jmp	wrtbex

wrtbex:
	pop	dx
	pop	cx
	pop	bx
	ret
fwrbuf	endp

;------ fclose: close file
;	si --> fstruc
;	al = 0 if all ok
fclose	proc	near
	push	bx
	push	cx
	push	si


	call	fwrbuf		;make sure last buffer is written
	mov	cl,al		;store error code

	mov	bx,[si].fhandle
	mov	ah,3eh
	int	21h
	jc	fclserr

	mov	al,1		;assume error
	or	cl,cl		;check fwrbuf error code
	jnz	fclsx		;yup -- error

	sub	al,al
	jmp	fclsx

fclserr:call	fsetmsg
	mov	al,1
fclsx:
	pop	si
	pop	cx
	pop	bx
	ret
fclose	endp

;------ isdevice: set carry flag if file is a device
isdevice proc	near
	push	ax
	push	bx
	push	dx

	mov	bx,[si].fhandle
	mov	al,0			;get device info
	mov	ah,44h
	int	21h

	clc
	test	dx,64			;is device?
	jz	isdx
	stc
isdx:
	pop	dx
	pop	bx
	pop	ax
	ret
isdevice endp

cm_code ends

end
