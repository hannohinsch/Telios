;------ extended parse functions
;	(C) Copyright 1984  Hanno Hinsch

	public	parsex
	public	qnxchr
	public	qaddchr
	public	qflush
	public	execlabel
	public	trprocess

cm_data segment public 'code'

allocate = 0
include data.pub

qa	db	512 dup(?)
qz	equ	this byte

qhead	dw	offset qa
qtail	dw	offset qa

labelstring	db	50 dup (?)

hicase	db	0			;highest active "case" stmt
maxcase equ	9			;highest case we can handle

case	struc
 captr	dw	0
 cawild db	0
 castring db	253 dup (?)
case	ends

case0	case <>
case1	case <>
case2	case <>
case3	case <>
case4	case <>
case5	case <>
case6	case <>
case7	case <>
case8	case <>
case9	case <>

cm_data ends


cm_code segment  public 'code'

assume	cs: cm_code
assume	ds: cm_data

extrn	nxchr:near,cisit:near,endchk:near,numscan:near,scanb:near
extrn	getkline:near,pmsg:near,setupd:near,tadd_sec:near,cm_cd:near
extrn	unseq:near,wswitch:near,setcrsr:near,emisint:near,doqval:near
extrn	bufwindow:near,ke_init:near
extrn	stosetup:near,stowrite:near,stoclose:near

;------ parsex: implement extended file commands
;	if no command found, set msg
;	at entry, si --> first char of cmnd
parsex	proc	near
	isit	emisc,emis,0
	isit	goto,goto,1
	isit	ifcm,if,2
	isit	qck,qcheck,3
	isit	qfl,qflush,5
	isit	qin,qinput,7
	isit	qmatch,qmatch,9
	isit	qval,qvalue,11
	isit	shortcm,tr,13		;disallow "tr"
	isit	tbegin,trbegin,15
	isit	tcase,trcase,17
	isit	tend,trend,19
	isit	window_def,window,21
	isit	ksop,ksop,23

unknown: mov	 msgnum,22			 ;unknown command
	or	cmdflg,cmderr
	jmp	cpx

unknownp: mov	msgnum,23		;unknown parameter
	or	cmdflg,cmderr
	jmp	cpx

missp:	mov	msgnum,27		;missing parameter
	or	cmdflg,cmderr
	jmp	cpx

excessp: mov	msgnum,69		;too many command options
	or	cmdflg,cmderr
	jmp	cpx

shortcm: mov	msgnum,136		;abbreviation too short
	or	cmdflg,cmderr
	jmp	cpx

nofile: mov	msgnum,137		;no file specified
	or	cmdflg,cmderr
	jmp	cpx


;------ ksop: set kermit outgoing start of packet character
ksop:	call	scanb
	jnz	kso2
	jmp	missp

kso2:
;	if overrun, missing parm
	mov	al,[si] 	;can't use nxchr because it converts case
	inc	si
	or	al,al
	jnz	kso3
	jmp	missp

kso3:	cmp	al,'^'          ;escape (^) chr?
	jne	ksoset		;nope -- normal keybd char

	mov	al,[si] 	;get next char
	inc	si
	or	al,al
	jnz	kso4
	jmp	missp

kso4:	call	unseq		;decode ^ char in al
	jnc	ksoset
	jmp	unknownp	;not recognized

ksoset: call	endchkx

	call	ke_init 		;set char
	mov	msgnum,40		;ok msg
	jmp	cpx


;------ emisc: pass special emis commands to emis module
emisc:	test	parm4,emis		;emis variant?
	jnz	emis1
	jmp	unknown

emis1:	call	scanb
	jnz	emis2
	jmp	missp

emis2:	isit	emlnup,lnup,e1
	isit	emlndn,lndn,e2
	isit	empgup,pgup,e3
	isit	empgdn,pgdn,e4
	isit	emchf,flag,e5
	isit	emwhi,hi,e6
	isit	emwlo,lo,e7
	isit	emcol,color,e8
	isit	emtrxy,xy,e9
	isit	emtrsc,scroll,e10
	isit	emstr,store,e11

	call	numscan
	jnz	emis3
	jmp	unknownp

