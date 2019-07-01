	public	comproc

; **********************************************************************
; All changes to 'parse' made for oem version are commented with:
;
;		;OEM
;
; The module should assemble and link cleanly.
; **********************************************************************

cm_data segment public 'code'

allocate = 0
include data.pub

	wild	db	'*.*',0         ;'wild card' arg for dir search
cm_data ends

cm_code segment public 'code'
assume	cs:cm_code
assume	ds:cm_data

extrn	rsetup:near,wrtclose:near,wrtsetup:near
extrn	cm_epar:near,cm_opar:near,cm_spar:near,cm_mpar:near,cm_paroff:near
extrn	cm_b110:near,cm_b150:near,cm_b300:near,cm_b600:near,cm_b1200:near
extrn	cm_b2400:near,cm_b4800:near,cm_b9600:near,define:near,startpfk:near
extrn	dosetup:near,ferase:near,pr_start:near,wait_init:near
extrn	dtroff:near,cm_setup:near,cm_enable:near,cm_restore:near
extrn	fcaptog:near,cm_break:near,dopanic:near,chk_cd:near
extrn	chdir:near,seldrive:near,frename:near,tadd:near,unseq:near
extrn	tsend_init:near,em_ris:near

extrn	endchk:near,scanb:near,cisit:near,numscan:near,nxchr:near
extrn	parsex:near,qaddchr:near,execlabel:near,qflush:near


; the following external references are for Telios only, not OEM
	extrn	vid_init:near,helpscrn:near,cmdir:near,dofshow:near,setck:near
	extrn	setupd:near,pmsg:near,status:near,fsave:near
	extrn	wswitch:near,window:near,rdcrsr:near,nattr:near
	extrn	clrbuf:near,stobuf:near,sc_beep:near

;------ comproc: process command string in cmdline. length+1 in cmdptr.
comproc proc	near
	push	si
	push	di
	push	ax
	push	bx
	push	cx
	push	dx
	push	es

;NOTE: SI always, always is the correct scan pointer. Don't mess with it.


	mov	si,offset cmdline	;point to command line

;------ scan off leading blanks and parse

