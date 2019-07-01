; helpscrn.asm --- data for help screens

	public	help1
	public	help2
	public	help3
	public	help4
	public	help5
	public	help6
	public	help7

cm_data segment public 'code'

allocate = 0
include data.pub

help1	dw	helpz1-helpa1
helpa1	db	12,' Fundamentals',54 dup (' '),'Screen 1 of 7'
	db	13,10,80 dup (205),13,10,10
	db	9,9
	db	'QUIT -- leave Telios and return to DOS'
; ***	db	13,10,9,9
; ***	db	'EXPLAIN command -- give detailed command usage instructions'
	db	13,10,10
	db	'Special keys:',9
	db	'Alt-H ==> list help screens; switch to command mode',13,10,9,9
	db	'Alt-S ==> show current status',13,10,9,9
	db	'Alt-F ==> list function key definitions',13,10,9,9
	db	'Alt-B ==> send BREAK signal',13,10,9,9
	db	'Alt-P ==> PANIC: stop SEND, TYPE commands; clear Tchar, Xon wait'
	db	13,10,10
	db	'Printing:',9
	db	'Ctrl-PrtSc ==> toggle flow of characters to printer',13,10,9,9
	db	'Shift-PrtSc ==> print the current screen',13,10,10
	db	'Paging:',9,9
	db	'PgUp/PgDn ==> roll the screen back/forward one page',13,10,9,9
	db	'Ctrl-PgUp/Ctrl-PgDn ==> roll the screen back/forward one line',13,10,9,9
	db	'Home/End ==> roll the screen to first/last page',13,10,9,9
	db	'STORE filename -- store contents of screen memory in file',13,10,9,9
	db	'                    (from first displayed line to end of memory)'
	db	13,10,9,9
	db	'CLEAR -- clear screen memory',13,10,9,9
	db	'CLS -- clear only current screen'
	db	13,10,10
	db	hilitef
	db	'Alt-H ==> next help screen; Enter ==> conversation mode; or type a command'
	db	nattrf
helpz1	db	?


help4	dw	helpz4-helpa4
helpa4	db	12,' File transfer      ',47 dup (' '),'Screen 4 of 7'
	db	13,10,80 dup (205),13,10,10
	db	'Download:',9
	db	'CAPTURE filename -- start capturing characters in file'
	db	13,10,9,9,'                    (Alt-T toggles character flow on/off)'
	db	13,10,9,9
	db	'CLOSE -- stop capturing characters in current file'
	db	13,10,10,'Upload:',9,9
	db	'SEND filename -- send file to host'
	db	13,10,10,10,'Filetype:',9
	db	'EOF filetype -- select appropriate End-Of-File handling'
	db	13,10,9,9
	db	'                  filetype = text, binary'
	db	13,10,10,10,'Pacing:',9,9
	db	'FLOW type -- set use of Xon/Xoff or Rts/Cts flow control',13,10,9,9
	db	'               type = off, send, obey, both, rts',13,10,9,9
	db	'TCHAR char -- set char to wait for after sending line to host'
	db	13,10,9,9
	db	'                 char = ASCII character, or OFF'
	db	13,10,9,9
	db	'TWAIT time -- set time to wait for after sending line to host',13,10,9,9
	db	'                time in tenths of a second, between 0 and 255'
	db	13,10,10,10
	db	hilitef
	db	'Alt-H ==> next help screen; Enter ==> conversation mode; or type a command'
	db	nattrf
helpz4	db	?

help5	dw	helpz5-helpa5
helpa5	db	12,' File transfers using protocol'
	db	37 dup (' '),'Screen 5 of 7'
	db	13,10,80 dup (205),13,10,10
	db	13,10,'Transfers:',9
	db	'PSEND filename -- send contents of file to host, using protocol'
	db	13,10,10,9,9
	db	'PCAPTURE filename -- capture file from host, using protocol'
	db	13,10,10,10
	db	'Setup:',9,9
	db	'PROTOCOL type -- select transfer protocol'
	db	13,10,9,9
	db	'                   type = xmodem, kermit'
	db	13,10,9,9
	db	'CHATTER level -- select style of transfer progress reporting'
	db	13,10,9,9
	db	'                   level = on, off, debug'
	db	13,10,9,9
	db	'TIMEOUT interval -- set timeout interval in seconds'
	db	13,10,9,9
	db	'                      interval between 0 and 255'
	db	13,10,9,9
	db	'RETRIES max -- set maximum number of packet retries'
	db	13,10,9,9
	db	'                 max between 0 and 127'
	db	13,10,9,9
	db	'KSOP char -- set Kermit start-of-packet character'
	db	13,10,9,9
	db	'               char = ASCII character or entry sequence'
	db	13,10,10,10,10
	db	hilitef
	db	'Alt-H ==> next help screen; Enter ==> conversation mode; or type a command'
	db	nattrf
helpz5	db	?

