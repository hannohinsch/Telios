	public	status
	public	dofshow
	public	fsrefresh		;refresh status/fkey display

cm_data segment public 'code'

allocate = 0
include data.pub

stat_screen_1	equ	25
stat_screen_2	equ	26
fkey_screen_1	equ	50
fkey_screen_2	equ	51


string	macro  label,astring
label	dw	label&z-label&a
label&a db	astring
label&z db	?
	endm


oldwin	db	0

sprefix dw	sprez-sprea
sprea	db	13,10,9,9
sprez	db	?

stat0	dw	stat0z-stat0a
stat0a	db	12
	db	' Status overview',51 dup(' '),'Screen 1 of 2'
	db	13,10,80 dup (205),13,10,10
	db	9,9
stat0z	db	?

stat1	dw	stat1z-stat1a
stat1a	db	12
	db	' Status overview',51 dup(' '),'Screen 2 of 2'
	db	13,10,80 dup (205),13,10,10
	db	9,9
stat1z	db	?

fhead	dw	fheadz-fheada
fheada	db	' Function key definitions',42 dup(' ')
	db	'Screen 1 of 2'
	db	13,10,80 dup (205)
fheadz	db	?

fhead2	dw	fhead2z-fhead2a
fhead2a db	' More string definitions',43 dup(' '),'Screen 2 of 2'
	db	13,10,80 dup (205)
fhead2z db	?

stat2	dw	stat2z-stat2a
stat2a	db	13,10,hilitef
	db	'Alt-S ==> next status screen; Enter ==> conversation mode; or type a command'
	db	nattrf
stat2z	db	?

dire	dw	dirz-dira
dira	db	13,10,hilitef
	db	'Alt-F ==> more definitions; Enter ==> conversation mode; or type a command'
	db	nattrf
dirz	db	?

sth1	dw	sth1z-sth1a
sth1a	db	13,'Chr. handling:',9
sth1z	db	?

sth2	dw	sth2z-sth2a
sth2a	db	13,'Comm. setup:',9
sth2z	db	?

sth3	dw	sth3z-sth3a
sth3a	db	13,'Pacing:',9,9
sth3z	db	?

sth4	dw	sth4z-sth4a
sth4a	db	13,'Screen:',9,9
sth4z	db	?

sth5	dw	sth5z-sth5a
sth5a	db	13,'Prot. setup:',9
sth5z	db	?

sth6	dw	sth6z-sth6a
sth6a	db	13,'Filetype:',9
sth6z	db	?

sth7	dw	sth7z-sth7a
sth7a	db	13,9,9,9,'-- tab ruler --',13,10,10
sth7z	db	?

string	tim,'Timeout:'
string	retr,' Retries:'
string	twshow,'Turnaround wait time set to:'
string	tshow1,'Set to:'
string	tshow2,'  Observed:'
string	lbshow,'  ['
string	rbshow,']'
string	pf1,'F1: '
string	pf2,'F2: '
string	pf3,'F3: '
string	pf4,'F4: '
string	pf5,'F5: '
string	pf6,'F6: '
string	pf7,'F7: '
string	pf8,'F8: '
string	pf9,'F9: '
string	pf10,'F10: '

string	pfs1,'S1: '
string	pfs2,'S2: '
string	pfs3,'S3: '
string	pfs4,'S4: '
string	pfs5,'S5: '
string	pfs6,'S6: '
string	pfs7,'S7: '
string	pfs8,'S8: '
string	pfs9,'S9: '
string	pfs10,'S10: '

string	pfent,'Enter key: '
string	pfbs,'Backspace key: '
string	pfpre,'Dial prefix: '
string	pfnum,'Number: '
string	pfsuf,'Dial suffix: '

string	trig,'Triggers:'
string	pfa,'Answerback: '
string	pfspre,'Send prefix: '
string	pfssuf,'Send suffix: '
string	pfdisc,'Disconnect: '
string	pfconn,'Connect: '
string	pfcher,'Character error: '
string	pfcmer,'Command error: '
string	pftime,'Timeout: '
string	pfring,'Ring: '
string	pfbrk,'Break: '
string	pfprot,'Protocol transfer error: '

