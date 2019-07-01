; encode terminal escape sequences
;	Copyright 1984 Hanno Hinsch

	public	encode

cm_data segment public 'code'

allocate = 0
include data.pub

ten	db	10			;for multiply

esc	equ	27

up	dw	offset	cm_code:enx	     ;off
	dw	offset	cm_code:a_up	     ;ansi
	dw	offset	cm_code:ti_up	     ;ti931
	dw	offset	cm_code:m_up	     ;mai
	dw	offset	cm_code:i_up	     ;ibm

dn	dw	offset	cm_code:enx	     ;off
	dw	offset	cm_code:a_dn	     ;ansi
	dw	offset	cm_code:ti_dn	     ;ti931
	dw	offset	cm_code:m_dn	     ;mai
	dw	offset	cm_code:i_dn	     ;ibm

left	dw	offset	cm_code:enx	     ;off
	dw	offset	cm_code:a_left	     ;ansi
	dw	offset	cm_code:ti_left      ;ti931
	dw	offset	cm_code:m_left	     ;mai
	dw	offset	cm_code:i_left	     ;ibm

rt	dw	offset	cm_code:enx	     ;off
	dw	offset	cm_code:a_rt	     ;ansi
	dw	offset	cm_code:ti_rt	     ;ti931
	dw	offset	cm_code:m_rt	     ;mai
	dw	offset	cm_code:i_rt	     ;ibm

a1	dw	offset	cm_code:enx	     ;off
	dw	offset	cm_code:a_a1	     ;ansi
	dw	offset	cm_code:enx	     ;ti931
	dw	offset	cm_code:m_a1	     ;mai
	dw	offset	cm_code:i_a1	     ;ibm

a2	dw	offset	cm_code:enx	     ;off
	dw	offset	cm_code:a_a2	     ;ansi
	dw	offset	cm_code:enx	     ;ti931
	dw	offset	cm_code:m_a2	     ;mai
	dw	offset	cm_code:i_a2	     ;ibm

a3	dw	offset	cm_code:enx	     ;off
	dw	offset	cm_code:a_a3	     ;ansi
	dw	offset	cm_code:enx	     ;ti931
	dw	offset	cm_code:m_a3	     ;mai
	dw	offset	cm_code:i_a3	     ;ibm

a4	dw	offset	cm_code:enx	     ;off
	dw	offset	cm_code:a_a4	     ;ansi
	dw	offset	cm_code:enx	     ;ti931
	dw	offset	cm_code:m_a4	     ;mai
	dw	offset	cm_code:i_a4	     ;ibm

					     ;same as cursor up
a9	dw	offset	cm_code:enx	     ;off
	dw	offset	cm_code:a_up	     ;ansi
	dw	offset	cm_code:enx	     ;ti931
	dw	offset	cm_code:m_up	     ;mai
	dw	offset	cm_code:i_up	     ;ibm

					     ;same as cursor down
a0	dw	offset	cm_code:enx	     ;off
	dw	offset	cm_code:a_dn	     ;ansi
	dw	offset	cm_code:enx	     ;ti931
	dw	offset	cm_code:m_dn	     ;mai
	dw	offset	cm_code:i_dn	     ;ibm

					     ;same as cursor left
adash	dw	offset	cm_code:enx	     ;off
	dw	offset	cm_code:a_left	     ;ansi
	dw	offset	cm_code:enx	     ;ti931
	dw	offset	cm_code:m_left	     ;mai
	dw	offset	cm_code:i_left	     ;ibm

					     ;same as cursor right
aequ	dw	offset	cm_code:enx	     ;off
	dw	offset	cm_code:a_rt	     ;ansi
	dw	offset	cm_code:enx	     ;ti931
	dw	offset	cm_code:m_rt	     ;mai
	dw	offset	cm_code:i_rt	     ;ibm

					     ;scroll lock
sclk	dw	offset	cm_code:enx	     ;off
	dw	offset	cm_code:a_sclk	     ;ansi
	dw	offset	cm_code:enx	     ;ti931
	dw	offset	cm_code:enx	     ;mai
	dw	offset	cm_code:enx	     ;ibm

					     ;keypad 7
n7	dw	offset	cm_code:enx	     ;off
	dw	offset	cm_code:a_n7	     ;ansi
	dw	offset	cm_code:enx	     ;ti931
	dw	offset	cm_code:enx	     ;mai
	dw	offset	cm_code:enx	     ;ibm

					     ;keypad 8
