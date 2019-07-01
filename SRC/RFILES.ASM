	public	rsetup		;setup readfile from command string
	public	fread		;read next char from file if available

;	public	rseek		;seek to file offset
;	public	rsize		;return file size
;	public	exsetup 	;set up "explain" file

	public	dosetup 	;setup do-file from command string
	public	doread		;read next chr from do-file if available
	public	doclose 	;close do-file

;	public	doseek
;	public	dorptr

	public	rdfclose	;close all (possibly open) read files

cm_data segment public 'code'

allocate = 0
include data.pub

rd	fstruc<>		;read file (type, send, psend)
fdo	fstruc<>		;do file (do command file)
ado	fstruc<>		;alternate do file (from DOPROC)

cur_do	dw	offset fdo	;current do file (pointer to either fdo or ado

cm_data ends

cm_code segment public 'code'
assume	cs: cm_code
assume	ds: cm_data

extrn	fsetmsg:near,fparse:near,apptls:near

;------ setup file to send:
;	on entry, ds:si points to filename string
;	on exit, al contains return code 0 -- ok; 1 -- not found
rsetup	proc	near
	push	dx
	push	si

	mov	dx,si		;new call needs addr in dx
	mov	si,offset rd
	call	fropen

	pop	si
	pop	dx
	ret
rsetup	endp


;------ return next char in buffer
;	char goes into al. ah = 0 if all ok, ah = 1 if no char available
fread	proc	near
	push	si

	mov	si,offset rd
	call	fread2
	or	ah,ah
	jnz	frdcl		;close on error

	cmp	al,26		;isit dos eof?
	jne	frdx		;no
	test	tflag,f1src	;is this file send?
	jz	frdcl		;no -- must be "type" -- always close on ^Z
	test	parm4,binfile	;sending binary file?
	jnz	frdx		;yes -- don't stop

frdcl:	call	fclose
	mov	ah,1		;indicate error
frdx:
	pop	si
	ret
fread	endp

;------ rseek: seek to position in read file
;	on entry, dx:ax contains offset to seek to
;	(dx = most significant)
;	on exit, cf is set iff error
rseek	proc	near
	push	cx
	push	dx
	push	si

	mov	si,offset rd		;point to read block
	mov	cx,dx			;cx gets most sig
	mov	dx,ax			;dx gets least sig
	call	fseek

	pop	si
	pop	dx
	pop	cx
	ret
rseek	endp

;------ rsize: find read file size
;	on exit, file size is in dx:ax
rsize	proc	near
	push	bx
	push	cx
	push	si

	mov	si,offset rd		;point to read block
	mov	bx,[si].fhandle

	mov	cx,0ffffh		;seek waay past end
	mov	dx,cx

	sub	al,al			;method = 2 (from end of file)
	mov	ah,42h
	int	21h
	jc	sizeerr
	jmp	sizex

sizeerr: call	fsetmsg
	stc				;set carry

sizex:
	pop	si
	pop	cx
	pop	bx
	ret
rsize	endp

;------ exsetup: set up read from telios.hlp file
;	on entry si points to name of subject
;	on exit, type flag is set so topic will be printed
;	and cf is set iff error
exsetup proc	near
	push	ax
	push	bx
	push	cx
	push	dx
	push	si


	pop	si
	pop	dx
	pop	cx
	pop	bx
	pop	ax
	ret
exsetup endp


;------ setup "do" file:
;	on entry, ds:si points to filename string
;	on exit, al contains return code 0 -- ok; 1 -- not found
dosetup proc	near
	push	dx
	push	si

	mov	dx,si
	call	fparse
	call	apptls		;add default ".tls" extension, if needed
				;ds:dx points to filename

	mov	si,offset ado	;assume alternate do file
	test	cmdflg,doproc	;doproc?
	jnz	dse1		;yup
	mov	si,offset fdo	;normal do file

dse1:	call	fclose		;close it first (may be open from last time)
	mov	cur_do,si
	call	fropen

	or	al,al			;rc=0?
	jnz	dsetx			;nope -- leave error message
	mov	msgnum,24		;all went ok-- executing...
	and	cmdflg,255-(lbsrch+lbwrap)
	sub	ah,ah

dsetx:
	pop	si
	pop	dx
	ret
dosetup endp

;------ return next char in 'DO' buffer
;	char goes into al. ah = 0 if all ok, ah = 1 if no char available
doread	proc	near
	push	cx
	push	dx
	push	si

	mov	si,cur_do

dfr0:	call	fread2
	or	ah,ah
	jnz	dfr1

	cmp	al,26		;DOS e-o-f character?
	jne	dfrex		;no  --

dfr1:	test	cmdflg,lbsrch
	jz	dfr2
	test	cmdflg,lbwrap	;have we already wrapped?
	jz	dfr1a		;no
	mov	msgnum,139	;"label not found"
	jmp	dfr2

dfr1a:	or	cmdflg,lbwrap	;note wrap to beginning of file
	sub	cx,cx		;new file offset
	sub	dx,dx
	call	fseek
	jc	dfr2		;quit on error
	jmp	dfr0		;get next character

dfr2:	call	fclose		;close current file
	test	cmdflg,doproc	;do we return to caller?
	jz	dfr3		;no
	and	cmdflg,255-doproc	;note return
	mov	si,offset fdo	;use caller's fstruc
	mov	cur_do,si
	jmp	dfr0		;get char from calling do file

dfr3:	mov	ah,1		;signal no char available

dfrex:	pop	si
	pop	dx
	pop	cx
	ret
doread	endp

;------ doseek: seek to position in do file
;	on entry, dx:ax contains offset to seek to
;	(dx = most significant)
;	on exit, cf is set iff error
doseek	proc	near
	push	cx
	push	dx
	push	si

	mov	si,cur_do	    ;point to "do" block
	mov	cx,dx			;cx gets most sig
	mov	dx,ax			;dx gets least sig
	call	fseek

	pop	si
	pop	dx
	pop	cx
	ret
doseek	endp

;------ dorptr: return current file pointer
;	dx:ax (dx is most significant)
dorptr	proc	near
	push	si

	mov	si,cur_do

	mov	dx,[si].foffsetm
	mov	ax,[si].foffsetl

	pop	si
	ret
dorptr	endp


;------ doclose: close do files
doclose proc	near
	push	si

	mov	si,offset fdo
	call	fclose

	mov	si,offset ado
	call	fclose

	pop	si
	ret
doclose endp


;------ fropen: open file for reading
;	si --> fstruc
;	ds:dx points to filename
;	on exit, al = 0 if file opened successfully
fropen	proc	near

	mov	al,0		;read only
	mov	ah,3dh		;open
	int	21h
	jc	seterr		;yup -- error return

	mov	[si].fhandle,ax     ;good return
	mov	[si].fcnt,0	    ;force buffer fill
	mov	[si].feof,0	    ;no eof seen yet
	mov	[si].foffsetl,0 	;file offset
	mov	[si].foffsetm,0 	;file offset
	sub	al,al
	jmp	setx

seterr: call	fsetmsg
	mov	al,1

setx:	sub	ah,ah			;rc in al (0 = ok)
	ret
fropen	endp


;------ fread2: read char from file buffer
;	si --> file struc
;	on exit, ah = 0 if char available
;	char in al
fread2	proc	near
	push	si
	push	bx

	cmp	[si].fcnt,0	;any chars left in buffer?
	ja	getchr		;yes
	call	fillbuf 	;no -- get another bufferful
	or	al,al		;any chrs?
	jz	getchr		;yes -- go get it
	mov	ah,1		;bad return code
	jmp	frex

getchr: mov	bx,si
	lea	si,[bx].fbuf	;point to buffer
	add	si,[bx].fptr	;add offset to current chr
	mov	al,[si] 	;and get it
	inc	[bx].fptr	;increment pointer
	dec	[bx].fcnt	;decrement character count
	inc	[bx].foffsetl	;increment file offset
	adc	[bx].foffsetm,0 ; ...and msw of offset
	sub	ah,ah		;ok return code

frex:
	pop	bx
	pop	si
	ret
fread2	endp


;------ fillbuf: fill buffer.
;	al = 0 all ok; non zero if no more data available
;	si --> appropriate fstruc
fillbuf       proc    near
	push	bx
	push	cx
	push	dx
	push	si

	test	[si].feof,1	;did we see eof last time?
	jz	fill		;no -- go read file
	mov	al,1		;bad return code
	mov	msgnum,84	;eof reached
	jmp	fillx

fill:
	mov	bx,[si].fhandle     ;get handle
	mov	cx,buflength
	lea	dx,[si].fbuf
	mov	ah,3fh		;read bytes
	int	21h
	jc	fillerr

	mov	[si].fcnt,ax	;indicate # of chars in buffer
	mov	[si].fptr,0	;point to first char

	cmp	ax,buflength	;did we get full buffer?
	jne	freof		;nope
	sub	al,al		;yes -- rc = 0
	jmp	fillx

fillerr: call	fsetmsg
	mov	al,1		;error	of some sort
	jmp	fillx

freof:	or	[si].feof,1	;set eof flag
	or	ax,ax		;did we get any chars?
	jz	freof2		;no
	sub	al,al		;yes -- rc = 0
	jmp	fillx

freof2: mov	al,1		;didn't get any chars
	mov	msgnum,84	;eof reached

fillx:	pop	si
	pop	dx
	pop	cx
	pop	bx
	ret
fillbuf       endp

;------ fclose: close file (may not be open)
;	si --> fstruc
fclose	proc	near
	push	ax
	push	bx

	mov	bx,[si].fhandle
	or	bx,bx
	jz	fclosx
	mov	ah,3eh			;close
	int	21h

	mov	[si].fhandle,0
fclosx: pop	bx
	pop	ax
	ret
fclose	endp

;------ fseek: seek to offset in cx:dx
fseek	proc	near
	push	ax
	push	bx
	push	cx
	push	dx

	mov	bx,[si].fhandle

	sub	al,al			;method = 0
	mov	ah,42h
	int	21h
	jc	seekerr
	mov	[si].fcnt,0	    ;force buffer fill
	mov	[si].feof,0	    ;no eof seen yet
	mov	[si].foffsetm,dx
	mov	[si].foffsetl,ax


	jmp	seekx

seekerr: call	fsetmsg
	stc				;set carry

seekx:
	pop	dx
	pop	cx
	pop	bx
	pop	ax
	ret
fseek	endp


;------ rdfclose: close all (possibly open) read files
rdfclose proc	near
	push	si

	mov	si,offset rd
	call	fclose

	mov	si,offset fdo
	call	fclose

	mov	si,offset ado
	call	fclose

	pop	si
	ret
rdfclose endp

cm_code ends
end
