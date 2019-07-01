	public	fsave		;save current parameters
	public	doqval		;put current parm into queue

string	macro  label,astring
label	dw	label&z-label&a
label&a db	astring
label&z db	?
	endm

swrite	macro	astring
	mov	si,offset astring
	call	pswrite
	endm


cm_data segment public 'code'

allocate = 0
include data.pub

saveflg db	0
qvflg	equ	1			;doqval procedure active

	string	flowc,'flow'
	string	baudc,'baud'
	string	b110c,'110'
	string	b150c,'150'
	string	b300c,'300'
	string	b600c,'600'
	string	b1200c,'1200'
	string	b2400c,'2400'
	string	b4800c,'4800'
	string	b9600c,'9600'
	string	parityc,'parity'
	string	spacec,'space'
	string	markc,'mark'
	string	evenc,'even'
	string	oddc,'odd'
	string	echoc,'echo'
	string	autolfc,'autolf'
	string	protocolc,'protocol'
	string	obeyc,'obey'
	string	sendc,'send'
	string	bothc,'both'
	string	rtsc,'rts'
	string	filterc,'filter'
	string	prefixc,'prefix'
	string	numc,'number'
	string	suffixc,'suffix'
	string	tcharc,'tchar'
	string	twaitc,'twait'
	string	expandc,'expand'
	string	enterc,'enter'
	string	bsc,'bs'
	string	onc,'on'
	string	offc,'off'
	string	definec,'define'
	string	f1c,'f1'
	string	f2c,'f2'
	string	f3c,'f3'
	string	f4c,'f4'
	string	f5c,'f5'
	string	f6c,'f6'
	string	f7c,'f7'
	string	f8c,'f8'
	string	f9c,'f9'
	string	f10c,'f10'
	string	s1c,'s1'
	string	s2c,'s2'
	string	s3c,'s3'
	string	s4c,'s4'
	string	s5c,'s5'
	string	s6c,'s6'
	string	s7c,'s7'
	string	s8c,'s8'
	string	s9c,'s9'
	string	s10c,'s10'
	string	clockc,'clock'
	string	colorc,'color'
	string	answerc,'answer'
	string	sprefixc,'sprefix'
	string	ssuffixc,'ssuffix'
	string	discc,'disconnect'
	string	connc,'connect'
	string	cherc,'character'
	string	cmerc,'command'
	string	timec,'timeout'
	string	ringc,'ring'
	string	breakc,'break'
	string	timeoutc,'timeout'
	string	retriesc,'retries'
	string	portc,'port'
	string	kermitc,'kermit'
	string	xmodemc,'xmodem'
	string	chatterc,'chatter'
	string	debugc,'debug'
	string	eofc,'eof'
	string	binaryc,'binary'
	string	textc,'text'
	string	termc,'term'
	string	ansic,'vt100'
	string	maic,'mai'
	string	nihc,'nih'
	string	dosc,'dos'
	string	cursorc,'cursor'
	string	localc,'local'
	string	tabsc,'tabs'
	string	vt52c,'vt52'
	string	windowc,'window'
	string	routec,'route'
	string	receivedc,'received'
	string	sentc,'sent'
	string	allc,'all'
	string	screenc,'screen'
	string	normalc,'normal'
	string	mutec,'mute'
	string	graphicc,'graphic'
	string	ti931c,'ti931'


cm_data ends

cm_code segment public 'code'
assume	cs: cm_code
assume	ds: cm_data

extrn	putstring:near,wswitch:near,qaddchr:near
extrn	sfsetup:near,sfwrite:near,savclose:near
extrn	cisit:near,endchk:near

;------ save parameters to file
;	on entry, ds:si points to filename string
fsave	proc	near

	call	sfsetup

	call	saveit			;write parms to file

	call	savclose		;close file

	ret
fsave	endp

