;------ terminal emulation functions
;	(C) Copyright 1984  Hanno Hinsch

	public	em_cup
	public	em_cuu
	public	em_cud
	public	em_cuf
	public	em_cub
	public	em_ed
	public	em_el
	public	em_cpr
	public	em_sgr
	public	em_hts
	public	em_tbc
	public	em_sm
	public	em_rm
	public	em_pscreen
	public	em_ri
	public	em_ind
	public	em_nel
	public	em_dsr
	public	em_ris
	public	em_stbm
	public	em_da
	public	send_da
	public	em_led
	public	em_svpos
	public	em_rspos

cm_data segment public 'code'

allocate = 0
include data.pub

ten	db	10			;for div instruction

crt_lc	equ	0
crt_rc	equ	79
crt_tr	equ	0
crt_br	equ	23

top_mgn db	0			;top and bottom margins
bot_mgn db	23

saved_crsr	dw	0		;for em_svpos/em_rspos
saved_attr	db	0

cm_data ends

cm_code segment  public 'code'

assume	cs: cm_code
assume	ds: cm_data

extrn	wsetcrsr:near,wrdcrsr:near
extrn	nattr:near,hilite:near,rvideo:near,getattr:near,setattr:near
extrn	beeol:near,beeop:near,bebol:near,bebop:near,beall:near
extrn	setupd:near
extrn	bscroll:near,bdscroll:near,bpscroll:near
extrn	cm_send:near

;------ em_cup: set cursor (note that parms are origin 1, NOT 0)
em_cup	proc	near
	push	dx

	sub	dx,dx			;default is 0,0
	cmp	emuparm[0],0
	je	cuset
	mov	dh,emuparm[1]
	or	dh,dh
	jz	cu1
	dec	dh
	cmp	dh,crt_br
	jbe	cu1
	mov	dh,crt_tr	       ;illegal row --> set to 0

cu1:	cmp	emuparm[0],1
	je	cuset
	mov	dl,emuparm[2]
	or	dl,dl
	jz	cu2
	dec	dl
	cmp	dl,crt_rc
	jbe	cu2
	mov	dl,crt_lc	       ;illegal col --> set to 0

cu2:	cmp	emuparm[0],2		;only 2 allowed
	je	cuset
	jmp	cux

cuset:	test	tkstate,decom		;correct for origin ?
	jz	cu3
	add	dh,top_mgn
	cmp	dh,bot_mgn
	jbe	cu3
	mov	dh,bot_mgn
cu3:	call	wsetcrsr
cux:

	pop	dx
	ret
em_cup	endp

;------ em_cuu: cursor up
em_cuu	proc	near
	push	ax
	push	dx

	call	wrdcrsr

	mov	al,1			;default is up one
	cmp	emuparm[0],0
	je	uuset			;default
	cmp	emuparm[0],1
	jne	uux			;only 1 parm supported
	mov	al,emuparm[1]
	or	al,al
	jnz	uuset
	mov	al,1			; zero becomes one

uuset:	sub	dh,al
	js	uux
	test	tkstate,decom		;enforce window bound if org mode
	jz	uuset1
	cmp	dh,top_mgn
	jge	uuset1
	mov	dh,top_mgn
uuset1: call	wsetcrsr

uux:
	pop	dx
	pop	ax
	ret
em_cuu	endp

;------ em_cud: cursor down
em_cud	proc	near
	push	ax
	push	dx

	call	wrdcrsr

	mov	al,1			;default is one
	cmp	emuparm[0],0
	je	udset			;default
	cmp	emuparm[0],1
	jne	udx			;only 1 parm supported
	mov	al,emuparm[1]
	or	al,al
	jnz	udset
	mov	al,1			; zero becomes one

udset:	add	dh,al
	cmp	dh,crt_br
	ja	udx
	test	tkstate,decom		;enforce window if origin mode
	jz	udset1
	cmp	dh,bot_mgn
	jle	udset1
	mov	dh,bot_mgn
udset1: call	wsetcrsr

udx:
	pop	dx
	pop	ax
	ret
em_cud	endp

