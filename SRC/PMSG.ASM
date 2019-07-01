;------ print message

	public	pmsg
	public	smsg

text	macro	num,message
msg&num dw	msgz&num-msga&num
msga&num db	message
msgz&num db	?
endm

cm_data segment public 'code'

allocate = 0
include data.pub

	text	1,<7,'           Internal error #1 (PMSG'>
	text	2,<7,'                    File not found'>
	text	3,<7,'                Incorrect filename'>
	text	4,<7,'                         Disk full'>
	text	5,<7,'               File directory full'>
	text	6,<7,'                 File close failed'>
	text	7,<7,'             Internal error #5 (Xm'>
	text	8,<'             Break signal received'>
	text	9,<7,'                Buffer nearly full'>
	text	10,<7,'             Buffer has overflowed'>
	text	11,<7,'Proper async adaptor not installed'>
	text	12,<'             Parity error detected'>
	text	13,<'            Framing error detected'>
	text	14,<7,'        Character overrun detected'>
	text	15,<'                    Line connected'>
	text	16,<'                 Line disconnected'>
	text	17,<'                   Sending file...'>
	text	18,<7,'         Internal error #6 (PROT'>
	text	19,<'           Capture to file started'>
	text	20,<'           Capture to file stopped'>
	text	21,<7,'          Internal error #2 (ASYNC'>
	text	22,<7,'                   Unknown command'>
	text	23,<7,'          Incorrect command option'>
	text	24,<'         Executing command file...'>
	text	25,<'   Remember: Press alt-H for HELP!'>
	text	26,<'                 Ready for command'>
	text	27,<7,'            Command option missing'>
	text	28,<7,'                    Path not found'>
	text	29,<'                    Echo turned on'>
	text	30,<'                   Echo turned off'>
	text	31,<'                  Filter turned on'>
	text	32,<'                 Filter turned off'>
	text	33,<'                  Autolf turned on'>
	text	34,<'                 Autolf turned off'>
	text	35,<'                 Parity set to ODD'>
	text	36,<'                Parity set to EVEN'>
	text	37,<'               Parity set to SPACE'>
	text	38,<'                Parity set to MARK'>
	text	39,<'        Parity checking turned off'>
	text	40,<'                              Ok  '>
	text	41,<'          Turnaround character set'>
	text	42,<'  Turnaround chr. checking stopped'>
	text	43,<'              Baud rate set to 110'>
	text	44,<'              Baud rate set to 150'>
	text	45,<'              Baud rate set to 300'>
	text	46,<'              Baud rate set to 600'>
	text	47,<'             Baud rate set to 1200'>
	text	48,<'             Baud rate set to 2400'>
	text	49,<'             Baud rate set to 4800'>
	text	50,<'             Baud rate set to 9600'>
	text	51,<7,'               Too many open files'>
	text	52,<7,'                     Access denied'>
	text	53,<7,'               Insufficient memory'>
	text	54,<7,'            No active capture file'>
	text	55,<'Conversation mode (alt-H ==> Help)'>
	text	56,<'              Data capture resumed'>
	text	57,<'            Data capture suspended'>
	text	58,<7,'               File already exists'>
	text	59,<7,'        Unexpected error (fsetmsg)'>
	text	60,<'                   Printer started'>
	text	61,<'                   Printer stopped'>
	text	62,<7,'     Not accepted--waiting for XON'>
	text	63,<'                       Sleeping...'>
	text	64,<'       Waiting for turnaround chr.'>
	text	65,<'          Turnaround wait time set'>
	text	66,<7,'          Internal error #3 (ASYNC'>
	text	67,<7,'          Internal error #4 (ASYNC'>
	text	68,<7,'           Invalid drive specified'>
	text	69,<7,'          Too many command options'>
	text	70,<7,'          Global erase not allowed'>
	text	71,<'                         Erased OK'>
	text	72,<'          Xon/Xoff sending enabled'>
	text	73,<'  Xon/Xoff flow control not in use'>
	text	74,<7,'    XOFF sent (buffer nearly full)'>
	text	75,<7,'    XON sent (buffer nearly empty)'>
	text	76,<'                    Typing file...'>
	text	77,<7,'           Disk is write protected'>
	text	78,<7,'                   Drive not ready'>
	text	79,<7,'                        Data error'>
	text	80,<7,'                        Seek error'>
	text	81,<7,'                  Sector not found'>
	text	82,<7,'                       Write fault'>
	text	83,<7,'              General disk failure'>
	text	84,<'                       End of file'>
	text	85,<'         Routing all chrs. to file'>
	text	86,<'    Routing received chrs. to file'>
	text	87,<'        Routing sent chrs. to file'>
	text	88,<'   Obey Xon/Xoff signals from host'>
	text	89,<'    Xon/Xoff in use by host+Telios'>
	text	90,<'     Null line expansion turned on'>
	text	91,<'    Null line expansion turned off'>
	text	92,<'           Clock display turned on'>
	text	93,<'          Clock display turned off'>
	text	94,<'            Connection timer reset'>
	text	95,<'                          Saved OK'>
	text	96,<7,'      Press alt-P to stop transfer'>
	text	97,<'                       Timeout set'>
	text	98,<7,'                    Packet timeout'>
	text	99,<7,'                  Resending packet'>
	text	100,<'                   Packet verified'>
	text	101,<7,'               Retry limit reached'>
	text	102,<'                Packet received OK'>
	text	103,<7,'            Received packet NOT OK'>
	text	104,<'                       Packet sent'>
	text	105,<7,'      Transfer aborted by receiver'>
	text	106,<7,'                  Transfer aborted'>
	text	107,<7,'                 Transfer complete'>
	text	108,<'                   Retry limit set'>
	text	109,<'             Normal screen display'>
	text	110,<'               Mute screen display'>
	text	111,<'            Graphic screen display'>
	text	112,<'          Xmodem protocol selected'>
	text	113,<'          Kermit protocol selected'>
	text	114,<'                Port COM1 selected'>
	text	115,<'                Port COM2 selected'>
	text	116,<7,'     Not accepted--keyboard locked'>
	text	117,<'                     Tab stops set'>
	text	118,<'           Emulating ADM1 terminal'>
	text	119,<'            Emulating NIH terminal'>
	text	120,<'          Emulating VT100 terminal'>
	text	121,<'  Emulating normal (dumb) terminal'>
	text	122,<'Chatter: show packet sequence msgs'>
	text	123,<'   Chatter: show packet debug msgs'>
	text	124,<'    Chatter: no packet msg display'>
	text	125,<'         EOF: binary mode selected'>
	text	126,<'           EOF: text mode selected'>
	text	127,<'      Using DOS terminal emulation'>
	text	128,<7,'      FATAL ERROR: 8-bit data lost'>
	text	129,<7,'              Printer out of paper'>
	text	130,<7,'                        Read fault'>
	text	131,<7,'         Unexpected critical error'>
	text	132,<7,'                   Not same device'>
	text	133,<'           Emulating VT52 terminal'>
	text	134,<'  Sending cursor key codes to host'>
	text	135,<'  Cursor key transmission disabled'>
	text	136,<7,'    Command abbreviation too short'>
	text	137,<7,'                  Missing filename'>
	text	138,<7,'        Waiting for keyboard input'>
	text	139,<7,'                   Label not found'>
	text	140,<'           Transaction in progress'>
	text	141,<7,'        Too many TRCASE statements'>
	text	142,<'           Emulating 3101 terminal'>
	text	143,<'                   Window size set'>
	text	144,<7,'        EMIS handler not installed'>
	text	145,<7,'      Previous DOPROC still active'>
	text	146,<'          Emulating TI931 terminal'>
	text	147,<7,'  Press alt-P to stop command file'>
	text	148,<'       RTS/CTS flow control in use'>
	text	149,<7,'         Waiting for Clear-To-Send'>