emis3:	call	endchkx

	mov	bl,al			;goto page #
	mov	al,8
	jmp	doemis

emlnup: call	endchkx
	mov	al,4			;line up
	jmp	doemis

emlndn: call	endchkx
	mov	al,5			;line down
	jmp	doemis

empgup: call	endchkx
	mov	al,6			;page up
	jmp	doemis

empgdn: call	endchkx
	mov	al,7
	jmp	doemis

emwhi:	call	endchkx 		;use hi window
	mov	al,12
	mov	bh,1
	jmp	doemis


emwlo:	call	endchkx 		;use low window
	mov	al,12
	mov	bh,0
	jmp	doemis


emtrxy: call	numscan 		;make entry into page table (xy)
	mov	ch,al			;displayed page num
	jnz	xy1
	jmp	missp

xy1:	call	numscan
	mov	bl,al			;transmitted page num (low order)
	jnz	xy2
	jmp	missp

xy2:	mov	bh,0			;transmitted page num (hi order)
	call	numscan
	jz	xy3
	mov	bh,al

xy3:	call	endchkx
	mov	al,11
	mov	cl,0			;indicate xy
	jmp	doemis


emtrsc: call	numscan 		;make entry into page table (scroll)
	mov	ch,al			;displayed page num
	jnz	tsc1
	jmp	missp

tsc1:	call	numscan
	mov	bl,al			;transmitted page num (lo order)
	jnz	tsc2
	jmp	missp

tsc2:	mov	bh,0			;transmitted pg num (hi order)
	call	numscan
	jz	tsc3
	mov	bh,al

tsc3:	call	endchkx
	mov	al,11
	mov	cl,1			;indicate scroll
	jmp	doemis

emcol:	call	numscan 		;set colors
	mov	bh,al			;foreground
	jnz	emc1
	jmp	missp

emc1:	call	numscan
	mov	bl,al			;background
	jnz	emc2
	jmp	unknownp

emc2:	call	numscan
	mov	ch,al			;change flag foreground
	jnz	emc3
	jmp	unknownp

emc3:	call	numscan
	mov	cl,al			;change flag background
	jnz	emc4
	jmp	unknownp

emc4:	call	endchkx
	mov	al,10
	jmp	doemis

emchf:	call	scanb			;control change flags
	jnz	emf0
	jmp	missp

emf0:	isit	emf1,pgclr,f0
	isit	emf2,on,f1
	isit	emf3,clr,f2
	isit	emf4,off,f3
	jmp	unknownp

emf1:	call	endchkx
	mov	al,9
	mov	bl,1		;page clear
	jmp	doemis

emf2:	call	endchkx
	mov	al,9
	mov	bl,2		;change flags on
	jmp	doemis

emf3:	call	endchkx
	mov	al,9
	mov	bl,3		;clear change flags
	jmp	doemis

emf4:	call	endchkx
	mov	al,9
	mov	bl,4		;change flags off
	jmp	doemis

emstr:	call	scanb		;store emis window
	jnz	ems2
	jmp	missp

ems2:	or	cmdflg,cmderr		;assume error
	call	emsbuf
	jc	emsx
	and	cmdflg,255-cmderr      ;no error found
emsx:	jmp	cpx

doemis: mov	msgnum,40		;default msg
	call	emisint 		;emis interrupt
	jnc	doemis2
	mov	msgnum,144		;handler not available
doemis2:jmp	cpx



;------ window: define size of main window
window_def:
	call	scanb
	jnz	wi1
	jmp	missp

wi1:	call	numscan 		;first arg (top)
	jnz	wi2
	jmp	unknownp

wi2:	mov	bl,al			;save first num
	call	numscan 		;second arg (bot)
	jnz	wi3
	jmp	unknownp

wi3:	call	endchkx
	mov	bh,al			;save second num

	cmp	bh,bl
	ja	wi4			;bot > top
	jmp	unknownp

wi4:	cmp	bh,23			;max window size
	jbe	wi5
	jmp	unknownp

