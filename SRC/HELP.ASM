	public	clrhelp
	public	helpscrn

cm_data segment public 'code'

allocate = 0
include data.pub

help_screen_1	equ	1
help_screen_2	equ	2
help_screen_3	equ	3
help_screen_4	equ	4
help_screen_5	equ	5
help_screen_6	equ	6
help_screen_7	equ	7


extrn	help1:word,help2:word,help3:word,help4:word,help5:word,help6:word
extrn	help7:word

oldwin	db	0


cm_data ends


cm_code segment public 'code'
assume	cs:cm_code
assume	ds:cm_data

extrn	dpage:near,display:near,wswitch:near,setcrsr:near,smsg:near
extrn	dstring:near,qwrite:near,rdcrsr:near,emisint:near


;------ helpscrn: show next help screen
helpscrn	proc	near
	push	ax
	push	cx
	push	si

	mov	al,wndc_id	;get current window id
	push	ax		;save for exit
	cmp	al,3		;are we already in help window?
	je	hs1		;yes -- no need to switch
	mov	al,3		;switch to help window
	call	wswitch
hs1:
	mov	al,scrnum
	or	al,al
	jz	hex		;no screen zero available
	mov	si,offset help1
	dec	al
	jz	phelp
	mov	si,offset help2
	dec	al
	jz	phelp
	mov	si,offset help3
	dec	al
	jz	phelp
	mov	si,offset help4
	dec	al
	jz	phelp
	mov	si,offset help5
	dec	al
	jz	phelp
	mov	si,offset help6
	dec	al
	jz	phelp
	mov	si,offset help7
	dec	al
	jz	phelp
	mov	si,offset help1 ;help screen 8 is wrapped around to screen 1
	mov	scrnum,help_screen_1
	jmp	phelp


phelp:	call	qwrite
	inc	scrnum

hex:	pop	ax		;recover old window num
	call	wswitch 	;go to it
	pop	si
	pop	cx
	pop	ax
	ret
helpscrn	endp

;------ clrhelp: return from help screen, and restore old screen.
clrhelp proc	near
	push	ax
	push	dx

	mov	al,1		;first re-display window one
	call	wswitch
	cmp	scrnum,1	;if scrnum is 1, then we never messed up scrn
				;note assumption
	je	clrh1
	call	dpage		;re-display page

	test	parm4,emis	;emis interface
	jz	clrh1
	mov	al,2		;refresh emis window
	call	emisint

clrh1:
;	mov	dh,wndc_crsrow
;	mov	dl,wndc_crscol
;	call	setcrsr

	mov	scrnum,1

	pop	dx
	pop	ax
	ret
clrhelp endp


cm_code ends
end
