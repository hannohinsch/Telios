;------ pf key interpreter
;	(C) Copyright 1984  Hanno Hinsch

	public	ctl_action
	public	altkeys

cm_data segment public 'code'

allocate = 0
include data.pub


cm_data ends

cm_code segment  public 'code'

assume	cs: cm_code
assume	ds: cm_data

extrn	helpscrn:near,cmndf2:near
extrn	status:near,dofshow:near
extrn	cm_break:near
extrn	prtog:near,fcaptog:near

extrn	pageup:near,pagedn:near,pghome:near,pgend:near,lineup:near
extrn	linedn:near,dpage:near

extrn	em_cuu:near,em_cud:near,em_cuf:near,em_cub:near

;------ ctl_action: interpret ctrl characters that don't affect screen
;	needs to eventually deal w/ fromctl chars as well
ctl_action proc    near
	test	ah,frompfk+fromctl    ;is ctrl char?
	jnz	c_ina		 ;yes --
	jmp	c_inx		 ;no -- ignore chr

c_ina:	call	altkeys
	call	i_ctrl
c_inx:
	ret
ctl_action endp

;------ altkeys: process those "frompfk" characters that need interpretation
;	in both command and conversation modes
altkeys proc	near
	test	ah,frompfk
	jnz	c_ind0
	jmp	ak_inx

c_ind0: cmp	al,46		;alt-c?
	jne	c_ind1
	test	parm4,qinact	;are we in qinput?
	jnz	c_ind0a 	;yes -- don't go into command mode
	call	cmndf2
c_ind0a:mov	ah,kill 	;claim this char
	jmp	ak_inx

c_ind1:  cmp	 al,35		 ;alt-h?
	jne	c_ind2
	call	helpscrn
	test	parm4,qinact	;are we in qinput?
	jnz	c_ind1a 	;yes -- don't go into command mode
	call	cmndf2
c_ind1a:mov	ah,kill 	;claim this char
	jmp	ak_inx

c_ind2:  cmp	 al,31		 ;alt-s?
	jne	c_ind3
	call	status
	test	parm4,qinact	;are we in qinput?
	jnz	c_ind2a 	;yes -- don't go into command mode
	call	cmndf2
c_ind2a:mov	ah,kill 	;claim this char
	jmp	ak_inx

c_ind3:  cmp	 al,33		 ;alt-f
	jne	c_ind4
	call	dofshow
	test	parm4,qinact	;are we in qinput?
	jnz	c_ind3a 	;yes -- don't go into command mode
	call	cmndf2
c_ind3a:mov	ah,kill 	;claim this char
	jmp	ak_inx

c_ind4:

	cmp	al,119		;ctrl-home?
	jne	c_ind5
	jmp	ak_inx		; *** no action

c_ind5: cmp	al,114		;ctrl-prt-sc?
	jne	c_ind6		 ;no
	call	prtog
	mov	ah,kill 	;claim this char
	jmp	ak_inx

c_ind6: cmp	al,48		;alt-b?
	jne	c_ind7
	call	cm_break
	mov	ah,kill 	;claim this char
	jmp	ak_inx

c_ind7: cmp	al,20		;alt-t
	jne	c_ind8
	call	fcaptog
	mov	ah,kill 	;claim this char
	jmp	ak_inx

c_ind8:
ak_inx:
	ret
altkeys endp


;------ i_ctrl: interpret local control chars from pfk
;	this group depends on terminal state
i_ctrl	  proc	  near
	test	ah,frompfk	;is ctrl char?
	jnz	pfka		;yes --
	jmp	pfkx2		;no -- ignore chr

pfka:	cmp	termtype,dost
	jne	ic0
	jmp	pfkx2		;doesn't work w/ term dos

ic0:	cmp	al,c_pgup	;page up?
	jne	pfkd7		;no
	call	pageup
	jmp	pfkx

pfkd7:	cmp	al,c_pgdn	;page down?
	jne	pfkd8		;no
	call	pagedn
	jmp	pfkx

pfkd8:	cmp	al,c_home	;Home?
	jne	pfkd11		;no
	call	pghome
	jmp	pfkx

pfkd11: cmp	al,c_end	;End?
	jne	pfkd12		;no
	call	pgend
	jmp	pfkx

pfkd12: cmp	al,c_ctpgup	;ctrl page up?
	jne	pfkd13		;no
	call	lineup
	jmp	pfkx2

pfkd13: cmp	al,c_ctpgdn	;ctrl page down?
	jne	pfkd14		;no
	call	linedn
	jmp	pfkx

pfkd14: cmp	al,c_up
	jne	pfkd15
	test	parmf,hecho		;host echo?
	jnz	pfkx2			;yup -- no action
	mov	emuparm[0],0
	call	em_cuu
	jmp	pfkx2			;don't kill char

pfkd15: cmp	al,c_dn
	jne	pfkd16
	test	parmf,hecho		;host echo?
	jnz	pfkx2			;yup -- no action
	mov	emuparm[0],0
	call	em_cud
	jmp	pfkx2			;don't kill char

pfkd16: cmp	al,c_left
	jne	pfkd17
	test	parmf,hecho		;host echo?
	jnz	pfkx2			;yup -- no action
	mov	emuparm[0],0
	call	em_cub
	jmp	pfkx2			;don't kill char

pfkd17:
	cmp	al,c_rt
	jne	pfkd18
	test	parmf,hecho		;host echo?
	jnz	pfkx2			;yup -- no action
	mov	emuparm[0],0
	call	em_cuf
	jmp	pfkx2			;don't kill char

pfkx2:	jmp	pfkx3			;reachable

pfkd18:
	cmp	al,c_a9
	jne	pfkd19
	test	parmf,hecho		;host echo?
	jnz	pfkx2			;yup -- no action
	mov	emuparm[0],0
	call	em_cuu
	jmp	pfkx2			;don't kill char

pfkd19:
	cmp	al,c_a0
	jne	pfkd20
	test	parmf,hecho		;host echo?
	jnz	pfkx2			;yup -- no action
	mov	emuparm[0],0
	call	em_cud
	jmp	pfkx2			;don't kill char

pfkd20:
	cmp	al,c_adash
	jne	pfkd21
	test	parmf,hecho		;host echo?
	jnz	pfkx2			;yup -- no action
	mov	emuparm[0],0
	call	em_cub
	jmp	pfkx2			;don't kill char

pfkd21:
	cmp	al,c_aequ
	jne	pfkd22
	test	parmf,hecho		;host echo?
	jnz	pfkx2			;yup -- no action
	mov	emuparm[0],0
	call	em_cuf
	jmp	pfkx2			;don't kill char

pfkd22:
	jmp	pfkx3


pfkx:	mov	ah,kill 	;claim this char
pfkx3:	ret
i_ctrl	  endp


cm_code ends
end