wi5:	mov	cl,wndc_id		;save for exit
	mov	al,1
	call	wswitch

	mov	wndc_tr,bl
	mov	wndc_br,bh
	mov	scrnum,99		;force Telios window refresh

	mov	dh,bl			;home cursor
	mov	dl,wndc_lc
	call	setcrsr 		;to fake out wswitch

	call	bufwindow		;tell buffer about switch
	test	parm4,emis		;set up emis window?
	jz	wi6			;no
	push	cx
	mov	cl,wndc_lc
	mov	dl,wndc_rc
	mov	ch,0			;assume no room for window
	mov	dh,0

;	use top or bottom space (top has priority if both exist)
	cmp	wndc_tr,2		;do we have room at top?
	jae	wi8b			;yup
	cmp	wndc_br,21		;do we have room at bottom?
	jbe	wi8a			;yup
	jmp	wi5a			;no room

wi8a:	mov	dh,23			;bottom row
	mov	ch,wndc_br
	add	ch,2			;goto next row, and skip it
	jmp	wi5a			; (leave for tag line)

wi8b:	mov	ch,0			;top row always 0
	mov	dh,wndc_tr
	sub	dh,2			;emis bot = our top - 2

wi5a:	mov	al,3			;window select
	call	emisint
	pop	cx

wi6:	mov	al,cl			;recover window id
	call	wswitch
	mov	msgnum,143		;window size set
	jmp	cpx


;------ goto: jump to label
goto:	call	scanb
	jnz	goto1
	jmp	missp

goto1:	call	labchkx
	call	execgoto
	mov	msgnum,40		;"ok"
	jmp	cpx


;------ ifcm: do "if" command
ifcm:	call	scanb
	jnz	ifc1
ifcma:	call	missp

ifc1:	isit	ifc2,online,i1
	isit	ifc3,offline,i2
	jmp	unknownp

ifc2:	call	scanb
	jz	ifcma

	call	labchkx
	mov	msgnum,16		;assume offline
	call	cm_cd
	jc	ifcx			;we're offline, so no action
	call	execgoto
	mov	msgnum,15		;online msg
	jmp	cpx

ifc3:	call	scanb
	jz	ifcma

	call	labchkx
	mov	msgnum,15		;assume online
	call	cm_cd
	jnc	ifcx			;we're online, so no action
	call	execgoto
	mov	msgnum,16		;offline msg
	jmp	cpx

ifcx:	jmp	cpx

;------ qval: place current value of parm into queue
qval:	call	scanb
	jnz	qv1
	jmp	missp

qv1:	call	doqval
	jnc	qvx
	jmp	unknownp

qvx:	mov	al,' '                  ;delimiter
	call	qaddchr
	mov	msgnum,40		;ok
	jmp	cpx


;------ qcheck: jump to label, depending on # of words in queue
qck:	call	scanb
	jnz	qc0
	jmp	missp

qc0:
;	get number of words into dl
	cld
	sub	dx,dx		;initial word count

	push	si		;save arg pointer
	mov	si,qtail

;	skip leading blanks before word
qcl3c:	cmp	si,qhead
	je	qcl3g		;reached end of queue
	cmp	si,offset qz	;handle queue wrap
	jb	qcl3d
	mov	si,offset qa
qcl3d:	cmp	byte ptr [si],32
	ja	qcl3a
	inc	si
	jmp	qcl3c		;repeat till end of blanks

;	skip word
qcl3a:	cmp	si,qhead
	je	qcl3f		;reached end of queue
	cmp	si,offset qz	;handle queue wrap
	jb	qcl3b
	mov	si,offset qa
qcl3b:	cmp	byte ptr [si],32
	jbe	qcl3e
	inc	si
	jmp	qcl3a		;repeat till end of word

qcl3e:	inc	dl		;bump word count
	jmp	qcl3c		;do next word

qcl3f:	inc	dl		;reached end of queue on char
qcl3g:				;reached end of queue on blank

;	dl now contains word count
	pop	si		;restore pointer

	isit	qclt,lt,q1
	isit	qcle,le,q2
	isit	qceq,eq,q3
	isit	qcge,ge,q4
	isit	qcgt,gt,q5
	isit	qcne,ne,q6
	jmp	qc1			;check old-style

;LESS THAN
qclt:	call	numscan
	jnz	qclt1
	jmp	missp