msga	dw	offset	msg1
	dw	offset	msg2
	dw	offset	msg3
	dw	offset	msg4
	dw	offset	msg5
	dw	offset	msg6
	dw	offset	msg7
	dw	offset	msg8
	dw	offset	msg9
	dw	offset	msg10
	dw	offset	msg11
	dw	offset	msg12
	dw	offset	msg13
	dw	offset	msg14
	dw	offset	msg15
	dw	offset	msg16
	dw	offset	msg17
	dw	offset	msg18
	dw	offset	msg19
	dw	offset	msg20
	dw	offset	msg21
	dw	offset	msg22
	dw	offset	msg23
	dw	offset	msg24
	dw	offset	msg25
	dw	offset	msg26
	dw	offset	msg27
	dw	offset	msg28
	dw	offset	msg29
	dw	offset	msg30
	dw	offset	msg31
	dw	offset	msg32
	dw	offset	msg33
	dw	offset	msg34
	dw	offset	msg35
	dw	offset	msg36
	dw	offset	msg37
	dw	offset	msg38
	dw	offset	msg39
	dw	offset	msg40
	dw	offset	msg41
	dw	offset	msg42
	dw	offset	msg43
	dw	offset	msg44
	dw	offset	msg45
	dw	offset	msg46
	dw	offset	msg47
	dw	offset	msg48
	dw	offset	msg49
	dw	offset	msg50
	dw	offset	msg51
	dw	offset	msg52
	dw	offset	msg53
	dw	offset	msg54
	dw	offset	msg55
	dw	offset	msg56
	dw	offset	msg57
	dw	offset	msg58
	dw	offset	msg59
	dw	offset	msg60
	dw	offset	msg61
	dw	offset	msg62
	dw	offset	msg63
	dw	offset	msg64
	dw	offset	msg65
	dw	offset	msg66
	dw	offset	msg67
	dw	offset	msg68
	dw	offset	msg69
	dw	offset	msg70
	dw	offset	msg71
	dw	offset	msg72
	dw	offset	msg73
	dw	offset	msg74
	dw	offset	msg75
	dw	offset	msg76
	dw	offset	msg77
	dw	offset	msg78
	dw	offset	msg79
	dw	offset	msg80
	dw	offset	msg81
	dw	offset	msg82
	dw	offset	msg83
	dw	offset	msg84
	dw	offset	msg85
	dw	offset	msg86
	dw	offset	msg87
	dw	offset	msg88
	dw	offset	msg89
	dw	offset	msg90
	dw	offset	msg91
	dw	offset	msg92
	dw	offset	msg93
	dw	offset	msg94
	dw	offset	msg95
	dw	offset	msg96
	dw	offset	msg97
	dw	offset	msg98
	dw	offset	msg99
	dw	offset	msg100
	dw	offset	msg101
	dw	offset	msg102
	dw	offset	msg103
	dw	offset	msg104
	dw	offset	msg105
	dw	offset	msg106
	dw	offset	msg107
	dw	offset	msg108
	dw	offset	msg109
	dw	offset	msg110
	dw	offset	msg111
	dw	offset	msg112
	dw	offset	msg113
	dw	offset	msg114
	dw	offset	msg115
	dw	offset	msg116
	dw	offset	msg117
	dw	offset	msg118
	dw	offset	msg119
	dw	offset	msg120
	dw	offset	msg121
	dw	offset	msg122
	dw	offset	msg123
	dw	offset	msg124
	dw	offset	msg125
	dw	offset	msg126
	dw	offset	msg127
	dw	offset	msg128
	dw	offset	msg129
	dw	offset	msg130
	dw	offset	msg131
	dw	offset	msg132
	dw	offset	msg133
	dw	offset	msg134
	dw	offset	msg135
	dw	offset	msg136
	dw	offset	msg137
	dw	offset	msg138
	dw	offset	msg139
	dw	offset	msg140
	dw	offset	msg141
	dw	offset	msg142
	dw	offset	msg143
	dw	offset	msg144
	dw	offset	msg145
	dw	offset	msg146
	dw	offset	msg147
	dw	offset	msg148
	dw	offset	msg149