cm_data ends


cm_code segment public 'code'
assume	cs:cm_code
assume	ds:cm_data

extrn	dpage:near,display:near,wswitch:near,setcrsr:near,smsg:near
extrn	dstring:near,qwrite:near,rdcrsr:near,emisint:near
extrn	pnum:near,pcntrl:near,crlf:near

;------ fsrefresh: redisplay status or function key screen if we're there
;	called after execution of commands, which may have affected info
fsrefresh proc near
	cmp	scrnum,stat_screen_1
	jne	fsr0
	mov	scrnum,0
	call	status
	jmp	fsrx

fsr0:	cmp	scrnum,stat_screen_2
	jne	fsr1
	mov	scrnum,stat_screen_1	;back up one screen
	call	status
	jmp	fsrx

fsr1:	cmp	scrnum,fkey_screen_1
	jne	fsr2
	mov	scrnum,0		;reinitialize
	call	dofshow
	jmp	fsrx

fsr2:	cmp	scrnum,fkey_screen_2
	jne	fsr3
	mov	scrnum,fkey_screen_1	;cause dofshow increments
	call	dofshow
	jmp	fsrx

fsr3:
fsrx:
	ret
fsrefresh endp


;------ display status screen
status	proc	near
	push	ax
	push	bx
	push	cx
	push	dx
	push	si

	mov	al,wndc_id	;get current window id
	push	ax		;save for exit
	cmp	al,3		;are we already in help window?
	je	st1		;yes -- no need to switch
	mov	al,3		;switch to help window
	call	wswitch

st1:	cmp	scrnum,stat_screen_1
	jne	st0
	jmp	st5			;go do screen 2

st0:	mov	scrnum,stat_screen_1	;status screen 1

	mov	si,offset stat0 	;clear screen and print greeting
	call	qwrite

	mov	ax,prmsg		;last printer msg
	call	smsg

	mov	si,offset sprefix
	call	qwrite
;	we present here a kludge that insures that the cap msg will be ok;
;	there are circumstances in which a cap file is closed but camsg is
;	no updated. We therefore update it here, just in case.
	test	tflag,fcap		;active cap file?
	jnz	st1a			;yes
	mov	ax,54			;"no open cap file" msg
	mov	camsg,ax		;store for posterity
	call	smsg
	jmp	st2			;skip file name display

st1a:	mov	ax,camsg		;last cap file msg
	call	smsg

	mov	si,offset lbshow
	call	qwrite

	mov	cx,cflen		;get length of filename
	mov	si,offset cfname	;point to filename
st1b:	lodsb				;char into al
	call	display
	loop	st1b

	mov	si,offset rbshow
	call	qwrite
st2:

	mov	si,offset sprefix
	call	qwrite
	call	qwrite
	call	qwrite
	mov	si,offset sth2
	call	qwrite
	mov	ax,bamsg
	call	smsg

	mov	si,offset sprefix
	call	qwrite
	mov	ax,pamsg
	call	smsg

	mov	si,offset sprefix
	call	qwrite
	mov	ax,cpmsg			;comm port
	call	smsg

	mov	si,offset sprefix
	call	qwrite
	call	qwrite
	call	qwrite
	mov	si,offset sth1
	call	qwrite
	mov	ax,ecmsg
	call	smsg

	mov	si,offset sprefix
	call	qwrite
	mov	ax,aumsg
	call	smsg

	mov	si,offset sprefix
	call	qwrite
	mov	ax,fimsg
	call	smsg

	mov	si,offset sprefix
	call	qwrite
	mov	ax,exmsg
	call	smsg

	mov	si,offset sprefix
	call	qwrite
	mov	ax,romsg
	call	smsg


	mov	al,10
	call	display
	mov	al,10
	call	display
	mov	al,10
	call	display
	mov	al,10
	call	display
	mov	al,10
	call	display
	mov	si,offset stat2 ;press enter to return msg
	call	qwrite
	jmp	statx