;------ doqval: parse parm pointed to by si, place value of parm into queue
doqval	proc	near
	push	ax
	push	bx

	or	saveflg,qvflg

	isit	docrsr,cursor,1
	isit	doeof,eof,3
	isit	dochat,chatter,5
	isit	doport,port,7
	isit	doprot,protocol,9
	isit	doret,retries,11
	isit	dotim,time,13
	isit	doclk,clock,15
	isit	doexp,expand,17
	isit	dotab,tabs,19
	isit	doterm,term,21
	isit	dotwait,twait,23
	isit	dotchar,tchar,25
	isit	dofilter,filter,27
	isit	doflow,flow,29
	isit	doauto,autolf,31
	isit	doecho,echo,33
	isit	dopar,parity,35
	isit	dobaud,baud,37
	isit	docolor,color,39
	isit	dowindow,window,41
	isit	doroute,route,43
	isit	doscreen,screen,45
	isit	donumber,number,47
	isit	doprefix,prefix,49
	isit	dosuffix,suffix,73
	isit	dof1,f1,51
	isit	dof2,f2,52
	isit	dof3,f3,53
	isit	dof4,f4,54
	isit	dof5,f5,55
	isit	dof6,f6,56
	isit	dof7,f7,57
	isit	dof8,f8,58
	isit	dof9,f9,59
	isit	dof10,f10,60
	isit	dos1,s1,61
	isit	dos2,s2,62
	isit	dos3,s3,63
	isit	dos4,s4,64
	isit	dos5,s5,65
	isit	dos6,s6,66
	isit	dos7,s7,67
	isit	dos8,s8,68
	isit	dos9,s9,69
	isit	dos10,s10,70
	isit	doring,ring,71
	isit	doans,answer,72
	isit	doenter,enter,74
	isit	dobs,bs,75

	and	saveflg,255-qvflg	;error -- parm not found
	stc
	jmp	doqx2

docrsr:  call	qvcursor
	jmp	doqx
doeof:	call	qveof
	jmp	doqx
dochat: call	qvchatter
	jmp	doqx
doport: call	qvport
	jmp	doqx
doprot: call	qvprotocol
	jmp	doqx
doret:	call	qvretries
	jmp	doqx
dotim:	call	qvtime
	jmp	doqx
doclk:	call	qvclock
	jmp	doqx
doexp:	call	qvexpand
	jmp	doqx
dotab:	call	qvtabs
	jmp	doqx
doterm: call	qvterm
	jmp	doqx
dotwait: call	qvtwait
	jmp	doqx
dotchar: call	qvtchar
	jmp	doqx
dofilter: call	qvfilter
	jmp	doqx
doflow: call	qvflow
	jmp	doqx
doauto: call	qvautolf
	jmp	doqx
doecho: call	qvecho
	jmp	doqx
dopar:	call	qvparity
	jmp	doqx
dobaud: call	qvbaud
	jmp	doqx
docolor: call	qvcolor
	jmp	doqx
dowindow: call	qvwindow
	jmp	doqx
doroute: call	qvroute
	jmp	doqx
doscreen: call	qvscreen
	jmp	doqx
donumber: mov	al,dpfnum
	call	qvstring
	jmp	doqx
doprefix: mov	al,dpfpr
	call	qvstring
	jmp	doqx
dosuffix: mov	al,dpfsuf
	call	qvstring
	jmp	doqx
dof1:	mov	al,dpf1
	call	qvstring
	jmp	doqx
dof2:	mov	al,dpf2
	call	qvstring
	jmp	doqx
dof3:	mov	al,dpf3
	call	qvstring
	jmp	doqx
dof4:	mov	al,dpf4
	call	qvstring
	jmp	doqx
dof5:	mov	al,dpf5
	call	qvstring
	jmp	doqx
dof6:	mov	al,dpf6
	call	qvstring
	jmp	doqx
dof7:	mov	al,dpf7
	call	qvstring
	jmp	doqx
dof8:	mov	al,dpf8
	call	qvstring
	jmp	doqx
dof9:	mov	al,dpf9
	call	qvstring
	jmp	doqx
dof10:	mov	al,dpf10
	call	qvstring
	jmp	doqx