qclt1:	call	scanb
	jnz	qclt1a
	jmp	missp

qclt1a: call	labchkx
	cmp	dl,al
	jb	qclt2
	jmp	qc5			;no action needed
qclt2:	jmp	qc6			;branch

;LESS THAN OR EQUAL
qcle:	call	numscan
	jnz	qcle1
	jmp	missp

qcle1:	call	scanb
	jnz	qcle1a
	jmp	missp

qcle1a: call	labchkx
	cmp	dl,al
	jbe	qcle2
	jmp	qc5			;no action needed
qcle2:	jmp	qc6			;branch

;EQUAL
qceq:	call	numscan
	jnz	qceq1
	jmp	missp

qceq1:	call	scanb
	jnz	qceq1a
	jmp	missp

qceq1a: call	labchkx
	cmp	dl,al
	je	qceq2
	jmp	qc5			;no action needed
qceq2:	jmp	qc6			;branch

;GREATER THAN OR EQUAL
qcge:	call	numscan
	jnz	qcge1
	jmp	missp

qcge1:	call	scanb
	jnz	qcge1a
	jmp	missp

qcge1a: call	labchkx
	cmp	dl,al
	jae	qcge2
	jmp	qc5			;no action needed
qcge2:	jmp	qc6			;branch

;GREATER THAN
qcgt:	call	numscan
	jnz	qcgt1
	jmp	missp

qcgt1:	call	scanb
	jnz	qcgt1a
	jmp	missp

qcgt1a: call	labchkx
	cmp	dl,al
	ja	qcgt2
	jmp	qc5			;no action needed
qcgt2:	jmp	qc6			;branch

;NOT EQUAL
qcne:	call	numscan
	jnz	qcne1
	jmp	missp

qcne1:	call	scanb
	jnz	qcne1a
	jmp	missp

qcne1a: call	labchkx
	cmp	dl,al
	jne	qcne2
	jmp	qc5			;no action needed
qcne2:	jmp	qc6			;branch

qc1:	; do old-style QCHECK <min> <max> -label  command....
	call	numscan 		;first arg (min)
	jnz	qc2
	jmp	unknownp

qc2:	mov	bl,al			;save first num
	call	numscan 		;second arg (max)
	jnz	qc3
	jmp	unknownp

qc3:	mov	cl,al			;save second arg
	call	scanb			;third arg
	jnz	qc4
	jmp	unknownp

qc4:	call	labchkx

	cmp	dl,bl		;smaller than min?
	jb	qc6
	cmp	dl,cl		; or bigger than max?
	ja	qc6

qc5:	mov	msgnum,40	;"ok"
	jmp	cpx		;nope -- no action needed

qc6:	call	execgoto
	mov	msgnum,40	;"ok"
qc7:	jmp	cpx


;------ qflush: flush input queue
;	if no arg, flush all; else flush specified number of words
qfl:	call	scanb
	jnz	qfl2
	mov	ax,qtail	;no arg means flush all
	mov	qhead,ax
	mov	msgnum,40	;ok
	jmp	cpx

qfl2:	call	numscan 	;get numeric arg
	jnz	qfl3
	jmp	unknownp	;bad arg

qfl3:	call	endchkx
	cld

	push	si		;save arg pointer
	sub	cx,cx
	mov	cl,al		;number of words to skip

	mov	si,qtail
	jcxz	qfl5

;	skip leading blanks
qfl3c:	cmp	si,qhead
	je	qfl5		;reached end of queue
	cmp	si,offset qz	;handle queue wrap
	jb	qfl3d
	mov	si,offset qa
qfl3d:
	cmp	byte ptr [si],32
	ja	qfl3a		;repeat till end of blanks
	inc	si
	jmp	qfl3c

;	skip word
qfl3a:	cmp	si,qhead
	je	qfl5		;reached end of queue
	cmp	si,offset qz	;handle queue wrap
	jb	qfl3b
	mov	si,offset qa
qfl3b:
	cmp	byte ptr [si],32
	jbe	qfl3e		;repeat till end of word
	inc	si
	jmp	qfl3a

qfl3e:	loop	qfl3c		;do next word