st5:	;do second status screen
	mov	scrnum,stat_screen_2

	mov	si,offset stat1 	;clear screen and print greeting
	call	qwrite

	mov	si,offset sth6
	call	qwrite
	mov	ax,damsg		;data type
	call	smsg

	mov	si,offset sprefix
	call	qwrite
	call	qwrite
	mov	si,offset sth3		;pacing
	call	qwrite
	mov	ax,protmsg		;really "flow" msg
	call	smsg

	mov	si,offset sprefix
	call	qwrite
	mov	ax,tcmsg
	call	smsg

	mov	si,offset lbshow
	call	qwrite

	mov	si,offset tshow1	;show set char
	call	qwrite
	mov	al,turnchr
	call	pcntrl

	mov	si,offset tshow2
	call	qwrite
	mov	al,obtchr	;show observed tchr
	and	al,01111111b	;strip off high bit (not used in compare, either)
	call	pcntrl

	mov	si,offset rbshow	;show ending bracket
	call	qwrite

	mov	si,offset sprefix
	call	qwrite
	mov	si,offset twshow
	call	qwrite
	mov	al,twtime
	call	pnum

	mov	si,offset sprefix
	call	qwrite
	call	qwrite
	mov	si,offset sth5
	call	qwrite
	mov	ax,kxmsg
	call	smsg

	mov	si,offset lbshow
	call	qwrite

	mov	si,offset tim		;timeout
	call	qwrite
	mov	al,timeout
	call	pnum

	mov	si,offset retr		;max retries
	call	qwrite
	mov	al,maxretry
	call	pnum

	mov	si,offset rbshow	;show ending bracket
	call	qwrite

	mov	si,offset sprefix
	call	qwrite
	mov	ax,chmsg		;chatter
	call	smsg

	mov	si,offset sprefix
	call	qwrite
	call	qwrite

	mov	si,offset sth4		;screen header
	call	qwrite
	mov	ax,temsg		;terminal emulation
	call	smsg

	mov	si,offset sprefix
	call	qwrite
	mov	ax,cumsg		;cursor key send
	call	smsg

	mov	si,offset sprefix
	call	qwrite
	mov	ax,scmsg		;screen
	call	smsg

	mov	si,offset sprefix
	call	qwrite
	call	qwrite

	mov	si,offset sth7		;tab ruler msg
	call	qwrite

	mov	si,offset tabarray	;print even numbered tab stops
	sub	bx,bx
	mov	cx,39			;don't print at 78 (won't fit)
st5a1:	cmp	byte ptr [si],0
	je	st5a2
	call	rdcrsr
	mov	dl,bl			;go to this tab stop
	call	setcrsr
	mov	al,bl
	call	pnum
st5a2:	add	bx,2
	add	si,2
	loop	st5a1

	call	crlf
	mov	si,offset tabarray	;print tab line
	mov	cx,80
st5a:	mov	al,196
	cmp	byte ptr [si],0
	je	st5b
	mov	al,215