dos1:	mov	al,dpfs1
	call	qvstring
	jmp	doqx
dos2:	mov	al,dpfs2
	call	qvstring
	jmp	doqx
dos3:	mov	al,dpfs3
	call	qvstring
	jmp	doqx
dos4:	mov	al,dpfs4
	call	qvstring
	jmp	doqx
dos5:	mov	al,dpfs5
	call	qvstring
	jmp	doqx
dos6:	mov	al,dpfs6
	call	qvstring
	jmp	doqx
dos7:	mov	al,dpfs7
	call	qvstring
	jmp	doqx
dos8:	mov	al,dpfs8
	call	qvstring
	jmp	doqx
dos9:	mov	al,dpfs9
	call	qvstring
	jmp	doqx
dos10:	mov	al,dpfs10
	call	qvstring
	jmp	doqx
doenter: mov	 al,dpfent
	call	qvstring
	jmp	doqx
dobs:	mov	al,dpfbs
	call	qvstring
	jmp	doqx
doans:	mov	al,dpfa
	call	qvstring
	jmp	doqx
doring: mov	al,dpfring
	call	qvstring
	jmp	doqx

doqx:	and	saveflg,255-qvflg
	clc
doqx2:
	pop	bx
	pop	ax
	ret
doqval	endp

;------ saveit: write parms to file
saveit	proc	near
	push	ax
	push	bx
	push	cx
	push	si

	swrite	termc
	call	qvterm
	call	crwrite

	swrite	windowc
	call	qvwindow
	call	crwrite

	swrite	colorc
	call	qvcolor
	call	crwrite

	swrite	baudc
	call	qvbaud
	call	crwrite

	swrite	parityc
	call	qvparity
	call	crwrite

	swrite	echoc
	call	qvecho
	call	crwrite

	swrite	autolfc
	call	qvautolf
	call	crwrite

	swrite	flowc
	call	qvflow
	call	crwrite

	swrite	filterc
	call	qvfilter
	call	crwrite

	swrite	tcharc
	call	qvtchar
	call	crwrite

	swrite	twaitc
	call	qvtwait
	call	crwrite

	swrite	tabsc
	call	qvtabs
	call	crwrite

	swrite	expandc
	call	qvexpand
	call	crwrite

						;what about defines????
	swrite	definec
	swrite	prefixc
	mov	al,dpfpr
	call	qvstring
	call	crwrite

	swrite	definec
	swrite	numc
	mov	al,dpfnum
	call	qvstring
	call	crwrite

	swrite	definec
	swrite	suffixc
	mov	al,dpfsuf
	call	qvstring
	call	crwrite

	swrite	definec
	swrite	f1c
	mov	al,dpf1
	call	qvstring
	call	crwrite

	swrite	definec
	swrite	f2c
	mov	al,dpf2
	call	qvstring
	call	crwrite

	swrite	definec
	swrite	f3c
	mov	al,dpf3
	call	qvstring
	call	crwrite

	swrite	definec
	swrite	f4c
	mov	al,dpf4
	call	qvstring
	call	crwrite

	swrite	definec
	swrite	f5c
	mov	al,dpf5
	call	qvstring
	call	crwrite

	swrite	definec
	swrite	f6c
	mov	al,dpf6
	call	qvstring
	call	crwrite

	swrite	definec
	swrite	f7c
	mov	al,dpf7
	call	qvstring
	call	crwrite

	swrite	definec
	swrite	f8c
	mov	al,dpf8
	call	qvstring
	call	crwrite

	swrite	definec
	swrite	f9c
	mov	al,dpf9
	call	qvstring
	call	crwrite

	swrite	definec
	swrite	f10c
	mov	al,dpf10
	call	qvstring
	call	crwrite

	swrite	definec
	swrite	s1c
	mov	al,dpfs1
	call	qvstring
	call	crwrite

	swrite	definec
	swrite	s2c
	mov	al,dpfs2
	call	qvstring
	call	crwrite

	swrite	definec
	swrite	s3c
	mov	al,dpfs3
	call	qvstring
	call	crwrite

	swrite	definec
	swrite	s4c
	mov	al,dpfs4
	call	qvstring
	call	crwrite

	swrite	definec
	swrite	s5c
	mov	al,dpfs5
	call	qvstring
	call	crwrite

	swrite	definec
	swrite	s6c
	mov	al,dpfs6
	call	qvstring
	call	crwrite

	swrite	definec
	swrite	s7c
	mov	al,dpfs7
	call	qvstring
	call	crwrite

	swrite	definec
	swrite	s8c
	mov	al,dpfs8
	call	qvstring
	call	crwrite

	swrite	definec
	swrite	s9c
	mov	al,dpfs9
	call	qvstring
	call	crwrite

	swrite	definec
	swrite	s10c
	mov	al,dpfs10
	call	qvstring
	call	crwrite

	swrite	definec
	swrite	enterc
	mov	al,dpfent
	call	qvstring
	call	crwrite

	swrite	definec
	swrite	bsc
	mov	al,dpfbs
	call	qvstring
	call	crwrite

	swrite	definec
	swrite	answerc
	mov	al,dpfa
	call	qvstring
	call	crwrite

