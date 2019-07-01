;------ keyboard bios interface routines

	public	sc_beep 		;orphan

	public	kbread
	public	kbinit
	public	bioskchk

cm_data segment public	'code'

allocate = 0
include data.pub

cm_data ends


cm_code segment public	'code'
assume	cs:cm_code
assume	ds:cm_data

extrn	setupd:near

iowait	proc	near
	jmp	short $+2
	jmp	short $+2
	ret
iowait	endp

;------ sc_beep: make a noise
sc_beep proc	near
	push	dx
	push	cx
	push	ax

	mov	al,10110110b	;select channel 2,lsb,msb,mode 3,binary
	out	43h,al		;write the timer mode reg
	call	iowait

	mov	ax,0800h	;generic pleasant tone
	out	42h,al		;write timer 2 cnt - lsb
	call	iowait
	mov	al,ah
	out	42h,al		;write timer 2 cnt - msb
	call	iowait

	in	al,61h		;get current setting of port
	call	iowait
	mov	ah,al		;save for reset
	or	al,1+2		;start timer countdown; turn on speaker
	out	61h,al
	call	iowait

	mov	dx,62h		;PC family TIMER 2 found on this port
	in	al,dx
	cmp	al,0ffh 	;PC's won't ever have 0ffh here
	jne	b0
	mov	dx,61h		;PS/2 family has TIMER 2 bit here

b0:	mov	cx,75

b2:	in	al,dx
	call	iowait
	test	al,20h		;timer 2 output bit
	jz	b2		;wait for high

b3:	in	al,dx
	call	iowait
	test	al,20h
	jnz	b3		;wait for low

	loop	b2		;next cycle

	mov	al,ah
	and	al,0fch 	;zero bits 0,1
	out	61h,al

	pop	ax
	pop	cx
	pop	dx
	ret			;return to caller
sc_beep endp


;------ kbinit: set shift_state
kbinit	proc	near
	push	ax
	mov	ah,2		;get shift state
	int	16h
	mov	shift_state,al
	pop	ax
	ret
kbinit	endp


;------ kbread: read char from keyboard into al. set zf if none available.
kbread	proc	near
	mov	ah,2		;get shift state into al
	int	16h
	mov	ah,al
	xor	ah,shift_state
	jz	kbchk1		;no change
	mov	shift_state,al	;remember for next time
	test	ah,shift_sclk	;did scroll lock change?
	jz	kbchk0
	mov	ah,c_sclk	;yes -- return fake character
	sub	al,al		;indicate extended code
	jmp	kbret1

kbchk0: test	ah,shift_numlk
	jz	kbchk1
	call	setupd		;update status line indicator

kbchk1: mov	ah,1
	int	16h		;bios kb status
	jz	kbret
	mov	ah,0
	int	16h		;bios kb read

;**** I would prefer a different home for this VT100 specific routine

	; if numlok is on, and scan code (in ah) is between 71 and 83
	;	and we're in keypad application mode,
	;	then return extended char, add 70 to code
	test	tkstate,decka			;keypad application mode?
	jz	kbret1				;no --
	test	shift_state,shift_numlk
	jz	kbret1
	cmp	ah,71
	jb	kbret1
	cmp	ah,83
	ja	kbret1
	add	ah,70		;move into c_sclk - c_del range
	sub	al,al		;make into extended char

kbret1: or	ax,ax		;clear zf
kbret:	ret
kbread	endp

;------ bioskchk: set zf unless chr in keyboard queue. Put chr in ax
bioskchk proc	near
	mov	ah,1
	int	16h
	ret
bioskchk endp

cm_code ends
end