qfl5:	mov	qtail,si	;store new pointer
	pop	si
	mov	msgnum,40	;ok
	jmp	cpx


;------ qinput: add words to input queue
;	if no arg, get line from keyboard
qin:	push	si
	call	scanb
	jnz	qin3

	mov	msgnum,138		;prompt
	call	pmsg			;print prompt

	or	parm4,qinact		;let rdkeyb know, so kb accepted
	call	getkline		;get keyboard line
	and	parm4,255-qinact

	call	setupd			;flag command line refresh
	mov	si,offset cmdline

qin3:	call	nxchr			;si --> kboard line or cmnd line
	or	al,al
	jz	qin4
	call	qaddchr 		;add to queue
	jmp	qin3

qin4:	mov	al,' '                  ;delimiter
	call	qaddchr
	mov	msgnum,40		;ok
	pop	si
	jmp	cpx

;------ qmatch: search for specified string in input queue
qmatch: call	scanb
	jnz	qm1
	jmp	missp

qm1:	mov	di,qtail

;	find first nonblank in queue
qma3c:
	cmp	di,qhead
	je	qm4		;reached end of queue
	cmp	di,offset qz	;handle queue wrap
	jb	qma3d
	mov	di,offset qa
qma3d:
	mov	al,[di]
	cmp	al,32
	jae	qm2
	inc	di
	jmp	qma3c

qm2:	call	match		;see if we match this word
	jnc	qm5		;matched!

;	no match -- skip to beginning of next word in queue
;	first, skip this word
qml3a:
	cmp	di,qhead
	je	qm4		;reached end of queue
	cmp	di,offset qz	;handle queue wrap
	jb	qml3b
	mov	di,offset qa
qml3b:
	mov	al,[di]
	cmp	al,32
	jbe	qml3c
	inc	di
	jmp	qml3a

;	skip over delimiters
qml3c:
	cmp	di,qhead
	je	qm4		;reached end of queue
	cmp	di,offset qz	;handle queue wrap
	jb	qml3d
	mov	di,offset qa
qml3d:
	mov	al,[di]
	cmp	al,32
	ja	qm2		;check out next word
	inc	di
	jmp	qml3c


qm5:	;match -- jump to label
	call	scanb
	jnz	qm5a
	jmp	missp

qm5a:	call	labchkx
	call	execgoto
	mov	msgnum,40		;"ok"
	jmp	cpx


qm4:	;no match -- no action
	call	scanb			;check out syntax anyway
	jnz	qm4a
	jmp	missp

qm4a:	call	labchkx
	mov	msgnum,40		;"ok"
	jmp	cpx

;------ match: clear cf iff string pointed to by si,di match
;	all chars in si, di string must match, up to first delimiter
match	proc	near
	push	di
	push	si

ma1:	mov	al,[si]
	cmp	al,32
	jbe	ma5			;end of search string (match)
	cmp	di,qhead
	je	ma6			;no match
	call	cicomp			;do compare of al and [di]
	jne	ma6			;no match
	inc	si
	inc	di
	cmp	di,offset qz
	jb	ma1
	mov	di,offset qa
	jmp	ma1			;compare next char


ma6:	stc				;no match
	jmp	ma5a

ma5:	; we ran off end of si; if [di] is delimiter, we matched
	cmp	di,qhead
	je	ma7			;end is same as delimiter
	cmp	byte ptr [di],32
	ja	ma6			;no match
ma7:	clc				;match

ma5a:
	pop	si
	pop	di
	ret
match	endp


;------ trbegin: begin a new transaction
tbegin: call	endchkx
	mov	hicase,0		;clear previous case entries
	or	parm4,trcomm		;inhibit comm reception
	mov	msgnum,40		;"ok"
	jmp	cpx

;------ trcase: set up for communications "case"
tcase:	call	scanb
	jnz	tc1
	jmp	missp

tc1:	mov	bh,hicase
	cmp	bh,maxcase
	ja	tc9
	sub	bl,bl			;note bx = hicase*256

	mov	di,offset case0
	add	di,bx

	mov	[di].captr,0		;first char to check
	mov	[di].cawild,0		;no blank match just yet

	push	ds
	pop	es
	add	di,castring		;point to case string