n8	dw	offset	cm_code:enx	     ;off
	dw	offset	cm_code:a_n8	     ;ansi
	dw	offset	cm_code:enx	     ;ti931
	dw	offset	cm_code:enx	     ;mai
	dw	offset	cm_code:enx	     ;ibm

					     ;keypad 9
n9	dw	offset	cm_code:enx	     ;off
	dw	offset	cm_code:a_n9	     ;ansi
	dw	offset	cm_code:enx	     ;ti931
	dw	offset	cm_code:enx	     ;mai
	dw	offset	cm_code:enx	     ;ibm

					     ;keypad minus
minus	dw	offset	cm_code:enx	     ;off
	dw	offset	cm_code:a_minus      ;ansi
	dw	offset	cm_code:enx	     ;ti931
	dw	offset	cm_code:enx	     ;mai
	dw	offset	cm_code:enx	     ;ibm

					     ;keypad 4
n4	dw	offset	cm_code:enx	     ;off
	dw	offset	cm_code:a_n4	     ;ansi
	dw	offset	cm_code:enx	     ;ti931
	dw	offset	cm_code:enx	     ;mai
	dw	offset	cm_code:enx	     ;ibm

					     ;keypad 5
n5	dw	offset	cm_code:enx	     ;off
	dw	offset	cm_code:a_n5	     ;ansi
	dw	offset	cm_code:enx	     ;ti931
	dw	offset	cm_code:enx	     ;mai
	dw	offset	cm_code:enx	     ;ibm

					     ;keypad 6
n6	dw	offset	cm_code:enx	     ;off
	dw	offset	cm_code:a_n6	     ;ansi
	dw	offset	cm_code:enx	     ;ti931
	dw	offset	cm_code:enx	     ;mai
	dw	offset	cm_code:enx	     ;ibm

					     ;keypad plus
plus	dw	offset	cm_code:enx	     ;off
	dw	offset	cm_code:a_plus	     ;ansi
	dw	offset	cm_code:enx	     ;ti931
	dw	offset	cm_code:enx	     ;mai
	dw	offset	cm_code:enx	     ;ibm

					     ;keypad 1
n1	dw	offset	cm_code:enx	     ;off
	dw	offset	cm_code:a_n1	     ;ansi
	dw	offset	cm_code:enx	     ;ti931
	dw	offset	cm_code:enx	     ;mai
	dw	offset	cm_code:enx	     ;ibm

					     ;keypad 2
n2	dw	offset	cm_code:enx	     ;off
	dw	offset	cm_code:a_n2	     ;ansi
	dw	offset	cm_code:enx	     ;ti931
	dw	offset	cm_code:enx	     ;mai
	dw	offset	cm_code:enx	     ;ibm

					     ;keypad 3
n3	dw	offset	cm_code:enx	     ;off
	dw	offset	cm_code:a_n3	     ;ansi
	dw	offset	cm_code:enx	     ;ti931
	dw	offset	cm_code:enx	     ;mai
	dw	offset	cm_code:enx	     ;ibm

					     ;keypad 0
n0	dw	offset	cm_code:enx	     ;off
	dw	offset	cm_code:a_n0	     ;ansi
	dw	offset	cm_code:enx	     ;ti931
	dw	offset	cm_code:enx	     ;mai
	dw	offset	cm_code:enx	     ;ibm

					     ;keypad delete key (ansi shift)
ndel	dw	offset	cm_code:enx	     ;off
	dw	offset	cm_code:a_del	     ;ansi
	dw	offset	cm_code:enx	     ;ti931
	dw	offset	cm_code:enx	     ;mai
	dw	offset	cm_code:enx	     ;ibm


					     ;alt-i
ai	dw	offset	cm_code:enx	     ;off
	dw	offset	cm_code:enx	     ;ansi
	dw	offset	cm_code:ti_ai	     ;ti931
	dw	offset	cm_code:enx	     ;mai
	dw	offset	cm_code:enx	     ;ibm

					     ;alt-d
ad	dw	offset	cm_code:enx	     ;off
	dw	offset	cm_code:enx	     ;ansi
	dw	offset	cm_code:ti_ad	     ;ti931
	dw	offset	cm_code:enx	     ;mai
	dw	offset	cm_code:enx	     ;ibm

					     ;alt_w
aw	dw	offset	cm_code:enx	     ;off
	dw	offset	cm_code:enx	     ;ansi
	dw	offset	cm_code:ti_aw	     ;ti931
	dw	offset	cm_code:enx	     ;mai
	dw	offset	cm_code:enx	     ;ibm

					     ;alt-e
