;------ vt100/vt52 escape sequence decode routine

	public	decode_ansi
	public	decode_vt52

cm_data segment public 'code'

allocate = 0
include data.pub

ten	db	10			;for multiply

esc	equ	27

tstate	db	exp_esc
exp_esc equ	1
exp_eq	equ	2
exp_y	equ	3
exp_x	equ	4
exp_lead equ	5
exp_parm equ	6
exp_g0	equ	7
exp_g1	equ	8

ansi_taba	db	'D'
		dw	offset cm_code:em_cub
		db	'B'
		dw	offset cm_code:em_cud
		db	'C'
		dw	offset cm_code:em_cuf
		db	'H'
		dw	offset cm_code:em_cup
		db	'A'
		dw	offset cm_code:em_cuu
		db	'J'
		dw	offset cm_code:em_ed
		db	'K'
		dw	offset cm_code:em_el
		db	'm'
		dw	offset cm_code:em_sgr
		db	'f'
		dw	offset cm_code:em_cup
		db	'h'
		dw	offset cm_code:em_sm
		db	'l'
		dw	offset cm_code:em_rm
		db	'{'
		dw	offset cm_code:em_pscreen
		db	'g'
		dw	offset cm_code:em_tbc
		db	'n'
		dw	offset cm_code:em_dsr
		db	'c'
		dw	offset cm_code:em_da
		db	'r'
		dw	offset cm_code:em_stbm
		db	'q'
		dw	offset cm_code:em_led
ansi_tabz	equ	this byte


cm_data ends


cm_code segment public	'code'
assume	cs:cm_code
assume	ds:cm_data

extrn	cm_send:near
extrn	em_cup:near
extrn	em_cuu:near
extrn	em_cud:near
extrn	em_cuf:near
extrn	em_cub:near
extrn	em_ed:near
extrn	em_el:near
extrn	em_sgr:near
extrn	em_dsr:near
extrn	em_hts:near
extrn	em_tbc:near
extrn	em_rm:near
extrn	em_sm:near
extrn	em_pscreen:near
extrn	em_tbc:near
extrn	em_hts:near,em_ris:near
extrn	em_ri:near,em_ind:near,em_nel:near
extrn	em_svpos:near,em_rspos:near
extrn	em_da:near,send_da:near
extrn	em_stbm:near
extrn	em_led:near


;------ decode the ansi escape sequences (in the style of vt-100)
;	al contains latest char
decode_ansi proc  near
	push	bx
	push	si
	push	ax

	and	al,7fh		       ;strip parity bit

	cmp	al,10
	je	ans_lf
	cmp	al,11			;new...
	je	ans_lf
	cmp	al,12			;new...
	je	ans_lf

	cmp	al,24			;can
	je	ans_can
	cmp	al,26			;sub
	je	ans_can
	cmp	al,esc
	je	ans_esc

	cmp	al,32
	jae	ans0
	jmp	ans_xa			;ignore other ctrl chars

ans0:	cmp	al,127			;ignore del
	jne	ans1
	jmp	ans_xa

ans1:	cmp	tstate,exp_lead
	jne	ans2
	jmp	ans_st_lead

ans2:	cmp	tstate,exp_parm
	jne	ans3
	jmp	ans_st_parm

ans3:	cmp	tstate,exp_g0
	jne	ans4
	call	set_g0
	mov	tstate,exp_esc
	jmp	ans_x1

ans4:	cmp	tstate,exp_g1
	jne	ans5
	call	set_g1
	mov	tstate,exp_esc
	jmp	ans_x1

ans5:					; we're probably expecting esc, so...
	jmp	ans_xa			; pass char along

ans_lf:
	call	em_ind			;lf handled specially
	jmp	ans_x1			; ?? should lf/nl mode affect this?

ans_can: mov	tstate,exp_esc
	jmp	ans_x1

ans_esc: mov	tstate,exp_lead
	mov	emuparm[0],0
	mov	emuparm[1],0
	jmp	ans_x1