tclp:	call	nxchr			;get search string
	cmp	al,32
	jbe	tc2
	stosb
	jmp	tclp

tc2:	mov	al,' '
	stosb				;add delimiter
	dec	si			;correct for nxchr overshoot
	call	scanb
	call	labchkx

tclp2:	call	nxchr			;write label
	cmp	al,32
	jbe	tc5
	stosb
	jmp	tclp2

tc5:	mov	al,0
	stosb				;write terminator

	inc	hicase			;point to next case
	mov	msgnum,40		;"ok"
	jmp	cpx

tc3:	jmp	missp
tc4:	jmp	unknownp

tc9:	mov	msgnum,141		;too many TRCASE statements
	or	cmdflg,cmderr
	jmp	cpx


;------ tend: transaction end; check for case match, timeout
;	stop command file processing, release comm processing
tend:	call	scanb
	jnz	te1
	jmp	missp

te1:	call	numscan
	jnz	te2
	jmp	unknownp

te2:	call	endchkx

	call	tadd_sec		;al contains timeout, in seconds
	mov	trtmc,cx
	mov	trtmd,dx
	and	parm4,255-trcomm	;allow comm processing
	or	parm4,trcmnd		;...but no command processing
	mov	msgnum,140		;transaction in progress
	jmp	cpx


cpx:
	ret
parsex	endp

;------ endchkx: check command line for non-blank chars
;	jump to excessp if non-blank chars left on line
endchkx proc	near
	call	endchk
	jnz	zchk3
	ret			;normal return address
zchk3:	pop	ax		;strip off return address
	jmp	excessp
endchkx endp

;------ qnxchr: get next char from queue into al
;	set cf if no char available
qnxchr	proc	near
	push	si

	mov	si,qtail
	cmp	si,qhead
	stc			;assume error
	je	qnx2
	mov	al,[si]

	inc	si
	cmp	si,offset qz		;handle queue wraparound
	jb	qnx1
	mov	si,offset qa
qnx1:	mov	qtail,si
	clc			;no error

qnx2:
	pop	si
	ret
qnxchr	endp

;------ qaddchr: add char in al to end of queue
qaddchr proc   near
	push	si

	mov	si,qhead
	mov	byte ptr [si],al

	inc	si
	cmp	si,offset qz		;handle queue wraparound
	jb	qad1
	mov	si,offset qa
qad1:	mov	qhead,si

	pop	si
	ret
qaddchr endp


;------ qflush: flush input character queue
qflush	proc	near
	push	ax
	mov	ax,qhead
	mov	qtail,ax
	pop	ax
	ret
qflush	endp


;------ execgoto: goto label in command file
;	si points to label (no leading dash)
execgoto proc	near
	push	ax
	push	bx
	push	cx
	push	dx
	push	si
	push	di
	push	es

	test	cmdflg,doact
	jz	gox				;no active command file

	or	cmdflg,lbsrch			;note label search
	and	cmdflg,255-lbwrap		;haven't wrapped yet

	push	ds
	pop	es

	mov	di,offset labelstring

golp:	call	nxchr
	cmp	al,32
	jbe	golp2
	stosb					;store in label string
	jmp	golp

golp2:	sub	al,al
	stosb					;terminator

gox:
	pop	es
	pop	di
	pop	si
	pop	dx
	pop	cx
	pop	bx
	pop	ax
	ret
execgoto endp


;------ execlabel: si points to label. see if it's the one we want
;	if it is, clear lbsrch flag
execlabel proc	near
	push	ax
	push	di
	push	si

	test	cmdflg,lbsrch
	jz	lax

	mov	di,offset labelstring

la0:	call	nxchr
	cmp	al,32
	jbe	la1
	cmp	byte ptr [di],0
	je	lax			;cmnd label too long
	cmp	al,[di]
	jne	lax			;mismatch
	inc	di
	jmp	la0

la1:	cmp	byte ptr [di],0
	jne	lax			;cmnd label too short

	and	cmdflg,255-lbsrch	;don't look anymore

lax:
	pop	si
	pop	di
	pop	ax
	ret
execlabel endp