;	swrite	definec
;	swrite	sprefixc
;	mov	al,dpfspre
;	call	qvstring
;	call	crwrite
;
;	swrite	definec
;	swrite	ssuffixc
;	mov	al,dpfssuf
;	call	qvstring
;	call	crwrite
;
;	swrite	definec
;	swrite	discc
;	mov	al,dpfdisc
;	call	qvstring
;	call	crwrite
;
;	swrite	definec
;	swrite	connc
;	mov	al,dpfconn
;	call	qvstring
;	call	crwrite
;
;	swrite	definec
;	swrite	cherc
;	mov	al,dpfcher
;	call	qvstring
;	call	crwrite
;
;	swrite	definec
;	swrite	cmerc
;	mov	al,dpfcmer
;	call	qvstring
;	call	crwrite
;
;	swrite	definec
;	swrite	timec
;	mov	al,dpftime
;	call	qvstring
;	call	crwrite

	swrite	definec
	swrite	ringc
	mov	al,dpfring
	call	qvstring
	call	crwrite

;	swrite	definec
;	swrite	breakc
;	mov	al,dpfbrk
;	call	qvstring
;	call	crwrite
;
;	swrite	definec
;	swrite	protocolc
;	mov	al,dpfprot
;	call	qvstring
;	call	crwrite

	swrite	clockc
	call	qvclock
	call	crwrite

	swrite	timeoutc
	call	qvtime
	call	crwrite

	swrite	retriesc
	call	qvretries
	call	crwrite

	swrite	protocolc
	call	qvprotocol
	call	crwrite

	swrite	portc
	call	qvport
	call	crwrite

	swrite	chatterc
	call	qvchatter
	call	crwrite

	swrite	eofc
	call	qveof
	call	crwrite

	swrite	cursorc
	call	qvcursor
	call	crwrite

	pop	si
	pop	cx
	pop	bx
	pop	ax
	ret
saveit	endp

;------ bwrite: basic write...to either file or queue, depends on flag
;	char in al
bwrite	proc	near
	test	saveflg,qvflg
	jz	bwf
	call	qaddchr 		;add to queue
	jmp	bwx

bwf:	call	sfwrite 		;write to file
bwx:
	ret
bwrite	endp

;------ pswrite: write string pointed to by si, followed by blank
pswrite proc	near
	mov	cx,[si] 	;get length
	add	si,2		;point to first char

psw0:	lodsb
	call	bwrite
	loop	psw0
	mov	al,' '
	call	bwrite
	ret
pswrite endp

;------ crwrite: write cr-lf to file
crwrite proc	near
	mov	al,13
	call	bwrite
	mov	al,10
	call	bwrite
	ret
crwrite endp

