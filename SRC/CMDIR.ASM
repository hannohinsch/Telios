	public	cmdir
	public	ferase
	public	frename
	public	seldrive
	public	chdir

cm_data segment public 'code'

allocate = 0
include data.pub

dtabuf	db	128 dup(?)	;disk transfer area

oldwin	db	0		;save area for old window id
dircnt	db	0		;count of line wraps for positioning end msg
driveno db	0		;temporary space for specified drive number
curdisk db	0		;place to stash current drive number

five	db	5

dtamap	struc
drsved	db	21 dup (?)
dattr	db	?
dtime	db	2 dup (?)
ddate	db	2 dup (?)
dsizl	dw	?
dsizh	dw	?
dname	db	8 dup (?)
dper	db	'.'
dext	db	3 dup (?)
dzero	db	0
dtamap	ends

dirmap	dtamap <>

dir0	dw	dir0z-dir0a
dir0a	db	' File directory',28 dup(' ')
dir0z	db	?

dir1	dw	dir1z-dir1a
dir1a	db	' bytes available on drive '
dir1z	db	?

dir2	dw	dir2z-dir2a
dir2a	db	13,10,80 dup (205),13,10,10
dir2z	db	?

dire	dw	dirz-dira
dira	db	13,10
	db	'Enter ==> conversation mode; or type a command'
dirz	db	?

cm_data ends

cm_code segment public 'code'
assume	cs: cm_code
assume	ds: cm_data

extrn	display:near,wswitch:near
extrn	qwrite:near,hilite:near,nattr:near
extrn	fsetmsg:near,qstarstar:near,fparse:near,appfname:near,qdriveno:near
extrn	appstar:near

;------ dirend: show nice continue msg for dir screen
;	we need to use 'dumb' display call, rather than fast one, cause
;	we may scroll at end. Qwrite routine doesn't scroll.
dirend	proc	near
	push	ax
	push	cx
	push	si

	call	hilite
	mov	si,offset dire
	mov	cx,[si]
	add	si,2
dendlp: lodsb
	call	display
	loop	dendlp
	call	nattr

	pop	si
	pop	cx
	pop	ax
	ret
dirend	endp


;------ dirstart1: show nice header msg for dir screen
dirstart1	proc	near
	push	si
	mov	si,offset dir1
	call	qwrite
	pop	si
	ret
dirstart1	endp


;------ dirstart0: show nice header msg for dir screen
dirstart0	proc	near
	push	si
	mov	si,offset dir0
	call	qwrite
	pop	si
	ret
dirstart0	endp

;------ dirstart2: show nice header msg for dir screen
dirstart2	proc	near
	push	si
	mov	si,offset dir2
	call	qwrite
	pop	si
	ret
dirstart2	endp

;------ print file directory a la dos
;	on entry, ds:si points to filename string
cmdir	proc	near
	push	ax
	push	cx
	push	dx
	push	di
	push	si
	push	es

	or	cmdflg,cmderr	;assume error

;	initialize count of line wraps. incremented by pdir
	mov	dircnt,0

	mov	dx,si		;let dx point to string
	call	fparse
	call	appstar 	;add *.* if no file specified

	call	qdriveno
	mov	driveno,al	;specified drive

	push	dx
	mov	dx,offset dirmap ;get dta address
	mov	ah,1ah		;set dta subcode
	int	21h
	pop	dx

cmlp4a: mov	cx,10h		;normal and directory file attributes ok
;	search for first entry
	mov	ah,4eh
	int	21h
	jnc	cmd2

	call	fsetmsg
	jmp	direx4		;exit w/out screen update

cmd2:
	mov	al,wndc_id
	mov	oldwin,al
	mov	al,3		;switch to help window
	call	wswitch

	mov	al,12		;clear screen
	call	display
	mov	scrnum,99	;signal 'clrhelp' that we mucked screen
	call	dirstart0	;print header 1
	call	freespace	;print free space left on disk
	call	pdir		;print formatted directory entry

;	search for next entry
dirlp:	mov	ah,4fh
	int	21h
	jc	dirlperr

	call	pdir		;print directory entry
	jmp	dirlp

dirlperr: cmp	  al,18 	;file not found?
	je	direx		;yes -- all done
	call	fsetmsg
	jmp	direx4

direx:	mov	cx,18
	sub	ah,ah
	mov	al,dircnt
	div	five
	sub	ah,ah		;ignore remainder
	sub	cx,ax		;print enough lfs to get near bottom of screen
	js	direx3		;no lfs if we had more than 18
	jcxz	direx3

direx2: mov	al,10
	call	display
	loop	direx2

direx3: call	dirend		;print "Type command or..."
	mov	msgnum,26	;"Ready for command msg
	and	cmdflg,255-cmderr	;clear error flag

