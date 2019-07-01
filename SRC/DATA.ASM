;	expanded data definitions

cm_data segment public 'code'
allocate = 1
include data.pub
include buffer.pub

cm_data ends

; dummy segment to make sure it is encountered before cm_buffer
cm_code segment public	'code'
cm_code ends

;note assumption that buffer is only thing in cm_buffer segment
;buffer length must be an integral number of lines
;
;MAKE SURE THAT CM_BUFFER IS ABSOLUTELY THE LAST THING LOADED

cm_buffer segment public para 'zzz'

	db	3840 dup (' ')          ;one screenful is minimum

cm_buffer ends
end