ten	db	10		;divisor
;------ wrnum: write decimal number currently in al
;	number positive and less then 999
;	follow w/ a blank
wrnum	proc	near
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

	mov	al,dl
	call	bwrite
	mov	al,cl
	call	bwrite
	mov	al,bl
	call	bwrite

	mov	al,' '
	call	bwrite

	pop	dx
	pop	cx
	pop	bx
	pop	ax
	ret
wrnum	endp

;------ wcntrl: write character in al, converting to ^ format if necessary
wcntrl	proc	near
	push	ax
	push	bx

	cmp	al,127
	je	pcnt
	cmp	al,32
	jbe	pcnt
	jmp	pcnt1		;display without ado

pcnt:	push	ax
	mov	al,'^'          ;escape prefix
	call	bwrite
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
pcnt1:	call	bwrite

	pop	bx
	pop	ax
	ret
wcntrl	endp

;----------------
; qv... procedures: write the value of command to file/queue
;	ax,bx can be used; others must be preserved

qvterm	proc	near
	cmp	termtype,tty
	jne	term1
	swrite	normalc
	jmp	termx

term1:	cmp	termtype,mai
	jne	term2
	swrite	maic
	jmp	termx

term2:	cmp	termtype,nih
	jne	term3
	swrite	nihc
	jmp	termx

term3:	cmp	termtype,ansi
	jne	term4
	swrite	ansic
	jmp	termx

term4:	cmp	termtype,dost
	jne	term5
	swrite	dosc
	jmp	termx

term5:	cmp	termtype,vt52
	jne	term8
	swrite	vt52c
	jmp	termx

term8:	cmp	termtype,ti931
	jne	term9
	swrite	ti931c
	jmp	termx

term9:
termx:
	ret
qvterm	endp


qvwindow proc	near
	mov	bl,wndc_id
	mov	al,1
	call	wswitch 		;switch to main window
	mov	al,wndc_tr
	call	wrnum
	mov	al,wndc_br
	call	wrnum
	mov	al,bl			;recover window
	call	wswitch
	ret
qvwindow endp


qvcolor proc	near
	mov	al,nattr_val
	call	wrnum
	mov	al,bckgrnd_val
	call	wrnum
	mov	al,hilite_val
	call	wrnum
	mov	al,reverse_val
	call	wrnum
	mov	al,reverseb_val
	call	wrnum
	mov	al,border_val
	call	wrnum
	ret
qvcolor endp

qvbaud	proc	near
	mov	ax,bamsg
	cmp	ax,43
	je	ba1
	cmp	ax,44
	je	ba2
	cmp	ax,45
	je	ba3
	cmp	ax,46
	je	ba4
	cmp	ax,47
	je	ba5
	cmp	ax,48
	je	ba6
	cmp	ax,49
	je	ba7
	cmp	ax,50
	je	ba8
;	that's all, folks...
	jmp	bax

ba1:	swrite	b110c
	jmp	bax
ba2:	swrite	b150c
	jmp	bax
ba3:	swrite	b300c
	jmp	bax
ba4:	swrite	b600c
	jmp	bax
ba5:	swrite	b1200c
	jmp	bax
ba6:	swrite	b2400c
	jmp	bax
ba7:	swrite	b4800c
	jmp	bax
ba8:	swrite	b9600c
	jmp	bax

bax:	ret
qvbaud	endp


qvparity proc	near
	mov	ax,pamsg
	cmp	ax,36
	je	pa1
	cmp	ax,35
	je	pa2
	cmp	ax,37
	je	pa3
	cmp	ax,38
	je	pa4
	cmp	ax,39
	je	pa5
;	no more
	jmp	pax

pa1:	swrite	evenc
	jmp	pax
pa2:	swrite	oddc
	jmp	pax
pa3:	swrite	spacec
	jmp	pax
pa4:	swrite	markc
	jmp	pax
pa5:	swrite	offc
	jmp	pax

pax:	 ret
qvparity endp


qvecho	proc	near
	test	parmf,hecho
	jnz	ec1
	swrite	onc
	jmp	ec2
ec1:	swrite	offc
ec2:	ret
qvecho	endp