cmlp0:	call	nxchr
	or	al,al
	jnz	cmlp1
	mov	msgnum,55		;clear msg line ("conversation mode"
	and	cmdflg,255-noret	;always exit command mode on blank line
	jmp	cpx			;and ignore blank command line

cmlp1:	cmp	al,32
	je	cmlp0
	cmp	al,9			;tab?
	je	cmlp0
	cmp	al,'-'                  ;label?
	jne	cmlp2
	call	execlabel
	jmp	cpx

cmlp2:	cmp	al,';'
	jne	cmlp2a
	jmp	cpx			;ignore lines that start w/ semicolon

cmlp2a: dec	si			;back up one char (point to nonblank)
	test	cmdflg,doact		;from file?
	jz	cmlp3			;no
	test	cmdflg,lbsrch		;label search?
	jz	cmlp3
	jmp	cpx			;ignore commands during label search

cmlp3:
	isit	alfon,autolf,1
	isit	baud,baud,2
	isit	beep,beep,2a
	isit	break,break,3
	isit	cap,capture,4
	isit	cdir,cdir,4b
	isit	chat,chatter,4a
	isit	shortcm,clo,5		;don't allow "CLO"
	isit	bfclr,clear,5a
	isit	clock,clock,6
	isit	close,close,7
	isit	cls,cls,8
	isit	color,color,9
	isit	cursor,cursor,10
	isit	defn,define,11
	isit	dat,data,12		;old synonym for "eof"
	isit	shortcm,di,13		;don't allow "DI
	isit	dial,dial,15
	isit	dir,dir,17
	isit	disc,disconnect,19
	isit	do,do,20
	isit	dop,doproc,20a
	isit	seldr,drive,20b
	isit	echo,echo,21
	isit	dat,eof,21a
	isit	erase,erase,22
	isit	exp1,expand,23
	isit	filter,filter,24
	isit	flow,flow,24a
	isit	fshow,f?,25
	isit	help,help,26
	isit	list,list,27
	isit	msga,msg,27a
	isit	online,online,28
	isit	shortcm,pa,29		;don't allow "PA
	isit	panic,panic,30
	isit	parity,parity,31
	isit	shortcm,pr,31b		;don't allow PR
	isit	pcap,preceive,31a
	isit	prot,protocol,32
	isit	pcap,pcapture,33
	isit	port,port,33b
	isit	psend,psend,33a
	isit	quit,quit,34
	isit	shortcm,re,34a		;don't allow "RE
	isit	cap,receive,34b
	isit	rem,remark,35
	isit	rena,rename,35b
	isit	retr,retries,35a
	isit	route,route,36
	isit	save,save,37
	isit	scrn,screen,37a
	isit	send,send,38
	isit	sleep,sleep,39
	isit	shortcm,st,39a		;don't allow "ST
	isit	stat,status,40
	isit	stor,store,40b
	isit	tab,tabs,40a
	isit	tchr,tchar,41
	isit	term,term,41a
	isit	time,timeout,41b
	isit	ftog,toggle,42
	isit	twait,twait,43
	isit	typec,type,45
	isit	waiti,wait,46
	isit	xstr,xstring,47
	call	parsex			;check for extended command
	jmp	cpx

;OEM  -- this block consists of Telios-only commands

;------ bfclr: clear screen buffer
bfclr:	call	endchkx
	call	clrbuf
	mov	msgnum,40
	jmp	cpx

;------ chat: set level of information displayed during protocol transfers
chat:	call	scanb
	jnz	chat1
	jmp	missp

chat1:	isit	chat2,off,ch1
	isit	chat3,debug,ch2
	isit	chat4,on,ch3
	jmp	unknownp

chat2:	call	endchkx

chat2a: mov	chatter,chat_off
	mov	msgnum,124
	mov	chmsg,124
	jmp	cpx

chat3:	call	endchkx

chat3a: mov	chatter,chat_bug
	mov	msgnum,123
	mov	chmsg,123
	jmp	cpx

chat4:	call	endchkx

chat4a: mov	chatter,chat_on
	mov	msgnum,122
	mov	chmsg,122
	jmp	cpx

;------ cursor: if set, then cursor keys send codes to host
cursor: call	scanb
	jnz	cur1
	jmp	missp

cur1:	isit	cur2,send,cu1
	isit	cur3,local,cu2
	jmp	unknownp

cur2:	call	endchkx
	or	parm4,crsend
	mov	msgnum,134
	mov	cumsg,134
	jmp	cpx

cur3:	call	endchkx
	and	parm4,255-crsend
	mov	msgnum,135
	mov	cumsg,135
	jmp	cpx

;------ color: select display colors
color:
	call	scanb			;point past blanks
	jnz	col1
	jmp	missp

col1:
	call	numscan 		;get number into al
	jnz	col2			;was there a valid number?
	jmp	unknownp		; no

col2:	mov	ch,al			;ch gets nattr
	call	numscan
	jnz	col3
	mov	al,bckgrnd_val

col3:	mov	cl,al			;cl gets background
	call	numscan
	jnz	col4
	mov	al,hilite_val

col4:	mov	bh,al			;bh gets hilite
	call	numscan
	jnz	col5
	mov	al,reverse_val

col5:	mov	bl,al			;bl gets reverse
	call	numscan
	jnz	col6
	mov	al,reverseb_val

col6:	mov	dh,al			;dh gets reverse backgrnd
	call	numscan
	jnz	col7
	mov	al,border_val

col7:	mov	dl,al			;dl gets border color
	call	endchkx

colset: mov	nattr_val,ch
	mov	bckgrnd_val,cl
	mov	hilite_val,bh
	mov	reverse_val,bl
	mov	reverseb_val,dh
	mov	border_val,dl

	mov	cl,wndc_id		;switch to main window
	mov	al,1
	call	wswitch
	call	nattr			;re-initialize attributes in main window

	call	vid_init
	mov	scrnum,99		;force screen update
	call	setupd			;force clock update
	mov	msgnum,40		;msg
	and	cmdflg,255-noret	;don't wait for empty cmnd line

	mov	al,cl
	call	wswitch
	jmp	cpx

;------ clock: set clock display
clock:	call	scanb
	jnz	ck1
	jmp	missp

ck1:	isit	ckon,on,k0
	isit	ckoff,off,k1
	isit	ckset,set,k2
	jmp	unknownp

ckoff:	call	endchkx
	or	parm2,clkoff
	call	setupd
	mov	msgnum,93
	jmp	cpx

ckon:	call	endchkx
	and	parm2,255-clkoff
	call	setupd
	mov	msgnum,92
	jmp	cpx

ckset:	call	endchkx
	call	setck
	call	setupd
	mov	msgnum,94
	jmp	cpx

;------ list: control command file list-to-screen toggle
list:	call	scanb			;look for blank
	jnz	l0
	jmp	missp			;none found -- missing parameter

l0:	isit	lion,on,l1
	isit	lioff,off,l3
	jmp	unknownp

lion:	call	endchkx

lion1:	and	parm2,255-nolist
	mov	msgnum,40
	jmp	cpx

lioff:	call	endchkx

lioff1: or	parm2,nolist
	mov	msgnum,40
	jmp	cpx

;------ dir: print dos directory
dir:	call	scanb
	jnz	dir1			;pass argument to cmdir
	mov	si,offset wild		;if no arg, pass 'wild' arg

;	at this point, si points to some sort of 'dir' arg
dir1:	call	cmdir			;print formatted directory
	or	cmdflg,noret		;stay in command mode
	jmp	cpx

;------ help:print next help screen
help:	call	endchkx
	call	helpscrn
	jmp	cpx

;------ stat: show status screen
stat:	call	endchkx

	call	status
	jmp	cpx


;------ fshow: list function key definitions
fshow:	call	endchkx 		 ;no arg allowed
	call	dofshow 		;print formatted definitions
	or	cmdflg,noret		;stay in command mode
	jmp	cpx

;------ tab: set tabs
tab:	mov	cx,80
	sub	al,al
	mov	di,offset tabarray
	push	ds
	pop	es
	rep	stosb				;clear tabarray

	sub	bx,bx
tab1:	call	numscan
	jz	tabx
	cmp	al,79				;no tabs past 79
	ja	tab1				; (MVTAB handles expansion)
	mov	bl,al
	mov	tabarray[bx],1
	jmp	tab1

tabx:	mov	msgnum,117			;tabs set
	jmp	cpx

;------ term: set terminal emulation type
term:	call	scanb
	jnz	term1
	jmp	missp

term1:
	isit	term3,nih,te0
	isit	term4,mai,te1
	isit	term4,adm1,te2
	isit	term5,vt100,te3
	isit	term6,off,te4
	isit	term6,normal,te5
	isit	term9,3101,te6
	isit	term7,dos,te7
	isit	term8,vt52,te8
	isit	term10,ti931,te9
	jmp	unknownp

term3:	call	endchkx
	mov	termtype,nih
	mov	msgnum,119
	mov	temsg,119
	jmp	cpx

term4:	call	endchkx
	mov	termtype,mai
	mov	msgnum,118
	mov	temsg,118
	jmp	cpx

term5:	call	endchkx
	mov	termtype,ansi
	call	em_ris			;set initial state
	mov	msgnum,120
	mov	temsg,120
	jmp	cpx

term6:	call	endchkx
	mov	termtype,tty		;
	mov	msgnum,121
	mov	temsg,121
	jmp	cpx

term7:	call	endchkx
	mov	termtype,dost
	mov	msgnum,127
	mov	temsg,127
	call	clrbuf
	jmp	cpx

term8:	call	endchkx
	mov	termtype,vt52
	mov	msgnum,133
	mov	temsg,133
	jmp	cpx

term9:	call	endchkx
	mov	termtype,ibm
	mov	msgnum,142
	mov	temsg,142
	jmp	cpx

term10: call	endchkx
	mov	termtype,ti931
	mov	msgnum,146
	mov	temsg,146
	jmp	cpx

;------ type (display) contents of file
typec:	call	scanb			;scan till blank
	jnz	ty1
	jmp	nofile

ty1:	call	rsetup			;setup read file (same as SEND cmnd)
	and	tflag,255-(t1src+f1src)
	or	cmdflg,cmderr	       ;assume error
	or	al,al			;check rc
	jnz	tycpx			;exit if not ok (msg set by "rsetup")
	or	tflag,t1src		;indicate file1 active for display
	mov	msgnum,76		;"typing file"
	and	cmdflg,255-(noret+cmderr)   ;do immediately; no error found
tycpx:	jmp	cpx


;------ store contents of buffer in file
stor:	call	scanb			;scan till blank
	jnz	sto1
	jmp	nofile

sto1:	or	cmdflg,cmderr		;assume error
	call	stobuf
	jc	stox
	and	cmdflg,255-cmderr      ;no error found
stox:	jmp	cpx

;------ save current parameters
save:	call	scanb
	jnz	sa1
	jmp	nofile

sa1:	call	fsave			;fsave sets msgnum
	jmp	cpx


;------ echo command argument to screen
msga:
	mov	bl,wndc_id
	mov	al,1
	call	wswitch 		;switch to main window

	mov	al,[si] 		;skip separator after MSG command
	inc	si			;can't nxchr cause of case conversion
	or	al,al
	jz	msga3

	call	rdcrsr
	cmp	dl,wndc_lc		;at left margin?
	je	msga1			;yup
	mov	ah,fromt1
	mov	al,13
	call	window
	mov	ah,fromt1
	mov	al,10
	call	window

msga1:	mov	al,[si]
	inc	si
	or	al,al
	jz	msga3

	mov	ah,fromt1		;just like typing a file
	call	window
	jmp	msga1

msga3:	mov	ah,fromt1
	mov	al,13
	call	window

	mov	ah,fromt1
	mov	al,10
	call	window

	mov	al,bl			;restore old window
	call	wswitch
	jmp	cpx


;------ set flags to control display of chars to screen
scrn:
	call	scanb			;look for blank
	jnz	sc0
	jmp	missp			;none found -- missing parameter

sc0:	isit	scon,normal,sc1
	isit	scoff,mute,sc2
	isit	scgrf,graphic,sc3
	jmp	unknownp

scon:	call	endchkx

sc1:	or	parm3,screen
	and	parm3,255-graph
	mov	msgnum,109
	mov	scmsg,109
	call	setupd
	jmp	cpx

scgrf:	call	endchkx

scgrf1: or	parm3,screen+graph
	call	setupd
	mov	msgnum,111
	mov	scmsg,111
	jmp	cpx

scoff:	call	endchkx

scoff1: and	parm3,255-(screen+graph)
	mov	msgnum,110
	mov	scmsg,110
	call	setupd
	jmp	cpx

;------ cls: clear main screen
cls:	call	endchkx

	mov	bl,wndc_id		;save window
	mov	al,1
	call	wswitch

	mov	ah,fromt1		;clear screen
	mov	al,12
	call	window
	mov	msgnum,40

	mov	al,bl			;switch back
	call	wswitch
	jmp	cpx

;------ beep: make a noise
beep:	call	endchkx
	call	sc_beep
	mov	msgnum,40
	jmp	cpx

;OEM ************* end of Telios-only commands	 %

;------ rena: rename file
rena:	call	scanb
	jnz	ren1
	jmp	nofile

ren1:	or	cmdflg,cmderr		;assume error
	call	frename
	jc	renx
	and	cmdflg,255-cmderr
renx:	jmp	cpx

;------ seldr: select default drive
seldr:	call	scanb
	jnz	sel1
	jmp	missp

sel1:	or	cmdflg,cmderr
	call	seldrive
	jc	selx
	and	cmdflg,255-cmderr
selx:	jmp	cpx


;------ cdir: change current directory
cdir:	call	scanb
	jnz	cdi1
	jmp	missp

cdi1:	or	cmdflg,cmderr
	call	chdir
	jc	cdix
	and	cmdflg,255-cmderr
cdix:	jmp	cpx


;------ port: select communications port
port:	call	scanb
	jnz	por1
	jmp	missp

por1:	call	numscan
	jnz	por2
	jmp	unknownp

por2:	call	endchkx

por3:	cmp	al,1
	je	por4
	cmp	al,2
	je	por4
	jmp	unknownp

por4:	call	cm_restore		;fix up old port
	call	cm_setup		;switch to port in AL
	call	cm_enable		;and initialize it
	jmp	cpx			;msgnum set by "cm_setup"


;------ dat: set data type
dat:	call	scanb
	jnz	da1
	jmp	missp

da1:	isit	da2,text,da1
	isit	da3,binary,da2
	jmp	unknownp

da2:	call	endchkx

da2a:	and	parm4,255-binfile
	mov	msgnum,126
	mov	damsg,126
	jmp	cpx

da3:	call	endchkx

da3a:	or	parm4,binfile
	mov	msgnum,125
	mov	damsg,125
	jmp	cpx

;------ time: set timeout
time:
	call	scanb
	jnz	tm1
	jmp	missp

tm1:	call	numscan 		;get number into al
	jnz	tm1a			;was there a valid number?
	jmp	unknownp		; no
tm1a:	call	endchkx

tm2:
	mov	timeout,al
	mov	msgnum,97
	jmp	cpx

;------ wait: initiate turnaround wait
waiti:	call	endchkx

waitok: call	wait_init
	jmp	cpx

;------ retries: set max number of retries on error
retr:
	call	scanb
	jnz	rt1
	jmp	missp

rt1:	call	numscan 		;get number into al
	jnz	rt1a			;was there a valid number?
	jmp	unknownp		; no
rt1a:	call	endchkx

rt2:	cmp	al,127
	jbe	rt3
	jmp	unknownp

rt3:	sub	ah,ah
	mov	maxretry,al
	mov	msgnum,108
	jmp	cpx


;------ online: set "connected" or "disconnected" msg
online: call	endchkx

onlok:	mov	lastcdmsg,0		;force display of msg
	call	chk_cd
	jmp	cpx

;------ exp1: select blank expansion
exp1:
	call	scanb			;look for blank
	jnz	ex0
	jmp	missp			;none found -- missing parameter

ex0:	isit	exon,on,x1
	isit	exoff,off,x3
	jmp	unknownp

exon:	call	endchkx

ex1:	or	parm2,expand
	mov	msgnum,90
	mov	exmsg,90
	jmp	cpx

exoff:	call	endchkx

exoff1: and	parm2,255-expand
	mov	msgnum,91
	mov	exmsg,91
	jmp	cpx


;------ route: select which chars go to cap file
route:	call	scanb
	jnz	ro1
	jmp	missp			;no parms

ro1:	isit	rokey,sent,r0
	isit	rohost,received,r1
	isit	roall,all,r2
	jmp	unknownp

rokey:
	call	endchkx

rokey1: and	parm2,255-routeh
	or	parm2,routek
	mov	msgnum,87
	mov	romsg,87
	jmp	cpx

rohost:
	call	endchkx

rohost1: and	parm2,255-routek
	or	parm2,routeh
	mov	msgnum,86
	mov	romsg,86
	jmp	cpx

roall:
	call	endchkx

roall1: or	parm2,routeh+routek
	mov	msgnum,85
	mov	romsg,85
	jmp	cpx


;------ panic: turn everything off
panic:	call	endchkx
	call	dopanic
	jmp	cpx

;------ break: send break signal
break:	call	endchkx
	call	cm_break
	jmp	cpx

;------ ftog: toggle cap file
ftog:	call	endchkx
	call	fcaptog
	call	setupd
	jmp	cpx

;------ disc: turn dtr off (disconnect
disc:	call	endchkx
	call	dtroff
	call	setck
	mov	msgnum,40		;"done"
	jmp	cpx

;------ flow: set flags to indicate host/telios supports protocol
flow:	call	scanb
	jnz	fl1
	jmp	missp

fl1:	isit	flxh,send,fl1
	isit	floff,off,fl2
	isit	flxt,obey,fl3
	isit	flxb,both,fl4
	isit	flrts,rts,fl5
	jmp	unknownp

flxh:	call	endchkx
	or	parmf,protxon
	and	parmf,255-protxont
	and	parm4,255-protrts
	mov	protmsg,72
	mov	msgnum,72		;use xoff  when necessary
	jmp	cpx

floff:	call	endchkx
	and	parmf,255-(protxon+protxont)
	and	parm4,255-protrts
	mov	protmsg,73
	mov	msgnum,73		;no flow in use
	jmp	cpx

flxt:	call	endchkx
	or	parmf,protxont
	and	parmf,255-protxon
	and	parm4,255-protrts
	mov	protmsg,88
	mov	msgnum,88		;obey xon
	jmp	cpx

flxb:	call	endchkx
	or	parmf,protxon+protxont
	and	parm4,255-protrts
	mov	protmsg,89
	mov	msgnum,89		;xon protocol now in use
	jmp	cpx

flrts:	call	endchkx
	and	parmf,255-(protxon+protxont)
	or	parm4,protrts
	mov	protmsg,148
	mov	msgnum,148		;cts/rts protocol now in use
	jmp	cpx


;------ prot: set protocol type (xmodem, kermit)
prot:
	call	scanb			;look for blank
	jnz	pr0
	jmp	missp			;none found -- missing parameter

pr0:	isit	prkerm,kermit,px1
	isit	prxmo,xmodem,px3

;***	since the PROTOCOL command used to do what FLOW does now, we
;	accept the FLOW parameters too.  Just don't tell anyone...
	isit	flxh,send,fp6
	isit	floff,off,fp7
	isit	flxt,obey,fp8
	isit	flxb,both,fp9
	jmp	unknownp


prkerm: call	endchkx

pr1:	or	parm3,kermit
	and	parm3,255-xmodem
	mov	msgnum,113
	mov	kxmsg,113
	jmp	cpx

prxmo:	call	endchkx

proff1: or	parm3,xmodem
	and	parm3,255-kermit
	mov	msgnum,112
	mov	kxmsg,112
	jmp	cpx


;------ remark: ignore argument (comment
rem:	mov	msgnum,40		;msg = ok
	jmp	cpx


;------ erase: erase a file
erase:	call	scanb
	jnz	era1			;pass argument to ferase
	jmp	nofile

;	at this point, si points to some sort of filename arg
era1:	call	ferase			;erase file
	jmp	cpx


;------ set baud rate
baud:	call	scanb
	jnz	b1
	jmp	missp

b1:	isit	b110,110,b1
	isit	b150,150,b2
	isit	b300,300,b3
	isit	b600,600,b4
	isit	b1200,1200,b5
	isit	b2400,2400,b6
	isit	b4800,4800,b7
	isit	b9600,9600,b8
	jmp	unknownp

b110:
	call	endchkx
	call	cm_b110
	mov	msgnum,43
	jmp	bexit
b150:
	call	endchkx
	call	cm_b150
	mov	msgnum,44
	jmp	bexit
b300:
	call	endchkx
	call	cm_b300
	mov	msgnum,45
	jmp	bexit
b600:
	call	endchkx
	call	cm_b600
	mov	msgnum,46
	jmp	bexit

b1200:
	call	endchkx
	call	cm_b1200
	mov	msgnum,47
	jmp	bexit
b2400:
	call	endchkx
	call	cm_b2400
	mov	msgnum,48
	jmp	bexit
b4800:
	call	endchkx
	call	cm_b4800
	mov	msgnum,49
	jmp	bexit
b9600:
	call	endchkx
	call	cm_b9600
	mov	msgnum,50
	jmp	bexit

bexit:	mov	ax,msgnum
	mov	bamsg,ax
	jmp	cpx


;------ send contents of file upline
send:	call	scanb			;scan till blank
	jnz	s1
	jmp	nofile

s1:	call	rsetup			;setup read file
	or	cmdflg,cmderr		;assume error
	and	tflag,255-(f1src+t1src)
	or	al,al			;check rc
	jnz	scpx			;exit if not ok (msg set by "rsetup")
	mov	msgnum,17		;"sending" msg
	and	cmdflg,255-(noret+cmderr) ;do immediately; note no error
	or	tflag,f1src		;indicate file1 active
	call	tsend_init		;initialize "expand" flag
scpx:	jmp	cpx

;------ send contents of file upline using protocol
psend:	call	scanb			;scan till blank
	jnz	ps1
	jmp	nofile

ps1:
;	save name of send file for file header packet
	push	si
	push	ds
	pop	es
ps0:	mov	di,offset sfname
	sub	cx,cx
ps2:	call	nxchr			;get next char
	or	al,al			;end of string if zero
	jz	ps4
	cmp	al,':'                  ;disk id?
	je	ps0			;restart
	cmp	al,'\'                  ;pathname?
	je	ps0			;restart
	stosb
	inc	cx
	jmp	ps2

ps4:	mov	sflen,cx		;store capfile name length
	pop	si			;restore string ptr

	call	rsetup			;setup read file
	or	cmdflg,cmderr		;assume error
	and	tflag,255-(f1src+t1src)
	or	al,al			;check rc
	jnz	pscpx			;exit if not ok (msg set by "rsetup")

	test	tflag,fcap		;is cap file open
	jz	ps3			;no --

	call	wrtclose		;yes -- close it (resets msgnum, too
	and	tflag,255-fcap		;and switch off flag
	call	setupd			;force update of status line

ps3:	mov	msgnum,17		;"sending" msg
	and	cmdflg,255-(noret+cmderr) ;do immediately (and note no error)
	or	tflag,f1src		;indicate file1 active
	call	pr_start		;prepare for ptrans transfer
pscpx:	jmp	cpx

;------ close capture file
close:	call	endchkx

close0: mov	msgnum,54		;"no open capture file"
	test	tflag,fcap		;is cap file open

	jnz	close1			;yes --
	or	cmdflg,cmderr		;assume error
	jmp	cpx			;no --

close1: call	wrtclose		;yes -- close it (resets msgnum, too
	and	tflag,255-fcap		;and switch off flag
	mov	camsg,54		;'no cap file' msg
	call	setupd			;force update of status line

	jmp	cpx

;------ capture to file
cap:	call	scanb
	jnz	c1
	jmp	nofile

c1:	test	tflag,fcap		;is one already active?
	jz	com2a			;no
	call	wrtclose		;yes -- close it
	and	tflag,255-fcap		;and switch off flag

com2a:	mov	camsg,54		;'no cap file' msg, changed by wrtsetup

;	save name of cap file for status display
	push	si
	push	ds
	pop	es
	mov	di,offset cfname
	sub	cx,cx
caplp:	call	nxchr			;get next char
	or	al,al			;end of string if zero
	jz	caplp2
	stosb
	inc	cx
	jmp	caplp

caplp2: mov	cflen,cx		;store capfile name length
	pop	si			;restore string ptr

	call	wrtsetup		;set up new file
	or	cmdflg,cmderr		;assume error
	or	al,al			;check rc
	jnz	cmcpx			;exit if not ok
	and	cmdflg,255-cmderr	;no error after all
	or	tflag,fcap		;indicate capture active
	and	parmf,255-capoff	;not toggled off
cmcpx:
	call	setupd			;force status redisplay
	jmp	cpx

;------ capture to file using protocol
pcap:	call	scanb
	jnz	pc1
	jmp	nofile

pc1:	and	tflag,255-f1src 	;turn off send
	test	tflag,fcap		;is cap already active?
	jz	pcom2a			;no
	call	wrtclose		;yes -- close it
	and	tflag,255-fcap		;and switch off flag

pcom2a: mov	camsg,54		;'no cap file' msg, changed by wrtsetup

;	save name of cap file for status display
	push	si
	push	ds
	pop	es
	mov	di,offset cfname
	sub	cx,cx
pcaplp: call	nxchr			;get next char
	or	al,al			;end of string if zero
	jz	pcaplp2
	stosb
	inc	cx
	jmp	pcaplp

pcaplp2: mov	 cflen,cx		 ;store capfile name length
	pop	si			;restore string ptr

	call	wrtsetup		;set up new file
	or	cmdflg,cmderr		;assume error
	or	al,al			;check rc
	jnz	pcmcpx			;exit if not ok
	and	cmdflg,255-cmderr	;no error after all
	or	tflag,fcap		;indicate capture active
	and	parmf,255-capoff	;not toggled off
	and	cmdflg,255-noret	;do immediately
	call	pr_start		;initialize protocol receiver
pcmcpx:
	call	setupd			;force status redisplay
	jmp	cpx

;------ sleep: set up things so that next command won't get executed
;	for xxx tenths of a second
sleep:
	call	scanb
	jnz	sl1
	jmp	missp

sl1:	call	numscan 		;get number into al
	jnz	sl1a			;was there a valid number?
	jmp	unknownp		; no

sl1a:	call	endchkx

sl2:	call	tadd			;get ending time into cx:dx
	mov	slepc,cx
	mov	slepd,dx
	or	tflag,cmsleep
	mov	msgnum,63		;sleepy msg
	jmp	cpx


;------ return to dos
quit:	call	endchkx

quit2:	or	tflag,pfexit		;set exit flag
	and	cmdflg,255-noret	;don't wait for empty cmnd line
	jmp	cpx

unknown: mov	msgnum,22		;unknown command
	or	cmdflg,cmderr
	jmp	cpx

unknownp: mov	msgnum,23		;unknown parameter
	or	cmdflg,cmderr
	jmp	cpx

missp:	mov	msgnum,27		;missing parameter
	or	cmdflg,cmderr
	jmp	cpx

excessp: mov	msgnum,69		;too many commadn options
	or	cmdflg,cmderr
	jmp	cpx

shortcm: mov	msgnum,136		;abbreviation too short
	or	cmdflg,cmderr
	jmp	cpx

nofile: mov	msgnum,137		;no file specified
	or	cmdflg,cmderr
	jmp	cpx

;------ set autolf after cr
alfon:	call	scanb			;look for blank
	jnz	a0
	jmp	missp			;none found -- missing paramter

a0:	isit	aon,on,a1
	isit	aoff,off,a3
	jmp	unknownp

aon:	call	endchkx

aon1:	or	parmf,autolf
	mov	msgnum,33		;autolf set on
	mov	aumsg,33
	jmp	cpx

aoff:	call	endchkx

aoff1:	and	parmf,255-autolf
	mov	msgnum,34		;autolf set off
	mov	aumsg,34
	jmp	cpx

;------ set weird character filter
filter: call	scanb
	jnz	f0
	jmp	missp			;missing parameter

f0:	isit	fon,on,f1
	isit	foff,off,f3
	jmp	unknownp

fon:	call	endchkx

fon1:	and	parmf,255-nofilt
	mov	msgnum,31		;filter set on
	mov	fimsg,31
	jmp	cpx

foff:	call	endchkx

foff1:	or	parmf,nofilt
	mov	msgnum,32		;filter set off
	mov	fimsg,32
	jmp	cpx

;------ set host or local echo
echo:	call	scanb
	jnz	e0
	jmp	missp			;missing parameter

e0:	isit	econ,on,e1
	isit	ecoff,off,e3
	jmp	unknownp

econ:	call	endchkx

econ1:	and	parmf,255-hecho
	mov	msgnum,29		;echo set on
	mov	ecmsg,29
	jmp	cpx

ecoff:	call	endchkx

ecoff1: or	parmf,hecho
	mov	msgnum,30		;echo set off
	mov	ecmsg,30
	jmp	cpx

;------ set parity
parity: call	scanb
	jnz	p0
	jmp	missp

p0:	isit	pma,mark,p1
	isit	psp,space,p3
	isit	pod,odd,p5
	isit	pev,even,p7
	isit	poff,off,p9
	jmp	unknownp

pma:	call	endchkx

pma1:	call	cm_mpar 		;set mark parity
	mov	msgnum,38
	mov	pamsg,38
	jmp	cpx

psp:	call	endchkx

psp1:	call	cm_spar 		;set space parity
	mov	msgnum,37
	mov	pamsg,37
	jmp	cpx

pev:	call	endchkx

pev1:	call	cm_epar 		;set even parity
	mov	msgnum,36
	mov	pamsg,36
	jmp	cpx

pod:	call	endchkx

pod1:	call	cm_opar 		;set odd parity
	mov	msgnum,35
	mov	pamsg,35
	jmp	cpx

poff:	call	endchkx

poff1:	call	cm_paroff		;turn off parity, use 8 data bits
	mov	msgnum,39
	mov	pamsg,39
	jmp	cpx

;------ set turnaround char
tchr:	call	scanb			;point past blanks
	jnz	t1
t0:	jmp	missp

t1:	and	tflag,255-lwait 	;turn off wait even on error
	isit	tnone,off,t1

;	if overrun, missing parm
	mov	al,[si] 	;can't use nxchr because it converts case
	inc	si
	or	al,al
	jz	t0		;missing char

	cmp	al,'^'          ;escape (^) chr?
	jne	tset		;nope -- normal keybd char

	mov	al,[si] 	;get next char
	inc	si
	or	al,al
	jz	t0

	call	unseq		;decode ^ char in al
	jc	nxp7		;not recognized
	jmp	tset


nxp7:	jmp	unknownp

tset:	call	endchkx

tset1:	mov	turnchr,al		;store turnaround char
	or	parmf,ltcon		;note that turnaround char is available
	mov	msgnum,41		;msg
	mov	tcmsg,41
	jmp	cpx

tnone:	call	endchkx

tnone1: and	parmf,255-ltcon 	;no turnaround char
	mov	turnchr,0
	mov	msgnum,42		;msg
	mov	tcmsg,42
	jmp	cpx


;------ twait: set line turnaround wait (tenths of a second)
twait:
	call	scanb			;point past blanks
	jnz	w1
	jmp	missp

w1:
	call	numscan 		;get number into al
	jnz	wset			;was there a valid number?
	jmp	unknownp		; no

wset:	call	endchkx

wset1:	mov	twtime,al		;store turnaround wait time
	mov	msgnum,65		;msg
	jmp	cpx

;------ defn: define pf key string
defn:	call	scanb
	isit	dp10,10,d8
	isit	dpent,enter,d9
	isit	dpbs,bs,d10
	isit	dpa,answer,d105
	isit	unknownp,pr,dd1 			;disallow 'pr'
	isit	dpp,prefix,d11
	isit	dpprot,protocol,d7
	isit	dps,suffix,d12
	isit	dpnum,number,d13
	isit	dpspre,sprefix,d14
	isit	dpssuf,ssuffix,d15
	isit	dpdisc,disconnect,d16
	isit	dpcher,character,d18
	isit	unknownp,co,dd0 			;disallow 'co'
	isit	dpcmer,command,d19
	isit	dpconn,connect,d17
	isit	dptime,timeout,d20
	isit	dpring,ring,d21
	isit	dpbrk,break,d22
	isit	dps1,s1,d23
	isit	dps2,s2,d24
	isit	dps3,s3,d25
	isit	dps4,s4,d26
	isit	dps5,s5,d27
	isit	dps6,s6,d28
	isit	dps7,s7,d29
	isit	dps8,s8,d30
	isit	dps9,s9,d31
	isit	dps10,s10,d32
	isit	dp1,f1,d33
	isit	dp2,f2,d34
	isit	dp3,f3,d35
	isit	dp4,f4,d36
	isit	dp5,f5,d37
	isit	dp6,f6,d38
	isit	dp7,f7,d39
	isit	dp8,f8,d40
	isit	dp9,f9,d41
	isit	dp10,f10,d42

;	following parms are one digit long
	inc	si
	cmp	byte ptr [si],' '
	jbe	defn2
	jmp	unknownp

defn2:	cmp	byte ptr [si-1],'1'
	je	dp1
	cmp	byte ptr [si-1],'2'
	je	dp2
	cmp	byte ptr [si-1],'3'
	je	dp3
	cmp	byte ptr [si-1],'4'
	je	dp4
	cmp	byte ptr [si-1],'5'
	je	dp5
	cmp	byte ptr [si-1],'6'
	je	dp6
	cmp	byte ptr [si-1],'7'
	je	dp7
	cmp	byte ptr [si-1],'8'
	je	dp8
	cmp	byte ptr [si-1],'9'
	je	dp9
	jmp	unknownp

dp1:	mov	al,dpf1
	jmp	dpex

dp2:	mov	al,dpf2
	jmp	dpex

dp3:	mov	al,dpf3
	jmp	dpex

dp4:	mov	al,dpf4
	jmp	dpex

dp5:	mov	al,dpf5
	jmp	dpex

dp6:	mov	al,dpf6
	jmp	dpex

dp7:	mov	al,dpf7
	jmp	dpex

dp8:	mov	al,dpf8
	jmp	dpex

dp9:	mov	al,dpf9
	jmp	dpex

dp10:	mov	al,dpf10
	jmp	dpex

dpent:	mov	al,dpfent
	jmp	dpex

dpbs:	mov	al,dpfbs
	jmp	dpex

dpa:	mov	al,dpfa
	jmp	dpex

dpp:	mov	al,dpfpr
	jmp	dpex

dps:	mov	al,dpfsuf
	jmp	dpex

dpspre: mov	al,dpfspre
	jmp	dpex

dpssuf: mov	al,dpfssuf
	jmp	dpex

dpdisc: mov	al,dpfdisc
	jmp	dpex

dpconn: mov	al,dpfconn
	jmp	dpex

dpcher: mov	al,dpfcher
	jmp	dpex

dpcmer: mov	al,dpfcmer
	jmp	dpex

dptime: mov	al,dpftime
	jmp	dpex

dpring: mov	al,dpfring
	jmp	dpex

dpbrk:	mov	al,dpfbrk
	jmp	dpex

dpprot: mov	al,dpfprot
	jmp	dpex

dps1:	mov	al,dpfs1
	jmp	dpex

dps2:	mov	al,dpfs2
	jmp	dpex

dps3:	mov	al,dpfs3
	jmp	dpex

dps4:	mov	al,dpfs4
	jmp	dpex

dps5:	mov	al,dpfs5
	jmp	dpex

dps6:	mov	al,dpfs6
	jmp	dpex

dps7:	mov	al,dpfs7
	jmp	dpex

dps8:	mov	al,dpfs8
	jmp	dpex

dps9:	mov	al,dpfs9
	jmp	dpex

dps10:	mov	al,dpfs10
	jmp	dpex

dpnum:	mov	al,dpfnum

dpex:	inc	si		;move past arg delimiter (blank, probably
	call	define
	mov	msgnum,40	;done
	jmp	cpx


;------ transmit argument string
xstr:	call	scanb			;strip leading blanks
	mov	al,dpfx 		;note XSTR string
	call	define			;store string
	mov	al,dpfx
	call	startpfk		;start sending
	mov	msgnum,40		;'done'
	jmp	cpx

;------ dial phone number
dial:	call	scanb
	jz	dial2		;nothing past string

	mov	al,dpfnum
	call	define		;define tel number

dial2:	mov	al,dpfpr
	call	startpfk
	mov	msgnum,40		;"done"
	and	cmdflg,255-noret	;do immediately
	or	parm2,diala		;note that dial is active
	call	setck			;reset connect timer
	jmp	cpx

;------ execute a command file
dop:	test	cmdflg,doproc		;this label for files that return
	jz	dop1
	mov	msgnum,145		;doproc already active
	or	cmdflg,cmderr
	jmp	cpx

dop1:	or	cmdflg,doproc		;indicate return expected

do:					;this label if not returning
	call	scanb			;point past blanks
	jnz	do1
	jmp	nofile

do1:	test	cmdflg,doact		;file already active?
	jnz	do1a			;yup -- no flush
	call	qflush			;flush input queue

do1a:	push	si
	call	scanb			;point past filename
	mov	cl,[si]
	mov	byte ptr [si],0 	;blast in new terminator
	mov	bx,si			;save terminator location
	pop	si
	call	dosetup 		;setup do file
	mov	byte ptr [bx],cl	;restore character

	call	pmsg			;print msg
	or	cmdflg,cmderr		;set error
	or	al,al			;check rc
	jnz	dcpx			;exit if not ok

;	move chars after filename into input queue
	call	scanb			;skip filename
	jz	do2			;no chars after filename

dolp:	call	nxchr
	or	al,al
	jz	do2			;all done
	call	qaddchr 		;add char to queue
	jmp	dolp

do2:	or	cmdflg,doact		;indicate do file active
	and	cmdflg,255-(cmderr+noret) ;no error after all
dcpx:	jmp	cpx

cpx:
	pop	es
	pop	dx
	pop	cx
	pop	bx
	pop	ax
	pop	di
	pop	si
	ret
comproc endp

;------ endchkx: check command line for non-blank chars
;	jump to excessp if non-blank chars left on line
endchkx proc	near
	call	endchk
	jnz	zchk3
	ret			;normal return address
zchk3:	pop	ax		;strip off return address
	jmp	excessp
endchkx endp

cm_code ends
end