ans_st_parm:
; if al is ';', increment emuparm[0]
; if al is digit, add value of al to current parm
; else execute char

	cmp	al,';'
	je	semi
	cmp	al,'?'                  ;private parm?
	jne	dig00
	mov	al,128			;mark high order bit
	jmp	dig0

dig00:	cmp	al,'0'
	jb	exec
	cmp	al,'9'
	ja	exec
	sub	al,'0'                  ;make numeric

;	digit in al
dig0:	sub	bx,bx
	mov	bl,emuparm[0]
	or	bl,bl
	jnz	dig1
	inc	bl
	mov	emuparm[0],bl

dig1:	push	cx
	push	ax
	mov	cl,al			;save across mul
	mov	al,emuparm[bx]
	mul	ten			;*** note PARM < 127 ***
	jnc	dig2
	or	al,128			;if high bit was on, keep it on
dig2:	add	al,cl			;add new digit
	mov	emuparm[bx],al		;save it
	pop	ax
	pop	cx
	jmp	ans_x1

semi:	sub	bx,bx
	mov	bl,emuparm[0]
	or	bl,bl
	jnz	semi2
	mov	emuparm[1],0		;account for empty first parm
	inc	bl
semi2:	inc	bl
	mov	emuparm[0],bl
	mov	emuparm[bx],0
	jmp	ans_x1

exec:	;find matching char, execute appropriate routine

	mov	si,offset ansi_taba
execlp: cmp	al,[si]
	je	exec2
	add	si,3			 ;point to next final char
	cmp	si,offset ansi_tabz	 ;at end?
	jne	execlp
	mov	tstate,exp_esc
	jmp	ans_xa			 ;char not found

exec2:	inc	si
	mov	si,word ptr [si]	;get address of routine
	call	si			;do it
	mov	tstate,exp_esc
	jmp	ans_x1

ans_st_lead:
	cmp	al,'['                  ;ansi lead-in char
	jne	lead0
	mov	tstate,exp_parm
	jmp	ans_x1

lead0:	cmp	al,'H'                  ;set tab?
	jne	lead1			;no
	call	em_hts
	mov	tstate,exp_esc
	jmp	ans_x1

lead1:	cmp	al,'Z'                  ;identify?
	jne	lead2			;no
	call	send_da
	mov	tstate,exp_esc
	jmp	ans_x1

lead2:	cmp	al,'='                  ;keyboard application mode
	jne	lead3			;no
	or	tkstate,decka
	mov	tstate,exp_esc
	jmp	ans_x1

lead3:	cmp	al,'>'                  ;keyboard numeric mode
	jne	lead4			;no
	and	tkstate,255-decka
	mov	tstate,exp_esc
	jmp	ans_x1

lead4:	cmp	al,'8'                  ;restore cursor?
	jne	lead5			;no
	call	em_rspos
	mov	tstate,exp_esc
	jmp	ans_x1

lead5:	cmp	al,'7'                  ;save cursor?
	jne	lead6			;no
	call	em_svpos
	mov	tstate,exp_esc
	jmp	ans_x1

lead6:	cmp	al,'D'                  ;index?
	jne	lead7			;no
	call	em_ind
	mov	tstate,exp_esc
	jmp	ans_x1

lead7:	cmp	al,'E'                  ;next line?
	jne	lead8			;no
	call	em_nel
	mov	tstate,exp_esc
	jmp	ans_x1

lead8:	cmp	al,'M'                  ;reverse index?
	jne	lead9			;no
	call	em_ri
	mov	tstate,exp_esc
	jmp	ans_x1

lead9:	cmp	al,'c'                  ;reset initial state?
	jne	lead10			;no
	call	em_ris
	mov	tstate,exp_esc
	jmp	ans_x1

lead10: cmp	al,'('                  ;select char set
	jne	lead11
	mov	tstate,exp_g0
	jmp	ans_x1

lead11: cmp	al,')'                  ;select character set
	jne	lead12
	mov	tstate,exp_g1
	jmp	ans_x1

lead12:
leadnf: mov	tstate,exp_esc
	jmp	ans_xa

ans_xa: pop	ax			;restore char
	mov	ah,fromc1
	or	ah,ah
	jmp	ans_x			;char available