direx4: mov	al,oldwin	;switch back to old window
	call	wswitch

	pop	es
	pop	si
	pop	di
	pop	dx
	pop	cx
	pop	ax
	ret
cmdir	endp


;------ freespace: print freespace left on disk
freespace	proc	near
	push	ax
	push	bx
	push	cx
	push	dx
	push	bp
	push	si
	push	di

;	get freespace units  (DOS 2.0 and later
fr1:	mov	dl,driveno
	mov	ah,36h		;get disk freespace
	int	21h

;	calculate free bytes
	mul	bx		;ax*bx
	mul	cx

;	we now have result in ax,dx
;	print result
frprt:	mov	di,dx
	mov	si,ax
	call	printdd
	call	dirstart1	;print trailing "bytes left" message
				;print drive letter
	mov	al,driveno
	or	al,al
	jz	frprt2		;go find out default
	dec	al		;make origin 0 (0 =a, etc)
	jmp	frprt3

frprt2: mov	ah,19h
	int	21h		;get current disk drive into al

frprt3: add	al,'A'
	call	display
	mov	al,':'
	call	display
	call	dirstart2
frex:
	pop	di
	pop	si
	pop	bp
	pop	dx
	pop	cx
	pop	bx
	pop	ax
	ret
freespace	endp

;------ printdd
printdd proc	near		;prints a 32 bit integer in di:si
	xor	ax,ax		;zero out the
	mov	bx,ax		; working
	mov	bp,ax		; registers.

;	the following converts a binary number in di:si into a
;	packed decimal number in bx:bp

	mov	cx,32
j1:	shl	si,1
	rcl	di,1

	xchg	bp,ax
	call	j6
	xchg	bp,ax

	xchg	bx,ax
	call	j6
	xchg	bx,ax

	adc	al,0
	loop	j1

;	bx:bp now contain the decimal equivalent

	mov	cx,1710h	;values for leading blank suppression

	mov	ax,bx		;first, output values in bx
	call	j2
	mov	ax,bp		;second, output values in bp

j2:	push	ax
	mov	dl,ah		;first do al
	call	j3
	pop	dx		;then do ah

j3:	mov	dh,dl		;first do high nibble...
	shr	dl,1
	shr	dl,1
	shr	dl,1
	shr	dl,1
	call	j4
	mov	dl,dh		;then do low nibble

;	this routine actually prints a nibble...
j4:	and	dl,0fh		;mask low nibble
	jz	j5		;strip the first 7 leading zeros
	mov	cl,0		;if we get here, we're no longer printing 0s
j5:	dec	ch		; after 7 zeros, drops below 10h
				; remember cl starts with value 10h
	and	cl,ch
				;cl is now either 10h or 0

	or	dl,'0'          ;fold in ascii zero (value 48 is in hi nibble
	sub	dl,cl		; subtract possible 16 from possible 48
				; to give value of 32 = stripped blank

	mov	al,dl
	call	display        ;note assumption that we've already called
				; qsetup

	ret			;exit to caller
printdd endp

j6	proc	near		; double the (decimal) number in al,
	adc	al,al		;overflowing into ah if carry
	daa
	xchg	al,ah		; now double the number in ah
	adc	al,al
	daa
	xchg	al,ah
	ret
j6	endp

;------ pdir: print formatted directory entry from fcb entry in dta
pdir	proc	near
	push	ax
	push	si
	push	cx

	mov	si,offset dirmap.dname
	sub	cx,cx

dplp1:	lodsb
	cmp	al,32		;blank?
	jb	pdext		;done w/fname
	call	display
	inc	cx
	jmp	dplp1

pdext:
	test	dirmap.dattr,10h  ;directory file
	jz	pdx1		;no
	mov	al,'<'          ;yup -- add directory suffix
	call	display
	mov	al,'D'
	call	display
	mov	al,'I'
	call	display
	mov	al,'R'
	call	display
	mov	al,'>'
	call	display
	add	cx,5

pdx1:	cmp	cx,8		;if we printed less than 8 chrs, then 2 tabs
	jae	pdx2
	mov	al,9		;add extra tab
	call	display

pdx2:	mov	al,9		;tab over
	call	display
	inc	dircnt

pdx3:	pop	cx
	pop	si
	pop	ax
	ret
pdir	endp

;------ ferase: erase file pointed to by ds:si
ferase	proc	near
	push	ax
	push	cx
	push	dx
	push	si
	push	es
	push	di

	or	cmdflg,cmderr	;assume error

	mov	dx,si		;new calls expect string in dx

;	make sure user didn't type ERASE *.*
	call	fparse
	call	qstarstar
	jnc	ferok
	mov	msgnum,70	;global erase not allowed
	jmp	ferx


ferok:
	push	dx
	mov	dx,offset dirmap ;get dta address
	mov	ah,1ah		;set dta subcode
	int	21h
	pop	dx

	mov	cx,0		;no attributes
;	search for first entry
	mov	ah,4eh
	int	21h
	jc	ferr1

;	ERASE HERE
	mov	dx,offset dirmap.dname
	call	appfname			;add prefix (drive, path)
	mov	ah,41h				;erase
	int	21h
	jc	ferr1

;	search for next entry
eralp:	mov	ah,4fh
	int	21h
	jc	ferr			;normal exit when all is done...

;	ERASE HERE
	mov	dx,offset dirmap.dname
	call	appfname			;add prefix (drive, path)
	mov	ah,41h			;erase
	int	21h
	jc	ferr1

	jmp	eralp

ferr1:	call	fsetmsg
	jmp	ferx

ferr:	cmp	al,18			;file not found?
	jne	ferr1			;no -- real error
	mov	msgnum,71		;"file erased ok"
	and	cmdflg,255-cmderr	;no error after all

ferx:	pop	di
	pop	es
	pop	si
	pop	dx
	pop	cx
	pop	ax
	ret
ferase	endp


;------ seldrive: si points to string; select new drive
;	set carry if error
seldrive	proc	near
	push	ax
	push	dx

	mov	dx,si			;fparse expects it in dx

	call	fparse
	call	qdriveno		;get drive into al

	mov	msgnum,23		;invalid command option
	or	al,al			;disallow zero
	stc
	jz	selx

	mov	dl,al

	push	dx
	dec	dl			;a = 0, etc.
	mov	ah,0eh			;select disk
	int	21h
	pop	dx

	mov	msgnum,68		;invalid drive
	cmp	dl,al
	stc
	ja	selx			;error -- disk doesn't exist

	mov	msgnum,40		 ;ok
	clc
selx:
	pop	dx
	pop	ax
	ret
seldrive	endp

;------ frename: si point to string (like dos rename argument)
;	set carry if error
frename proc	near
	push	ax
	push	dx
	push	di
	push	es

	mov	dx,si		;point to string

fren1:	lodsb
	cmp	al,32
	ja	fren1		;find separator

	mov	msgnum,27	;missing command option
	or	al,al		;terminator?
	stc
	jz	frenx		;yup  -- error

	mov	byte ptr [si-1],0	;blast in a terminator
	push	ax			;save original char

	mov	di,si		;point to rest of string
	push	ds
	pop	es

	mov	msgnum,40	;ok
	mov	ah,56h		;rename
	int	21h
	jnc	frenx1
	call	fsetmsg
	stc

frenx1: pop	ax			 ;retrieve old character
	mov	byte ptr [si-1],al	 ;restore it

frenx:

	pop	es
	pop	di
	pop	dx
	pop	ax
	ret
frename endp


;------ chdir: si points to new directory
;	set carry if error
chdir	proc	near
	push	ax
	push	dx

	mov	dx,si
	mov	ah,3bh
	int	21h
	mov	msgnum,40		;ok
	jnc	chdx
	call	fsetmsg
	stc
chdx:
	pop	dx
	pop	ax
	ret
chdir	endp


; old dos 1.1 freespace code... (not needed)
xxx proc near
	;check if dos 2.0 (or later)

	mov	ah,30h		;get dos versio
	int	21h
	cmp	al,2		;release 2 or later?
;	jae	fr1
;	dos 1.0 and 1.1 ...
	mov	ah,19h
	int	21h		;get current disk drive
	mov	curdisk,al	;and remember

	mov	dl,driveno	;if spec = 0
	or	dl,dl
	jz	fre0		;leave default
	dec	dl		;change origin to a=0, b=1, etc

	mov	ah,0eh		;select specified disk
	int	21h

fre0:	push	ds
	mov	ah,1bh		;get fat address in memory
	int	21h		;ds:si points to fat

	mov	ah,0		;al = sector size
	xchg	cx,dx		;sector size times the
	mul	dx		; # sectors/cluster
	push	ax		;save cluster size
	xor	ax,ax		;unused clusters = 0
	mov	si,2		;skip first 3 clusters
e1:	mov	di,si		;di <- cluster #
	shr	di,1		;divide cluster number
	add	di,si		; by 1.5
	mov	di,[bx+di]	;fetch from fat
	test	si,1		;test if even or odd
	jz	e2		;if even then skip
	shr	di,1		; else if odd
	shr	di,1		;  right justify the
	shr	di,1		;  cluster number.
	shr	di,1
e2:	and	di,0fffh	;mask the low 12 bits
	jnz	e3		;if not 0 then skip, else
	inc	ax		; increment counter.
e3:	inc	si		;point to next cluster
	loop	e1		; and go check it.
	pop	cx		;get cluster size, times
	mul	cx		;  # of free clusters
	pop	ds

	push	ax
	push	dx
	mov	ah,0eh		;reset current disk
	mov	dl,curdisk
	int	21h
	pop	dx
	pop	ax

xxx endp

cm_code ends
end