ae	dw	offset	cm_code:enx	     ;off
	dw	offset	cm_code:enx	     ;ansi
	dw	offset	cm_code:ti_ae	     ;ti931
	dw	offset	cm_code:enx	     ;mai
	dw	offset	cm_code:enx	     ;ibm

					     ;ctrl-home
chome	dw	offset	cm_code:enx	     ;off
	dw	offset	cm_code:enx	     ;ansi
	dw	offset	cm_code:ti_cthome    ;ti931
	dw	offset	cm_code:enx	     ;mai
	dw	offset	cm_code:enx	     ;ibm

					     ;ctrl-end
cend	dw	offset	cm_code:enx	     ;off
	dw	offset	cm_code:enx	     ;ansi
	dw	offset	cm_code:ti_ctend     ;ti931
	dw	offset	cm_code:enx	     ;mai
	dw	offset	cm_code:enx	     ;ibm

					     ;ctrl-left
cleft	dw	offset	cm_code:enx	     ;off
	dw	offset	cm_code:enx	     ;ansi
	dw	offset	cm_code:ti_ctleft     ;ti931
	dw	offset	cm_code:enx	     ;mai
	dw	offset	cm_code:enx	     ;ibm

					     ;ctrl-right
crt	dw	offset	cm_code:enx	     ;off
	dw	offset	cm_code:enx	     ;ansi
	dw	offset	cm_code:ti_ctrt      ;ti931
	dw	offset	cm_code:enx	     ;mai
	dw	offset	cm_code:enx	     ;ibm

					     ;Ins
ins	dw	offset	cm_code:enx	     ;off
	dw	offset	cm_code:enx	     ;ansi
	dw	offset	cm_code:ti_ins	     ;ti931
	dw	offset	cm_code:enx	     ;mai
	dw	offset	cm_code:enx	     ;ibm

					     ;Del
del	dw	offset	cm_code:enx	     ;off
	dw	offset	cm_code:enx	     ;ansi
	dw	offset	cm_code:ti_del	     ;ti931
	dw	offset	cm_code:enx	     ;mai
	dw	offset	cm_code:enx	     ;ibm

					     ;backtab
btab	dw	offset	cm_code:enx	     ;off
	dw	offset	cm_code:enx	     ;ansi
	dw	offset	cm_code:ti_bktab     ;ti931
	dw	offset	cm_code:enx	     ;mai
	dw	offset	cm_code:enx	     ;ibm

cm_data ends

cm_code segment public 'code'
assume	cs:cm_code
assume	ds:cm_data

extrn	cm_send:near


;------ encode: encode cntrl char (frompfk) into terminal escape sequence
encode	proc	near
	push	dx

	test	ah,frompfk
	jnz	encd0
	jmp	en8			;check alt-numeric keys

encd0:
	test	parm4,crsend		;do we send cursor key codes?
	jnz	en4
	jmp	enx

en4:	cmp	al,c_up
	jne	en5
	mov	si,offset up
	jmp	ensend

en5:	cmp	al,c_dn
	jne	en6
	mov	si,offset dn
	jmp	ensend

en6:	cmp	al,c_left
	jne	en7
	mov	si,offset left
	jmp	ensend

en7:	cmp	al,c_rt
	jne	en8
	mov	si,offset rt
	jmp	ensend

en8:	cmp	al,c_a1
	jne	en9
	mov	si,offset a1
	jmp	ensend

en9:	cmp	al,c_a2
	jne	en10
	mov	si,offset a2
	jmp	ensend

en10:	cmp	al,c_a3
	jne	en11
	mov	si,offset a3
	jmp	ensend

en11:	cmp	al,c_a4
	jne	en11a
	mov	si,offset a4
	jmp	ensend

en11a:	cmp	al,c_a9
	jne	en11b
	mov	si,offset a9
	jmp	ensend

en11b:	cmp	al,c_a0
	jne	en11c
	mov	si,offset a0
	jmp	ensend

en11c:	cmp	al,c_adash
	jne	en11d
	mov	si,offset adash
	jmp	ensend

en11d:	cmp	al,c_aequ
	jne	en12
	mov	si,offset aequ
	jmp	ensend

en12:	cmp	al,c_n0
	jne	en13
	mov	si,offset n0
	jmp	ensend

en13:	cmp	al,c_n1
	jne	en14
	mov	si,offset n1
	jmp	ensend

en14:	cmp	al,c_n2
	jne	en15
	mov	si,offset n2
	jmp	ensend

