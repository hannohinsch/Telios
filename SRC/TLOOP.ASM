;------ terminal emulator (main program)
;	(C) Copyright 1983  Hanno Hinsch

	public	chktime

cm_data segment public 'code'

allocate = 0
include data.pub

inifile db	12,'startup.tls',0      ;default initialization file
pspline db	128 dup (?)		;space for copy of command parm line

nullint db	0cfh			;iret instruction for taming ctrl-break

brkstate	db	0		;control break state at entry

dosxstring	db	'Telios requires DOS version 2.00 or later',13,10,'$'

cm_data ends

stack	segment stack
	db	500 dup (?)
stack	ends

cm_code segment  public 'code'
assume	ss: stack
assume	cs: cm_code
assume	ds: nothing

extrn	cm_enable:near,cm_restore:near,fenable:near,frestore:near
extrn	cm_b300:near,cm_epar:near,isxonw:near,isdsron:near,clrxonw:near
extrn	display:near,wswitch:near,doinit:near,vid_init:near,wcsettle:near
extrn	cmcont:near,rdkeyb:near,waiter:near,setck:near,qckch:near,showck:near
extrn	sendc:near,window:near,capfile1:near,setupd:near
extrn	pmsg:near,logo:near,fread:near,wrtclose:near,chk_cd:near
extrn	nattr:near,tadd_sec:near,cm_setup:near,ctl_action:near
extrn	pr_send:near,pr_rd:near
extrn	pr_eof:near,pr_loop:near
extrn	decode:near,bufinit:near,rdfclose:near
extrn	ansback:near,ringchk:near,trprocess:near,kbinit:near
extrn	emisint:near
extrn	isctsw:near,rtson:near,rtsoff:near

start	proc	far
;	store dos return info
	push	ds
	sub	ax,ax
	push	ax

	mov	ax,cm_data
	mov	es,ax
	mov	si,80h		;offset in psp of command parms
	mov	di,offset cm_data:pspline
	mov	cx,128		;length of psp line

;	ds:si points at psp line, es:di points into data area
	rep	movsb		;move it into data segment

	mov	bx,ds		;save ptr to program prefix for bufinit
	mov	es,bx

	mov	ds,ax		;set up data segment
	assume	ds:cm_data

	mov	ah,30h		;check for DOS 2.0 or later
	int	21h
	cmp	al,2		;2.0 or greater?
	jae	init2		;yup -- all ok

	mov	ah,9		;print error msg
	mov	dx,offset dosxstring
	int	21h
	jmp	dosexit 	;take quick exit

init2:	mov	ax,es:[2]	;get upper memory bound
	call	bufinit 	;initialize screen buffer

	mov	dx,offset nullint	;de-fang crtl-break
	mov	al,23h			;23h = ctrl break
	mov	ah,25h			;"set int vector" function
	int	21h

	mov	ah,33h		;find ctrl-break state
	mov	al,0		;request state
	int	21h
	mov	brkstate,dl	;store for exit

	mov	ah,33h		;reset break setting
	mov	al,1
	mov	dl,0
	int	21h

	call	vid_init	;set up video initialization
	call	fenable

;	initialize comm adaptor
	mov	al,1		;start w/ port 1
	call	cm_setup
	jnc	start1
	mov	al,2		;couldn't find comm 1
	call	cm_setup
				;could check for error; assume user not stupid
start1: call	cm_enable	;set up interrupt handlers
	call	cm_b300
	call	cm_epar
	call	chk_cd		;initialize cd msg

	mov	si,offset pspline
	mov	al,[si]
	or	al,al
	jnz	loop0

	mov	si,offset inifile

loop0:	call	kbinit
	call	logo		;logo waits for chr iff al = 0
	call	doinit		;execute startup file

	mov	al,0ch		;move home
	call	display

	call	setck		;start connect timer
	call	setupd		;force clock re-display
	or	parm2,msgupd	;force status line update
	mov	msgnum,25	;friendly greeting

;	note that the order in which the sources are checked matters,
;	in that it assigns priorities to the sources

loop:	test	tflag,tdelay		;waiting for turnaround delay?
	jz	loop2			;nope -- go on
	mov	si,offset twc
	call	chktime 		;set zf if time not up
	jz	loop2			;wait more

loop1a: and	tflag,255-tdelay

loop2:	cmp	msgnum,0
	je	loop2a
	call	pmsg		;print possible message

loop2a: test	parm3,ptrans
	jz	loop2b
	call	pr_loop 	;give protocol unit a chance

loop2b: test	parm4,protrts	;rts?
	jz	loop2c
	test	parm2,msgupd	;do we clear msg area?
	jz	loop2c		;no
	call	isctsw
	jnz	loop2c		;still waiting for cts
	mov	msgnum,-1	;force status msg to clear possible "Waiting..."

loop2c: call	rdkeyb		;rdkeyb sets source
	jz	chkcom		;no character ready
	test	parm2,msgupd	;do we clear msg area?
	jz	rdk2		;no
	mov	msgnum,-1	;flag status update
rdk2:	jmp	process

chkcom: test	parm4,trcomm		;is transaction blocking comm read?
	jnz	chkfile 		;yes -- skip it
	mov	si,offset decode
	test	parm3,ptrans
	jz	chkcom1
	mov	si,offset pr_rd