;------ em_cuf: cursor forward
em_cuf	proc	near
	push	ax
	push	dx

	call	wrdcrsr

	mov	al,1			;default is one
	cmp	emuparm[0],0
	je	ufset			;default
	cmp	emuparm[0],1
	jne	ufx			;only 1 parm supported
	mov	al,emuparm[1]
	or	al,al
	jnz	ufset
	mov	al,1			; zero becomes one

ufset:	add	dl,al
	cmp	dl,crt_rc
	jle	ufset1
	mov	dl,crt_rc	       ;can't be beyond right column
ufset1: call	wsetcrsr

ufx:
	pop	dx
	pop	ax
	ret
em_cuf	endp

;------ em_cub: move backwards
em_cub	proc	near
	push	ax
	push	dx

	call	wrdcrsr

	mov	al,1			;default is one
	cmp	emuparm[0],0
	je	ubset			;default
	cmp	emuparm[0],1
	jne	ubx			;only 1 parm supported
	mov	al,emuparm[1]
	or	al,al
	jnz	ubset
	mov	al,1			; zero becomes one

ubset:	sub	dl,al
	cmp	dl,crt_lc
	jge	ubset1
	mov	dl,crt_lc
ubset1: call	wsetcrsr

ubx:
	pop	dx
	pop	ax
	ret
em_cub	endp

;------ em_ed: erase in display
em_ed	proc	near
	cmp	emuparm[0],0
	je	ed0			;clear to end of screen
	cmp	emuparm[0],1
	jne	edx			;only 1 parm supported
	cmp	emuparm[1],0
	je	ed0			;clear to end of screen
	cmp	emuparm[1],1
	je	ed1			;clear top
	cmp	emuparm[1],2
	je	ed2			;clear whole screen
	jmp	edx

ed2:	call	beall			;whole screen
	jmp	edx

ed1:	call	bebop			;from start to active, inclusive
	jmp	edx

ed0:	call	beeop			;to end of screen
	jmp	edx

edx:
	ret
em_ed	endp

;------ em_el: erase in line
em_el	proc	near
	cmp	emuparm[0],0
	je	el0			;clear to end
	cmp	emuparm[0],1
	jne	elx			;only 1 parm supported
	cmp	emuparm[1],0
	je	el0			;clear to end
	cmp	emuparm[1],1
	je	el1			;clear to start
	cmp	emuparm[1],2
	je	el2			;clear whole
	jmp	elx

el0:	call	beeol
	jmp	elx

el1:	call	bebol
	jmp	elx

el2:	call	beeol
	call	bebol
	jmp	elx

elx:
	ret
em_el	endp

;------ em_dsr: device status report
em_dsr	proc	near
	push	ax
	cmp	emuparm[0],0
	je	dsx			;no good
	cmp	emuparm[0],1
	jne	dsx			;only 1 parm supported
	cmp	emuparm[1],5
	je	ds5			;report status
	cmp	emuparm[1],6
	je	ds6			;send cpr
	jmp	dsx

ds5:	mov	al,27			;send dsr report to host
	call	cm_send
	mov	al,'['
	call	cm_send
	mov	al,'0'
	call	cm_send
	mov	al,'n'
	call	cm_send
	jmp	dsx

ds6:	call	em_cpr			;send cursor position report

dsx:
	pop	ax
	ret
em_dsr	endp

;------ em_cpr: send vt-100 cursor position report to host
;	*** should this be origin dependent?
em_cpr	proc	near
	push	ax
	push	dx

	mov	al,27			;esc
	call	cm_send
	mov	al,'['
	call	cm_send

	call	wrdcrsr
	mov	al,dh			;rows
	sub	ah,ah
	div	ten			;quotient into al
					;remainder into ah
	add	al,48			;make into digit (and increment)
	call	cm_send
	mov	al,ah
	add	al,48
	call	cm_send

	mov	al,';'                  ;delimiter
	call	cm_send

	mov	al,dl			;columns
	sub	ah,ah
	div	ten			;quotient into al
					;remainder into ah
	add	al,48			;make into digit
	call	cm_send
	mov	al,ah
	add	al,48
	call	cm_send

	mov	al,'R'                  ;cpr final char
	call	cm_send

	pop	dx
	pop	ax
	ret
em_cpr	endp