ans_x1: pop	ax			;restore char
	cmp	al,al			;no char available
ans_x:
	pop	si
	pop	bx
	ret
decode_ansi endp

set_g0	proc	near
	ret
set_g0	endp

set_g1	proc	near
	ret
set_g1	endp

;------ decode_vt52: char is in al
decode_vt52 proc  near
	push	ax

	and	al,7fh		       ;strip parity bit

	cmp	tstate,exp_esc
	jne	vt1a
	jmp	vt2

vt1a:	cmp	tstate,exp_lead
	jne	vt1b
	jmp	vt3

vt1b:	cmp	tstate,exp_x
	jne	vt1c
	jmp	vt4

vt1c:	cmp	tstate,exp_y
	jne	vt1d
	jmp	vt5

vt1d:	mov	tstate,exp_esc		;unexpected state
	jmp	vtxa



vt2:	cmp	al,esc			;expecting escape
	je	vt2a
	jmp	vtxa
vt2a:	mov	tstate,exp_lead
	jmp	vtx


;	--- actions ---
vt3:	cmp	al,'A'                  ;up
	jne	vt3a
	mov	emuparm,0
	call	em_cuu
	jmp	vt3x

vt3a:	cmp	al,'B'                  ;down
	jne	vt3b
	mov	emuparm,0
	call	em_cud
	jmp	vt3x

vt3b:	cmp	al,'C'                  ;forward
	jne	vt3c
	call	em_cuf
	jmp	vt3x

vt3c:	cmp	al,'D'                  ;backward
	jne	vt3d
	call	em_cub
	jmp	vt3x

vt3d:	cmp	al,'F'                  ;graphics mode (unsupported)
	jne	vt3e
	jmp	vt3x

vt3e:	cmp	al,'G'                  ;graphics mode (unsupported)
	jne	vt3f
	jmp	vt3x

vt3f:	cmp	al,'H'                  ;home cursor
	jne	vt3g
	mov	emuparm,0
	call	em_cup
	jmp	vt3x

vt3g:	cmp	al,'I'                  ;reverse linefeed
	jne	vt3h
	call	em_ri
	jmp	vt3x

vt3h:	cmp	al,'J'                  ;eeop
	jne	vt3i
	mov	emuparm,0
	call	em_ed
	jmp	vt3x

vt3i:	cmp	al,'K'                  ;eeol
	jne	vt3j
	mov	emuparm,0
	call	em_el
	jmp	vt3x

vt3j:	cmp	al,'Y'                  ;cursor position
	jne	vt3k
	mov	tstate,exp_x
	jmp	vtx

vt3k:	cmp	al,'Z'                  ;send identifying sequence
	jne	vt3l			;
	mov	al,'/'
	call	cm_send
	mov	al,'Z'
	call	cm_send
	jmp	vt3x

vt3l:	cmp	al,'='                  ;alt keypad mode
	jne	vt3m			;
	or	tkstate,decka
	jmp	vt3x

vt3m:	cmp	al,'>'                  ;exit alt keypad mode
	jne	vt3n			;
	and	tkstate,255-decka
	jmp	vt3x

vt3n:	cmp	al,'<'                  ;enter ansi mode
	jne	vt3o
	mov	termtype,ansi
	mov	temsg,120		;note switch (for status display)
	mov	tstate,exp_esc
	jmp	vt3x

vt3o:	jmp	vtxa			;unexpected escap sequence

vt3x:	mov	tstate,exp_esc		;no char available; reset state
	jmp	vtx



vt4:	sub	al,31			;expecting x coord
	mov	emuparm[1],al
	mov	tstate,exp_y
	jmp	vtx

vt5:	sub	al,31			;expecting y coord
	mov	emuparm[0],2
	mov	emuparm[2],al
	call	em_cup
	mov	tstate,exp_esc
	jmp	vtx

vtxa:	pop	ax			;restore char
	mov	ah,fromc1
	or	ah,ah			;char available
	jmp	vtx2

vtx:	pop	ax			;restore char
	cmp	al,al			;no char available
vtx2:
	ret
decode_vt52 endp

cm_code ends
end
