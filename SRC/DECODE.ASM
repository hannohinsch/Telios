; route to terminal escape sequenc decoder
;	Copyright (c) 1984 Hanno Hinsch

	public	decode

cm_data segment public 'code'

allocate = 0
include data.pub


cm_data ends

cm_code segment public 'code'
assume	cs:cm_code
assume	ds:cm_data

extrn	decode_931:near,decode_vt52:near,decode_ansi:near
extrn	decode_mai:near,cm_rd:near,decode_emis:near

;------ decode: decode terminal escape sequence into cntrl char
;	clear zf if char available (char in al; source in ah)
decode	proc	near
	call	cm_rd			;get char from comline
	jnz	de00
	jmp	dex

de00:	test	parm3,ptrans
	jnz	de0			;no emulation during protocol transfer
	cmp	termtype,tty
	je	de1
	cmp	termtype,dost
	je	de0
	cmp	termtype,nih
	je	de3
	cmp	termtype,mai
	je	de2
	cmp	termtype,ansi
	je	de3
	cmp	termtype,vt52
	je	de4
	cmp	termtype,ti931
	je	de5
	jmp	dexz			;internal error if we get here


de0:	mov	ah,fromc1
	or	ah,ah			;clear zero flag
	jmp	dex			;no processing required

de1:	test	parm4,emis		;in tty mode, emis mebbe active
	jz	de0
	call	decode_emis
	jmp	dex

;	mai terminal emulation
de2:	call	decode_mai		;clears zf if char available
	jmp	dex

;	ansi terminal emulation
de3:	call	decode_ansi		;clears zf if char available
	jmp	dex

;	vt52 terminal emulation
de4:	call	decode_vt52
	jmp	dex

;	ti931 emulation
de5:	call	decode_931
	jmp	dex

dexz:	cmp	ah,ah			;set zf (no char available)
dex:
	ret
decode	endp

cm_code ends
end