;------ trprocess: check out char in al. source in ah
;	if we complete a match with a "case", then branch to it
trprocess proc near
	push	ax
	push	bx
	push	cx
	push	di
	push	si

	test	ah,fromc1
	jnz	tp1
	jmp	tpx

tp1:	and	al,7fh			;strip high bit for comparisons
	sub	bx,bx			;case counter
	mov	cl,al			;keep copy of char

tp1a:	mov	al,cl			;recover char (destroyed in loop)
	cmp	bh,hicase
	je	tpx			;we've seen them all
	mov	si,offset case0 	;point to case
	add	si,bx
	lea	di,[si].castring	;point to string
	add	di,[si].captr		;point to next char

	cmp	[si].cawild,1		;are we doing blank compare?
	jne	comp2
	cmp	al,32			;any number of blanks match
	je	tp2a
	cmp	al,9
	je	tp2a
	mov	[si].cawild,0		;not a blank; compare next char

comp2:	cmp	byte ptr [di],'^'
	jne	comp3
	mov	al,[di+1]
	call	unseq
	jc	compn
	cmp	al,32			;embedded blank?
	jne	comp2a			;no
	mov	[si].cawild,1		;yes	(note it)
	cmp	cl,32
	je	compi2
	cmp	cl,9
	je	compi2
	jmp	compn

comp2a: cmp	cl,al			;cntrl char-- no case conversion
	je	compi2
	jmp	compn

comp3:	xor	al,[di] 		;do compare
	jz	compi
	cmp	al,20h			;is lower/upper difference?
	je	compi
	jmp	compn

compi2: inc	[si].captr
	inc	di
compi:	inc	[si].captr
	inc	di

	cmp	byte ptr [di],' '       ;are we at last char?
	je	tp3			;yes -- we have a match
	jmp	tp2a			;no -- go on

compn:	mov	[si].captr,0		;back to beginning
	mov	[si].cawild,0

tp2a:	inc	bh
	jmp	tp1a			;do next case

;	we have a match; goto label
;	assumption: castring has one blank between string and label
;	label does NOT start w/ delimiter
tp3:	mov	si,di
	inc	si			;point to label
	call	execgoto		;set up goto
	mov	msgnum,-1		;clear msg area
	and	parm4,255-trcmnd	;resume command file execution
	jmp	tpx

tpx:
	pop	si
	pop	di
	pop	cx
	pop	bx
	pop	ax
	ret
trprocess endp

;------ case insensitive compare of al and [di]; sets ZF appropriately
cicomp	proc	near
	push	ax

	xor	al,[di]
	jz	cicx
	cmp	al,20h			;is lower/upper difference?
cicx:
	pop	ax
	ret
cicomp	endp

;------ labchkx: si points to purported label. Check it out.
;	set error and branch to cpx if not ok
;	else leave si pointing to first char of label (not '-')
labchkx proc	near
	push	ax
	push	si

	call	nxchr
	cmp	al,'-'
	jne	lberr
	cmp	byte ptr [si],32
	jbe	lberr			;blank labels not allowed
	call	scanb			;see if there's anything past label
	jnz	lberr			;there is

	pop	si			;normal exit
	pop	ax
	inc	si			;point to first char of label
	ret

lberr:	pop	si			;error exit
	pop	ax
	pop	ax			;strip return address off stack
	jmp	unknownp

labchkx endp

;------ emsbuf: store emis buffer
;	si --> file name to use
emsbuf	proc	near
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

sto0:	mov	al,12			;emis store subcode
	mov	dx,offset cs:emsbuf2	;pass addr of chr store routine
	mov	bx,cs			;...in bx:dx

	call	emisint 		;emis interrupt
	jnc	sto2
	mov	msgnum,144		;handler not available
	jmp	stoer9
sto2:

	call	stoclose
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
emsbuf	endp

;------ emsbuf2: called be emis resident program
;	al has char to be written to file
emsbuf2 proc	far			;called by emis handler
	push	bx
	push	ds

	mov	bx,cm_data		;establish addressability
	mov	ds,bx

	call	stowrite

	pop	ds
	pop	bx
	ret				;note this is a FAR procedure
emsbuf2 endp

cm_code ends
end