en15:	cmp	al,c_n3
	jne	en16
	mov	si,offset n3
	jmp	ensend

en16:	cmp	al,c_n4
	jne	en17
	mov	si,offset n4
	jmp	ensend

en17:	cmp	al,c_n5
	jne	en18
	mov	si,offset n5
	jmp	ensend

en18:	cmp	al,c_n6
	jne	en19
	mov	si,offset n6
	jmp	ensend

en19:	cmp	al,c_n7
	jne	en20
	mov	si,offset n7
	jmp	ensend

en20:	cmp	al,c_n8
	jne	en21
	mov	si,offset n8
	jmp	ensend

en21:	cmp	al,c_n9
	jne	en22
	mov	si,offset n9
	jmp	ensend

en22:	cmp	al,c_sclk
	jne	en23
	mov	si,offset sclk
	jmp	ensend

en23:	cmp	al,c_minus
	jne	en24
	mov	si,offset minus
	jmp	ensend

en24:	cmp	al,c_plus
	jne	en25
	mov	si,offset plus
	jmp	ensend

en25:	cmp	al,c_ndel
	jne	en26
	mov	si,offset ndel
	jmp	ensend

en26:	cmp	al,c_ai
	jne	en27
	mov	si,offset ai
	jmp	ensend

en27:	cmp	al,c_ad
	jne	en28
	mov	si,offset ad
	jmp	ensend

en28:	cmp	al,c_aw
	jne	en29
	mov	si,offset aw
	jmp	ensend

en29:	cmp	al,c_ae
	jne	en30
	mov	si,offset ae
	jmp	ensend

en30:	cmp	al,c_cthome
	jne	en31
	mov	si,offset chome
	jmp	ensend

en31:	cmp	al,c_ctend
	jne	en32
	mov	si,offset cend
	jmp	ensend

en32:	cmp	al,c_ctleft
	jne	en33
	mov	si,offset cleft
	jmp	ensend

en33:	cmp	al,c_ctrt
	jne	en34
	mov	si,offset crt
	jmp	ensend

en34:	cmp	al,c_ins
	jne	en35
	mov	si,offset ins
	jmp	ensend

en35:	cmp	al,c_del
	jne	en36
	mov	si,offset del
	jmp	ensend

en36:	cmp	al,c_bktab
	jne	en37
	mov	si,offset btab
	jmp	ensend

en37:
	jmp	enx			;not sendable char