;------ em_da: device attribute
em_da	proc	near

	cmp	emuparm[0],0
	je	da0
	cmp	emuparm[0],1
	jne	dax			;only 1 parm supported
	cmp	emuparm[1],0
	je	da0
	jmp	dax

da0:	call	send_da
dax:
	ret
em_da	endp

;------ send_da:
send_da proc	near
	push	ax

	mov	al,27			;identify as vt-100, no options
	call	cm_send
	mov	al,'['
	call	cm_send
	mov	al,'?'
	call	cm_send
	mov	al,'1'
	call	cm_send
	mov	al,';'
	call	cm_send
	mov	al,'0'
	call	cm_send
	mov	al,'c'
	call	cm_send

	pop	ax
send_da endp

;------ em_sgr: select graphic rendition (a.k.a. attribute)
;	this doesn't meet ansi spec (should take multiple attributes)
;	underlying mechanism also needs to handle multiple attributes
em_sgr	proc	near
	push	bx
	push	cx

	mov	bx,1			;parm index
	sub	ch,ch
	mov	cl,emuparm[0]		;get number of parms
	or	cx,cx
	jne	sg0
	mov	cx,1			;pretend we had one
	jmp	sg1

sg0:	cmp	emuparm[bx],0
	je	sg1			;normal
	cmp	emuparm[bx],1
	je	sg2			;hilite
	cmp	emuparm[bx],4
	je	sg3			;underscore (***)
	cmp	emuparm[bx],5
	je	sg3			;blink (***)
	cmp	emuparm[bx],7
	je	sg3			;rvideo
	jmp	sgx

sg1:	call	nattr			;normal
	jmp	sgx

sg2:	call	hilite			;hilite
	jmp	sgx

sg3:	call	rvideo			;inverse
	jmp	sgx

sgx:	inc	bx			;point to next parm
	loop	sg1

	pop	cx
	pop	bx
	ret
em_sgr	endp

;------ em_hts: set tab at current position
em_hts	proc	near
	push	bx
	push	dx

	call	wrdcrsr
	sub	bx,bx
	mov	bl,dl			;use col as index
	mov	tabarray[bx],1		;set tab stop

	pop	dx
	pop	bx
	ret
em_hts	endp

;------ em_tbc: clear tab stops
;	parm1 = 0 clears current; parm1 = 3 clears all
em_tbc	proc	near
	push	ax
	push	bx
	push	cx
	push	dx

	cmp	emuparm[0],0
	je	tbc0
	cmp	emuparm[0],1
	jne	tbcx
	cmp	emuparm[1],0
	je	tbc0
	cmp	emuparm[1],3
	je	tbc1
	jmp	tbcx

tbc0:	call	wrdcrsr 		 ; (clear current tab stop)
	sub	bx,bx
	mov	bl,dl
	mov	tabarray[bx],0
	jmp	tbcx

tbc1:	mov	cx,80
	mov	di,offset tabarray
	sub	al,al
	push	ds
	pop	es
	rep	stosb			;clear all tab stops

tbcx:
	pop	dx
	pop	cx
	pop	bx
	pop	ax
	ret
em_tbc	endp

;------ em_rm: reset mode
em_rm	proc	near
	push	ax
	push	bx
	push	cx
	push	dx

	sub	ch,ch
	mov	cl,emuparm[0]			;get # of parms

	mov	bx,1				;parm index
	or	cx,cx
	jnz	rmlp
	jmp	rmx

rmlp:	mov	al,emuparm[bx]
	inc	bx

	or	al,al
	js	rmdec				;dec private
	cmp	al,2
	je	rmkb				;keyboard action
	jmp	rmlpx

rmkb:	and	parm3,255-kblock		;unlock keyboard
	jmp	rmlpx

rmdec:	and	al,255-128			;get rid of dec flag

	cmp	al,1				;cursor key mode?
	jne	rmdec2
	and	tkstate,255-decca		 ;yes -- clr cursor appl mode
	jmp	rmlpx

rmdec2: cmp	al,2				;vt52 mode?
	jne	rmdec3
	mov	termtype,vt52
	mov	temsg,133			;emulating vt52
	jmp	rmlpx

rmdec3: cmp	al,6				;origin mode?
	jne	rmdec4
	and	tkstate,255-decom

	push	dx
	sub	dx,dx
	call	wsetcrsr
	pop	dx
	jmp	rmlpx

