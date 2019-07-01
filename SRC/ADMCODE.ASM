; decode adm1 terminal escape sequences
;	Copyright (c) 1984 Hanno Hinsch

	public	decode_mai

cm_data segment public 'code'

allocate = 0
include a:data.pub

esc	equ	27

tstate	db	exp_esc
exp_esc equ	1
exp_eq	equ	2
exp_y	equ	3
exp_x	equ	4

cm_data ends

cm_code segment public 'code'
assume	cs:cm_code
assume	ds:cm_data

extrn	em_cup:near
extrn	em_ed:near
extrn	em_el:near
extrn	em_sgr:near


;------ decode_mai: al contains latest char
decode_mai proc near
	push	ax

	and	al,7fh		       ;strip parity bit

	cmp	tstate,exp_esc
	jne	dem1
	jmp	de2a

dem1:	cmp	tstate,exp_eq
	jne	dem2
	jmp	de2b

dem2:	cmp	tstate,exp_y
	jne	dem3
	jmp	de2c

dem3:	cmp	tstate,exp_x
	jne	dem4
	jmp	de2d

dem4:
dem5:	jmp	dmx1			;state error

de2a:	cmp	al,esc
	je	de2a1
	jmp	dmxa

de2a1:	mov	tstate,exp_eq
	jmp	dmx1

de2b:	mov	tstate,exp_esc		;default case
	cmp	al,'='
	je	de2b2			;cursor position
	cmp	al,'*'
	je	de2b1			;clear screen
	cmp	al,':'
	je	de2b1			;alternate clear screen
	cmp	al,'T'
	je	de2b3			;eeol
	cmp	al,'Y'
	je	de2b4			;eeop
	cmp	al,')'
	je	de2b5			;high intensity
	cmp	al,'('
	je	de2b6			;normal intensity

	;not a valid ctrl char, so display it
	jmp	dmxa

de2b1:	mov	emuparm[0],1
	mov	emuparm[1],2		;erase whole screen
	call	em_ed
	jmp	dmx1


de2b2:	mov	tstate,exp_y
	jmp	dmx1

de2b3:					;eeol
	mov	emuparm[0],0
	call	em_el
	jmp	dmx1
de2b4:					;eeop
	mov	emuparm[0],0
	call	em_ed
	jmp	dmx1

de2b5:					;normal attr
	mov	emuparm[0],0
	call	em_sgr
	jmp	dmx1

de2b6:	mov	emuparm[0],1
	mov	emuparm[1],1		;highlite
	jmp	dmx1

de2c:	sub	al,31			;set vertical position
	mov	emuparm[2],al		;move to global parm area
	mov	tstate,exp_x
	jmp	dmx1


de2d:	sub	al,31			;set horz position
	mov	emuparm[1],al		;move to global parm area
	mov	emuparm[0],2		;account for vert pos, as well
	call	em_cup			;set it
	mov	tstate,exp_esc
	jmp	dmx1

dmxa:	pop	ax			;restore char
	mov	ah,fromc1
	or	ah,ah			;char available
	jmp	dmx

dmx1:	pop	ax			;restore char
	cmp	ah,ah			;no char available
dmx:
	ret
decode_mai endp

cm_code ends
end