msgz	dw	?
tablen	equ	(msgz-msga)/2	;number of messages



cm_data ends

cm_code segment public 'code'
assume	cs:cm_code
assume	ds:cm_data

extrn	display:near,wswitch:near,dpage:near,setcrsr:near
extrn	nattr:near,hilite:near,rvideo:near

;------ pmsg: print message in message window (in reverse video)
;	msgnum contains message number
;	after printing, msgnum is reset to zero
;	if msgnum = -1, then we update window w/ status msg
pmsg	proc	near
	push	ax
	push	cx
	push	dx
	push	si

	mov	ax,msgnum
	or	ax,ax
	jnz	pm0
	jmp	nomsg		;no msg to print

pm0:	mov	al,wndc_id	;save current window id
	push	ax
	mov	al,5		;switch to message window
	call	wswitch

	mov	ax,msgnum
	or	parm2,msgupd	;note message line has been changed
	cmp	ax,-1		; special state flag?
	jne	pm1		;no --

;	print state msg
	and	parm2,255-msgupd		;state msg has been updated
	mov	ax,63		;sleeping
	test	tflag,cmsleep
	jnz	pm1
	mov	ax,24		;executing command file
	test	cmdflg,doact
	jnz	pm1
	mov	ax,76		;typing
	test	tflag,t1src
	jnz	pm1
	mov	ax,17		;sending
	test	tflag,f1src
	jnz	pm1
	mov	ax,26		;command mode
	test	parm2,cmndm
	jnz	pm1
	mov	ax,55		;must be conversation mode