chkcom1: call	si
	jz	chkfile 	;no data here -- check file
	mov	obtchr,al	;save it (last one is "observed turnaround chr
	jmp	process

chkfile:call	wcsettle	 ;make screen cursor = logical cursor
	call	chk_cd		;see if line status changed recently
	call	ringchk 	;check ring indicator
	test	parm4,emis
	jz	chkf1
	mov	al,1		;poll emis handler
	call	emisint
chkf1:	call	qckch		;see if time has changed
	jz	chkfile2
	call	showck		;update status line

chkfile2: test	tflag,f1src		;is file an active source?
	jz	chkty			;no -- continue
	test	tflag,lwait+tdelay	;waiting for line?
	jnz	chkfile3		;yes -- ignore file input
	call	isxonw			;waiting for xon?
	jnz	chkfile3		;wait
	test	parm3,pause		;temp pause?
	jnz	chkfile3		;yes --

	call	isctsw			;waiting for clear-to-send?
	jz	chkdof			;no -- go read char
	call	rtson			; ask permission to send
	jmp	chkfile3		; -- don't get file chr now

chkdof: call	fread		;get the char
	or	ah,ah		;rc = 0 ?
	jnz	frdoff		;no -- egads
	mov	ah,fromf1	;indicate char from file1
	jmp	process

frdoff: and	tflag,255-f1src ;turn off active in-file flag
	mov	msgnum,84	;eof reached

	test	parm3,ptrans
	jz	frdoff2
	call	pr_eof		;finished sending file
	jmp	chkfile3

frdoff2: test	parm4,protrts	;squelch rts at end of file send (not ptrans)
	jz	chkfile3
	call	rtsoff

chkfile3: jmp	loop

chkty:	test	tflag,t1src	;"type" cmnd active?
	jz	chkcmnd 	;no
	call	fread		;get the char
	or	ah,ah		;rc = 0 ?
	jnz	typoff1 	;no -- egads
	mov	ah,fromt1	;indicate char from file1 for display only
	jmp	process

typoff1: mov	msgnum,84	;eof reached
	and	tflag,255-t1src ;turn off active in-file flag
	jmp	loop		;and continue


;	call command processor to continue command file execution
;	(may not be active, but we don't know)
chkcmnd:
	test	tflag,cmsleep		;is file sleeping?
	jz	chkcm3			;nope -- go check it
	mov	si,offset slepc
	call	chktime
	jz	chkcm4			;sleep some more

	and	tflag,255-cmsleep	;clear it
	mov	msgnum,-1		;clear msg area (probable sleep msg

chkcm3: test	tflag,cmsleep+xmita+lwait+tdelay+f1src	;any reason to wait?
	jnz	chkcm4				;yes
	test	parm4,trcmnd		;transaction blocking cmnd file?
	jz	chkcm3a 		;no --
	mov	si,offset trtmc 	;check timer
	call	chktime
	jz	chkcm4			;not timed out yet
	and	parm4,255-trcmnd	;timed out -- continue cmnd file
	mov	msgnum,-1		;clear msg area

chkcm3a:call	cmcont
chkcm4:
	test	tflag,pfexit	;shall we continue?
	jnz	ex0
	jmp	loop


;------ let each possible sink look at the char in ax (ah indicates source
process:
	or	parm3,rtimer	;invalidate timer
	call	waiter		;check for line turnaround

	call	ctl_action	;interpret ctrl chars that don't affect scrn

	test	ah,fromc1
	jnz	pro2
	mov	si,offset sendc
	test	parm3,ptrans
	jz	pro1
	mov	si,offset pr_send
pro1:	call	si		;com1 sender

pro2:	call	ansback 	;check for answerback char
	test	parm3,screen	;display ?
	jz	pro3		; no
	call	window		;current screen window

pro3:	call	capfile1	;capture file 1

	test	parm4,trcmnd	;transaction -- waiting for match?
	jz	pro4		;no
	call	trprocess	;check for match

pro4:	test	tflag,pfexit	;shall we continue?
	jnz	ex0
	jmp	loop		;yes --

ex0:	test	tflag,fcap	;active capture flag?
	jz	ex1		;no
	call	wrtclose	;yes
	call	pmsg

ex1:	call	cm_restore
	call	rdfclose	;close (possibly open) read files
	call	frestore	;restore file error handlers

	test	parm4,emis		;tell emis to shut up?
	jz	ex2			;no
	mov	cl,wndc_lc
	mov	dl,wndc_rc
	mov	ch,0			;leave no room for window
	mov	dh,0
	mov	al,3			;window select
	call	emisint

ex2:	mov	ah,33h		;restore ctrl-break setting
	mov	al,1
	mov	dl,brkstate
	int	21h

;	now clear entire screen
	mov	al,4		;whole screen window
	call	wswitch
	mov	nattr_val,7	;use normal screen attributes
	mov	bckgrnd_val,0
	call	nattr		;set normal attribute
	call	vid_init	;set border
	mov	al,12		;clear screen
	call	display
dosexit:
	ret			;return to dos
start	endp


;------ chktime: see if time doubleword pointed to by si is greater
;	than current time, and clear zf iff it is,
;	i.e. if zf then time not up
;
;	Note wholesale slaughter of registers
;
chktime proc	near

	mov	ah,2ch			;"get time" dos function
	int	21h			;into cx, dx

	or	ch,ch			;isit the zero hour?
	jnz	chktb			;no
	cmp	byte ptr [si+1],23	;did we roll
	je	chkta			;yes -- (go)
	jmp	chktc			;no --

chktb:	cmp	ch,23			;check for roll the other way
	jne	chktc
	cmp	byte ptr [si+1],0
	je	chkt2			;wait some more

chktc:	cmp	cx,[si] 		;check normal hours
	jb	chkt2			;wait more
	ja	chkta			;no mo wait
	cmp	dx,[si+2]
	ja	chkta			;no mo wait
	jmp	chkt2			;wait more

chkta:	or	si,si			;clear zf
	jmp	chktd

chkt2:	cmp	si,si			;set zf

chktd:	ret
chktime endp

cm_code ends
end	start