st5b:	call	display
	inc	si
	loop	st5a

	mov	si,offset tabarray	;print odd numbered tab stops
	inc	si
	mov	bx,1
	mov	cx,39			;skip 79 (it won't fit)
st5b1:	cmp	byte ptr [si],0
	je	st5b2
	call	rdcrsr
	mov	dl,bl			;go to this tab stop
	call	setcrsr
	mov	al,bl
	call	pnum
st5b2:	add	bx,2
	add	si,2
	loop	st5b1


	mov	al,10
	call	display
	mov	si,offset stat2 ;press enter to return msg
	call	qwrite
	jmp	statx


statx:	pop	ax		;go to old window
	call	wswitch

	pop	si
	pop	dx
	pop	cx
	pop	bx
	pop	ax		;restore reg
	ret
status	endp

;------ dofshow: list pf string definitions
dofshow proc	near
	push	ax
	push	si
	mov	al,wndc_id
	mov	oldwin,al
	mov	al,3		;switch to help window
	call	wswitch

	mov	al,12		;clear screen
	call	display

	cmp	scrnum,fkey_screen_1	;on screen 1?
	jne	dof1			;do 1
	jmp	dof2			;do 2

dof1:	mov	scrnum,fkey_screen_1	   ;signal 'clrhelp' that we mucked screen

	mov	si,offset fhead
	call	qwrite
	call	crlf
	mov	al,10
	call	display

	mov	si,offset pf1
	call	qwrite
	mov	al,dpf1 	;pf 1...
	call	dstring
	call	crlf

	mov	si,offset pf2
	call	qwrite
	mov	al,dpf2
	call	dstring
	call	crlf

	mov	si,offset pf3
	call	qwrite
	mov	al,dpf3 	;pf 3...
	call	dstring
	call	crlf

	mov	si,offset pf4
	call	qwrite
	mov	al,dpf4
	call	dstring
	call	crlf

	mov	si,offset pf5
	call	qwrite
	mov	al,dpf5
	call	dstring
	call	crlf

	mov	si,offset pf6
	call	qwrite
	mov	al,dpf6
	call	dstring
	call	crlf

	mov	si,offset pf7
	call	qwrite
	mov	al,dpf7
	call	dstring
	call	crlf

	mov	si,offset pf8
	call	qwrite
	mov	al,dpf8
	call	dstring
	call	crlf

	mov	si,offset pf9
	call	qwrite
	mov	al,dpf9
	call	dstring
	call	crlf

	mov	si,offset pf10
	call	qwrite
	mov	al,dpf10
	call	dstring
	call	crlf
	mov	al,10
	call	display

	mov	si,offset pfpre
	call	qwrite
	mov	al,dpfpr	;dial prefix
	call	dstring
	call	crlf

	mov	si,offset pfnum
	call	qwrite
	mov	al,dpfnum	;tel number
	call	dstring
	call	crlf

	mov	si,offset pfsuf
	call	qwrite
	mov	al,dpfsuf	;dial suffix
	call	dstring
	call	crlf
	mov	al,10
	call	display

	mov	si,offset pfbs
	call	qwrite
	mov	al,dpfbs	;backspace key
	call	dstring
	call	crlf

	mov	si,offset pfent
	call	qwrite
	mov	al,dpfent	;enter key
	call	dstring
	call	crlf


	mov	al,10
	call	display
	mov	si,offset dire
	call	qwrite
	jmp	dofx

dof2:	mov	scrnum,fkey_screen_2	   ;do second screen

	mov	si,offset fhead2
	call	qwrite
	call	crlf
	mov	al,10
	call	display

	mov	si,offset pfs1
	call	qwrite
	mov	al,dpfs1
	call	dstring
	call	crlf

	mov	si,offset pfs2
	call	qwrite
	mov	al,dpfs2
	call	dstring
	call	crlf

	mov	si,offset pfs3
	call	qwrite
	mov	al,dpfs3
	call	dstring
	call	crlf

	mov	si,offset pfs4
	call	qwrite
	mov	al,dpfs4
	call	dstring
	call	crlf

	mov	si,offset pfs5
	call	qwrite
	mov	al,dpfs5
	call	dstring
	call	crlf

	mov	si,offset pfs6
	call	qwrite
	mov	al,dpfs6
	call	dstring
	call	crlf

	mov	si,offset pfs7
	call	qwrite
	mov	al,dpfs7
	call	dstring
	call	crlf

	mov	si,offset pfs8
	call	qwrite
	mov	al,dpfs8
	call	dstring
	call	crlf

	mov	si,offset pfs9
	call	qwrite
	mov	al,dpfs9
	call	dstring
	call	crlf

	mov	si,offset pfs10
	call	qwrite
	mov	al,dpfs10
	call	dstring
	call	crlf

	call	crlf
	mov	si,offset pfring
	call	qwrite
	mov	al,dpfring     ;ring indicator
	call	dstring
	call	crlf

	mov	si,offset pfa
	call	qwrite
	mov	al,dpfa        ;answerback
	call	dstring
	call	crlf

	mov	al,10
	call	display
	mov	al,10
	call	display
	mov	al,10
	call	display
	mov	al,10
	call	display
	mov	al,10
	call	display
	mov	si,offset dire
	call	qwrite

dofx:	mov	al,oldwin	;switch back to old window
	call	wswitch

	pop	si
	pop	ax
	ret
dofshow endp


cm_code ends
end