rmdec4: cmp	al,7			;auto-wrap at eol?
	jne	rmdec5
	or	tkstate,decaw
	jmp	rmlpx

rmdec5: cmp	al,3			;80 col mode?
	jne	rmdec6			;clear screen/home cursor

	push	dx

	call	beall			;buffer erase all

	sub	dx,dx
	call	wsetcrsr

	pop	dx
	jmp	rmlpx

rmdec6:

rmlpx:	dec	cx			;far "loop" stmt
	jz	rmx
	jmp	rmlp

rmx:
	pop	dx
	pop	cx
	pop	bx
	pop	ax
	ret
em_rm	endp

;------ em_sm: set mode
em_sm	proc	near
	push	ax
	push	bx
	push	cx
	push	dx

	sub	ch,ch
	mov	cl,emuparm[0]			;get # of parms

	jcxz	smx
	mov	bx,1				;parm index

smlp:	mov	al,emuparm[bx]
	inc	bx

	or	al,al
	js	smdec				;dec private
	cmp	al,2
	je	smkb				;keyboard action
	jmp	smlpx

smkb:	or	parm3,kblock			;lock keyboard
	jmp	smlpx

smdec:	and	al,255-128			;get rid of dec flag

	cmp	al,1				;cursor key mode?
	jne	smdec2
	or	tkstate,decca			 ;yes -- set cursor appl mode
	jmp	smlpx

smdec2: cmp	al,6				;origin mode?
	jne	smdec3
	or	tkstate,decom

	push	dx
	mov	dh,top_mgn
	mov	dl,crt_lc
	call	wsetcrsr
	pop	dx

	jmp	smlpx

smdec3: cmp	al,7			;auto-wrap?
	jne	smdec4
	and	tkstate,255-decaw
	jmp	smlpx

smdec4:
smlpx:	loop	smlp

smx:
	pop	dx
	pop	cx
	pop	bx
	pop	ax
	ret
em_sm	endp

;------ em_pscreen: set screen mode (private command)
em_pscreen proc    near
	cmp	emuparm[0],0
	je	pscr0
	cmp	emuparm[0],1
	jne	pscrx
	cmp	emuparm[1],0
	je	pscr0
	cmp	emuparm[1],1
	je	pscr1
	jmp	pscrx

pscr1:	and	parm3,255-screen		;screen mute
	call	setupd				;force status redisplay
	jmp	pscrx

pscr0:	or	parm3,screen			;turn screen on
	call	setupd				;force status redisplay
	jmp	pscrx

pscrx:
	ret
em_pscreen endp

;------ em_ri: reverse index; scroll screen down if at top
em_ri	proc	near
	push	ax
	push	dx

	call	wrdcrsr

	cmp	dh,top_mgn		;we hit top margin ?
	jne	riset0			; nope, check crt bounds
	cmp	dh,crt_tr		;is that same as crt?
	jne	riset2			; no -- definite partial scroll
	mov	al,bot_mgn
	cmp	al,crt_br		;is bottom margin set?
	jne	riset2			; yes -- do partial scroll

riset0: cmp	dh,crt_tr
	je	riset3
	dec	dh
	jmp	riset1

riset2: call	dscroll_m		;scrolling region scroll
	mov	dh,top_mgn
	jmp	riset1

riset3: call	bdscroll		;full screen scroll
	mov	dh,crt_tr

riset1: call	wsetcrsr

	pop	dx
	pop	ax
	ret
em_ri	endp


;------ em_ind: index; scroll screen up if at bottom
em_ind	proc	near
	push	ax
	push	dx

	call	wrdcrsr

	cmp	dh,bot_mgn		;did we hit margin
	jne	ind0			; no -- check crt bound
	cmp	dh,crt_br		;margin same as crt bot?
	jne	ind2			; no -- definite partial scroll
	mov	al,crt_tr		;is top margin set?
	cmp	al,top_mgn
	jne	ind2			;yes -- do partial scroll

ind0:	cmp	dh,crt_br
	je	ind1
	inc	dh
	jmp	indset

ind2:	call	scroll_m		;scrolling region scroll
	mov	dh,bot_mgn
	jmp	indset