qvautolf proc	near
	test	parmf,autolf
	jnz	au1
	swrite	offc
	jmp	au2
au1:	swrite	onc
au2:	ret
qvautolf	endp


qvflow	proc	near
	test	parm4,protrts
	jnz	pr3a
	test	parmf,protxon+protxont
	jz	pr1			;off
	jp	pr2			;both
	test	parmf,protxon
	jnz	pr3			;send
	swrite	obeyc			;obey
	jmp	pr4
pr1:	swrite	offc
	jmp	pr4
pr2:	swrite	bothc
	jmp	pr4
pr3:	swrite	sendc
	jmp	pr4
pr3a:	swrite	rtsc
pr4:	ret
qvflow	endp


qvfilter proc	near
	test	parmf,nofilt
	jnz	fi1
	swrite	onc
	jmp	fi2
fi1:	swrite	offc
fi2:	 ret
qvfilter endp


qvtchar proc	near
	test	parmf,ltcon
	jnz	tc1
	swrite	offc
	jmp	tcx
tc1:	mov	al,turnchr
	call	wcntrl
tcx:	ret
qvtchar endp


qvtwait proc	near
	mov	al,twtime
	call	wrnum
	ret
qvtwait endp


qvtabs	proc	near
	push	cx
	push	si
	mov	cx,80
	sub	al,al
	mov	si,offset tabarray
tabs1:	cmp	byte ptr [si],0
	je	tabs2
	call	wrnum
tabs2:	inc	al
	inc	si
	loop	tabs1
	pop	si
	pop	cx
	ret
qvtabs	endp

qvexpand proc	near
	test	parm2,expand
	jnz	exp1
	swrite	offc
	jmp	exp2
exp1:	swrite	onc
exp2:	 ret
qvexpand endp

qvclock proc	near
	test	parm2,clkoff
	jnz	ck1
	swrite	onc
	jmp	ck2
ck1:	swrite	offc
ck2:	ret
qvclock endp

qvtime	proc	near
	mov	al,timeout
	call	wrnum
	ret
qvtime	endp

qvretries proc	near
	mov	al,maxretry
	call	wrnum
	ret
qvretries endp


qvprotocol proc near
	test	parm3,xmodem
	jz	pro1
	swrite	xmodemc
	jmp	pro3
pro1:	test	parm3,kermit
	jz	pro2			;internal error
	swrite	kermitc
pro2:
pro3:	ret
qvprotocol	endp

qvport	proc	near
	mov	al,commport
	call	wrnum
	ret
qvport	endp


qvchatter proc	near
	cmp	chatter,chat_on
	jne	cha1
	swrite	onc
	jmp	cha5
cha1:	cmp	chatter,chat_off
	jne	cha2
	swrite	offc
	jmp	cha5
cha2:	cmp	chatter,chat_bug
	jne	cha3
	swrite	debugc
	jmp	cha5
cha3:
cha5:	ret
qvchatter endp

qveof	proc	near
	test	parm4,binfile
	jz	bin2
	swrite	binaryc
	jmp	bin3
bin2:	swrite	textc
bin3:	ret
qveof	endp


qvcursor proc	near
	test	parm4,crsend
	jz	crs1
	swrite	sendc
	jmp	crs2
crs1:	swrite	localc
crs2:	ret
qvcursor endp

;	note: either routeh, routek, or both are on
qvroute proc	near
	test	parm2,routeh
	jz	rouk
	test	parm2,routek
	jz	rouh
	swrite	allc
	jmp	roux
rouk:	swrite	sentc
	jmp	roux
rouh:	swrite	receivedc
roux:	ret
qvroute endp

qvscreen proc	near
	test	parm3,screen
	jnz	scr1
	swrite	mutec
	jmp	scrx
scr1:	test	parm3,graph
	jz	scr2
	swrite	graphicc
	jmp	scrx
scr2:	swrite	normalc
scrx:	ret
qvscreen endp

qvstring proc near
	mov	bx,offset cm_code:bwrite
	call	putstring
	ret
qvstring endp

cm_code ends
	end