;	if we're in conversation mode, and the clock is off, then we
;	clear the status line to keep monsieur fajman happy
	test	parm2,clkoff
	jz	pm1		;clock on
	mov	al,12
	call	display 	;clear area (normal video)
	jmp	pmex		;and skip town


pm1:	dec	ax		;make origin 0
	cmp	ax,tablen-1	;is number in range?
	jbe	pmsgok		;yes
	mov	ax,0		;no -- print internal error msg #1
pmsgok:
	sal	ax,1		;make word offset
	mov	si,offset msga
	add	si,ax
	mov	si,[si] 	;si:= address of msg


	call	rvideo		;reverse video
	mov	al,12		;clear window
	call	display

	mov	cx,[si] 	;first word is char count
	add	si,2		;point to first char

plp0:	mov	al,[si]
	call	display
	inc	si
	loop	plp0

pmex:	call	nattr		;normal attribute again
	mov	msgnum,0	;reset it
	pop	ax		;recover original window id
	call	wswitch 	;and restore it

nomsg:	pop	si
	pop	dx
	pop	cx
	pop	ax
	ret
pmsg	endp

;------ smsg: print message at current cursor, stripping leading blanks
;	AX contains message number
smsg	proc	near
	push	ax
	push	cx
	push	si

	or	ax,ax
	jz	snomsg		;no msg to print

	dec	ax		;make origin 0
	cmp	ax,tablen-1	;is number in range?
	jbe	smsgok		;yes
	mov	ax,0		;no -- print internal error msg #1
smsgok:
	sal	ax,1		;make word offset
	mov	si,offset msga
	add	si,ax
	mov	si,[si] 	;si:= address of msg

	mov	cx,[si] 	;first word is char count
	add	si,2		;point to first char

	mov	al,32		;get blank
bslp:	cmp	al,[si] 	;search for first non-cntrl char
	jb	splp
	inc	si
	loop	bslp		;note assumption that msg isn't all blank

splp:	mov	al,[si] 	;get char
	call	display 	;write it
	inc	si
	loop	splp		;until done

snomsg: pop	si
	pop	cx
	pop	ax
	ret
smsg	endp

cm_code ends
end