ind1:	call	bscroll 		;full screen scroll
	mov	dh,crt_br

indset: call	wsetcrsr

	pop	dx
	pop	ax
	ret
em_ind	endp

;------ em_ris: reset initial state
em_ris	proc	near

	and	tkstate,255-(decca+decka+decom) 	;clear term state
	or	tkstate,decaw				;no autowrap

	mov	top_mgn,0
	mov	bot_mgn,23

	ret
em_ris	endp

;------ em_stbm: set top and bottom margins
em_stbm proc	near
	push	ax
	push	bx
	push	cx
	push	dx

	cmp	emuparm[0],2		;allow 2 parms
	jbe	stb0
	jmp	stbx

stb0:	mov	bh,crt_tr
	mov	bl,crt_br	       ;default

	cmp	emuparm[0],1
	jb	stb3
	mov	bh,emuparm[1]		;top
	or	bh,bh
	jnz	stb1			;zero becomes default
	mov	bh,crt_tr
	inc	bh

stb1:	dec	bh			;make origin 0

	cmp	emuparm[0],2
	jb	stb3
	mov	bl,emuparm[2]		;bottom
	or	bl,bl
	jnz	stb2			;zero becomes default
	mov	bl,crt_br
	inc	bl

stb2:	dec	bl			;make origin 0

	cmp	bl,bh
	ja	stb4			;bot > top
	jmp	stbx

stb4:	cmp	bl,crt_br	       ;max window size
	jbe	stb3
	jmp	stbx

stb3:	mov	top_mgn,bh
	mov	bot_mgn,bl

	mov	dh,crt_tr	       ;home cursor
	test	tkstate,decom		;origin mode?
	jz	stb5
	mov	dh,top_mgn		;yes -- window relative
stb5:
	mov	dl,crt_lc
	call	wsetcrsr


stbx:	pop	dx
	pop	cx
	pop	bx
	pop	ax
	ret
em_stbm endp

;------ em_nel: new line; scroll up if at bottom
em_nel	proc	near
	push	ax
	push	dx

	call	wrdcrsr

	mov	dl,crt_lc

	cmp	dh,bot_mgn		;did we hit margin
	jne	nel0			; no -- go check crt bound
	cmp	dh,crt_br		;margin same as crt bot?
	jne	nel2			; no -- definite partial scroll
	mov	al,crt_tr		;is top margin set?
	cmp	al,top_mgn
	jne	nel2			;yes -- do partial scroll

nel0:	cmp	dh,crt_br
	je	nel3
	inc	dh
	jmp	nelset

nel2:	call	scroll_m		;scrolling region scroll
	mov	dh,bot_mgn
	jmp	nelset

nel3:	call	bscroll 		;full screen scroll

nelset: call	wsetcrsr

	pop	dx
	pop	ax
	ret
em_nel	endp

;------ em_led: light leds (nop)
em_led	proc	near
	ret
em_led	endp

;------ scroll_m: scroll up the area between scrolling margins
scroll_m	proc	near
	push	ax
	push	bx
	push	cx
	push	dx


	mov	bh,top_mgn
	mov	bl,bot_mgn

	mov	al,0			;up
	call	bpscroll		;do screen

	pop	dx
	pop	cx
	pop	bx
	pop	ax
	ret
scroll_m	endp

;------ dscroll_m: scroll down the area between scrolling margins
dscroll_m	 proc	 near
	push	ax
	push	bx
	push	cx
	push	dx


	mov	bh,top_mgn
	mov	bl,bot_mgn

	mov	al,1		      ;down
	call	bpscroll		;do screen

	pop	dx
	pop	cx
	pop	bx
	pop	ax
	ret
dscroll_m	 endp

;------ svpos: save current cursor and attribute
em_svpos proc	 near
	push	ax
	push	dx

	call	wrdcrsr
	mov	saved_crsr,dx
	call	getattr
	mov	saved_attr,al

	pop	dx
	pop	ax
	ret
em_svpos endp

;------ em_rspos: restore cursor and attribute
em_rspos proc	near
	push	ax
	push	dx

	mov	dx,saved_crsr
	call	wsetcrsr
	mov	al,saved_attr
	call	setattr

	pop	dx
	pop	ax
	ret
em_rspos endp

cm_code ends
end