help6	dw	helpz6-helpa6
helpa6	db	12,' Function keys and strings '
	db	40 dup (' '),'Screen 6 of 7'
	db	13,10,80 dup (205),13,10,10
	db	'Function keys:',9
	db	'DEFINE key defn -- define function keys and strings'
	db	13,10,10,9,9
	db	'    key = F1..F10, S1..S10, enter, bs, answer, ring,'
	db	13,10,9,9
	db	'            prefix, number, suffix'
	db	13,10,9,9
	db	'    defn = line of characters and entry sequences'
	db	13,10,9,9
	db	'    entry sequences:',13,10,9,9
	db	'       ^M (for carriage return)',13,10,9,9
	db	'       ^# (for ASCII delete char)',13,10,9,9
	db	'       ^1 (to enter command mode)',13,10,9,9
	db	'       ^@, ^A...^Z, ^[, ^\, ^], ^^, ^-, ^$ (for ASCII 0..32)'
	db	13,10,9,9
	db	'       ^! (for ^ (caret))'
	db	13,10,10
	db	'Example:',9,'This DEFINE command sets up the F10 key to'
	db	13,10,9,9,'execute the command "BAUD 1200" '
	db	13,10,9,9
	db	13,10,9,9,'    DEFINE F10 ^1 BAUD 1200 ^M^M'
	db	13,10,10,10,10
	db	hilitef
	db	'Alt-H ==> next help screen; Enter ==> conversation mode; or type a command'
	db	nattrf
helpz6	db	?

help3	dw	helpz3-helpa3
helpa3	db	12,' Modem control and files                '
	db	27 dup (' '),'Screen 3 of 7'
	db	13,10,80 dup (205),13,10,10
	db	'Modem control:',9
	db	'DIAL number -- dial using prefix+number+suffix strings',13,10
	db	9,9,'DISCONNECT -- disconnect modem'
	db	13,10,10
	db	'Command files:',9
	db	'SAVE filename -- save current Telios setup in command file',13,10,9,9
	db	'DO filename -- execute commands from file'
	db	13,10,10
	db	'Files:',9,9
	db	'DIR -- list disk files',13,10,9,9
	db	'ERASE filename -- erase file',13,10,9,9
	db	'RENAME filename newname -- rename file',13,10,9,9
	db	'DRIVE drive: -- select default disk drive',13,10,9,9
	db	'CDIR drive:path -- change current DOS directory',13,10,9,9
	db	'TYPE filename -- display contents of file',13,10,9,9
	db	'                   (Press Alt-P to stop display)'
	db	13,10,10,10,10,10,10,10
	db	hilitef
	db	'Alt-H ==> next help screen; Enter ==> conversation mode; or type a command'
	db	nattrf
helpz3	db	?


help2	dw	help2z-help2a
help2a	db	12,' Communications setup    '
	db	42 dup (' '),'Screen 2 of 7',13,10
	db	80 dup (205),13,10,10
	db	'Comm. setup:',9
	db	'BAUD rate -- set the line speed (baud rate)',13,10,9,9
	db	'               rate = 110,150,300,600,1200,2400,4800,9600'
	db	13,10,9,9
	db	'PARITY type -- set type of parity checking',13,10,9,9
	db	'                 type = even, odd, mark, space, off'
	db	13,10,9,9
	db	'PORT commport --  select communications port',13,10,9,9
	db	'                    commport = 1, 2'
	db	13,10,10
	db	'Char. handling:',9
	db	'ECHO switch -- echo typed characters to the screen',13,10,9,9
	db	'                 switch = on, off'
	db	13,10,9,9
	db	'AUTOLF switch -- add a linefeed after carriage returns'
	db	13,10,9,9
	db	'                   switch = on, off'
	db	13,10,9,9
	db	'FILTER switch -- filter non-text characters',13,10,9,9
	db	'                   switch = on, off'
	db	13,10,9,9
	db	'EXPAND switch -- expand null lines to blank lines on upload'
	db	13,10,9,9
	db	'                   switch = on, off'
	db	13,10,9,9
	db	'ROUTE source -- route selected characters to capture file',13,10,9,9
	db	'                  source = all, sent, received'
	db	13,10,10,10
	db	hilitef
	db	'Alt-H ==> next help screen; Enter ==> conversation mode; or type a command'
	db	nattrf
help2z	db	?

help7	dw	help7z - help7a
help7a	db	12,' Screen setup & emulation'
	db	42 dup (' '),'Screen 7 of 7',13,10
	db	80 dup (205),13,10,10
	db	'Screen:',9,9
	db	'TERM type -- enable terminal emulation',13,10,9,9
	db	'               type = normal, VT100, VT52',13,10,9,9
	db	'CURSOR switch -- control transmission of cursor key codes',13,10,9,9
	db	'                   switch = send, local',13,10,9,9
	db	'TABS nums -- set tab stops',13,10,9,9
	db	'               nums = column numbers, separated by blanks'
	db	13,10,9,9
	db	'WINDOW top bot -- specify size of horizontal window',13,10,9,9
	db	'                    top, bot = row numbers from 0 to 23'
	db	13,10,9,9
	db	'CLOCK switch -- reset clock; control clock display'
	db	13,10,9,9
	db	'                  switch = set, on, off',13,10,9,9
	db	'SCREEN switch -- control screen display of characters',13,10,9,9
	db	'                   switch = normal, mute, graphic',13,10,9,9
	db	'COLOR c1 c2 c3 c4 c5 c6-- set screen colors, from 0 to 15'
	db	13,10,9,9
	db	' c1..c6 = foregrnd,bkgrnd,hilite,msg-foregrnd,msg-bkgrnd,border'
	db	13,10,10,10,10,10,10
	db	hilitef
	db	'Alt-H ==> next help screen; Enter ==> conversation mode; or type a command'
	db	nattrf
help7z	db	?
cm_data ends
end