;	si --> appropriate jump table for selected key
ensend: cmp	termtype,0
	je	enx1
	cmp	termtype,dost
	je	enx1

	add	si,2
	cmp	termtype,ansi
	je	endo
	cmp	termtype,nih		;same as ansi
	je	endo
	cmp	termtype,vt52		;same as ansi (subroutines distinguish
	je	endo

	add	si,2			;ti emulation
	cmp	termtype,ti931
	je	endo

	add	si,2
	cmp	termtype,mai
	je	endo

	add	si,2
	cmp	termtype,ibm
	je	endo

enx1:	jmp	enx			;internal error if we get here

endo:	mov	si,[si] 		;get address of routine
	jmp	si			;jump to it

;--- ansi + vt52
a_up:	mov	dl,'A'
	call	cusend
	jmp	enx

a_dn:	mov	dl,'B'
	call	cusend
	jmp	enx

a_left: mov	dl,'D'
	call	cusend
	jmp	enx

a_rt:	mov	dl,'C'
	call	cusend
	jmp	enx

a_a1:	mov	dl,'P'
	call	pfsend
	jmp	enx

a_a2:	mov	dl,'Q'
	call	pfsend
	jmp	enx

a_a3:	mov	dl,'R'
	call	pfsend
	jmp	enx

a_a4:	mov	dl,'S'
	call	pfsend
	jmp	enx

a_n0:	mov	dl,'p'
	call	kasend
	jmp	enx

a_n1:	mov	dl,'q'
	call	kasend
	jmp	enx

a_n2:	mov	dl,'r'
	call	kasend
	jmp	enx

a_n3:	mov	dl,'s'
	call	kasend
	jmp	enx

a_n4:	mov	dl,'t'
	call	kasend
	jmp	enx

a_n5:	mov	dl,'u'
	call	kasend
	jmp	enx

a_n6:	mov	dl,'v'
	call	kasend
	jmp	enx

a_n7:	mov	dl,'w'
	call	kasend
	jmp	enx

a_n8:	mov	dl,'x'
	call	kasend
	jmp	enx

a_n9:	mov	dl,'y'
	call	kasend
	jmp	enx

a_sclk: mov	dl,'m'                  ;dec dash key
	call	kasend
	jmp	enx

a_plus: mov	dl,'M'                  ;dec Enter key
	call	kasend
	jmp	enx

a_minus: mov	 dl,'l'                 ;dec comma key
	call	kasend
	jmp	enx

a_del:	mov	dl,'n'                  ;dec del (period) key
	call	kasend
	jmp	enx


;--- mai
m_up:	mov	al,0bh
	call	cm_send
	jmp	enx

m_dn:	mov	al,0ah
	call	cm_send
	jmp	enx

m_left: mov	al,08h
	call	cm_send
	jmp	enx

m_rt:	mov	al,0ch
	call	cm_send
	jmp	enx

m_a1:	jmp	enx

m_a2:	jmp	enx

m_a3:	jmp	enx

m_a4:	jmp	enx


;--- ibm
i_up:	jmp	enx

i_dn:	jmp	enx

i_left: jmp	enx

i_rt:	jmp	enx

i_a1:	jmp	enx

i_a2:	jmp	enx

i_a3:	jmp	enx

i_a4:	jmp	enx

enx:
	pop	dx
	ret
encode	endp


cusend	proc near		;send ansi/vt52 code w/ action in dl
	push	ax

	mov	al,esc
	call	cm_send

	cmp	termtype,ansi	;vt52 doesn't get prefix
	jne	cu52
	mov	al,'['
	test	tkstate,decka	 ;keypad application mode?
	jz	cuas		;no
	test	tkstate,decca	 ;and cursor application mode?
	jz	cuas		;no
	mov	al,'O'

cuas:	call	cm_send

cu52:	mov	al,dl
	call	cm_send

	pop	ax
	ret
cusend	endp

pfsend	proc near		;send ansi/vt52 code w/ action in dl
	push	ax

	mov	al,esc
	call	cm_send

	cmp	termtype,ansi	;vt52 doesn't need prefix
	jne	pf52
	mov	al,'O'
	call	cm_send

pf52:	mov	al,dl
	call	cm_send

	pop	ax
	ret
pfsend	endp


kasend	proc near		;send ansi/vt52 code w/ action in dl
	push	ax

	mov	al,esc
	call	cm_send

	mov	al,'?'          ;vt52 prefix
	cmp	termtype,ansi
	jne	ka52
	mov	al,'O'          ;ansi prefix

ka52:	call	cm_send
	mov	al,dl
	call	cm_send

	pop	ax
	ret
kasend	endp

ti_ai:
	mov	al,esc
	call	cm_send
	mov	al,4eh
	call	cm_send
	jmp	enx

ti_ad:
	mov	al,esc
	call	cm_send
	mov	al,4bh
	call	cm_send
	jmp    enx

ti_aw:
	mov	al,esc
	call	cm_send
	mov	al,57h
	call	cm_send
	jmp	enx

ti_ae:
	mov	al,esc
	call	cm_send
	mov	al,3dh
	call	cm_send
	jmp	enx

ti_cthome:
	mov	al,esc
	call	cm_send
	mov	al,48h
	call	cm_send
	jmp	enx



ti_ctend:
	mov	al,esc
	call	cm_send
	mov	al,69h
	call	cm_send
	mov	al,71h
	call	cm_send
	jmp	enx

ti_ctleft:
	mov	al,esc
	call	cm_send
	mov	al,74h
	call	cm_send
	jmp	enx

ti_ctrt:
	mov	al,0ah
	call	cm_send
	jmp	enx

ti_ins:
	mov	al,esc
	call	cm_send
	mov	al,50h
	call	cm_send
	jmp	enx


ti_del:
	mov	al,esc
	call	cm_send
	mov	al,51h
	call	cm_send
	jmp	enx


ti_rt:
	mov	al,esc
	call	cm_send
	mov	al,43h
	call	cm_send
	jmp	enx

ti_left:
	mov	al,esc
	call	cm_send
	mov	al,44h
	call	cm_send
	jmp	enx

ti_up:
	mov	al,esc
	call	cm_send
	mov	al,41h
	call	cm_send
	jmp	enx

ti_dn:
	mov	al,esc
	call	cm_send
	mov	al,42h
	call	cm_send
	jmp	enx

ti_bktab:
	mov	al,esc
	call	cm_send
	mov	al,74h
	call	cm_send
	jmp	enx

cm_code ends
end
