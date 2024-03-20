;----------------------------------;
;        Master Boot Record        ;
;  Written by Christian Henrichsen ;
;            12.03.2024            ;
;           Copyright (C)          ;
;       Christian Henrichsen       ;
;               2024               ; 
;----------------------------------;

org 600h                ; Program origin of 600h
bits 16                 ; 16-bit programing
cpu 8086                ; And assembling for the iAPX 8086 processor
cli                     ; Clear the interrupt flag, only non-maskable interrupts will be enabled
xor ax, ax              ; Zero out accumulator
mov ss, ax              ; Set the stack segment register
mov sp, 7000h           ; Set Stack Pointer
push ax                 ; Pushing AX 
push ax                 ; Pushing AX again
pop es                  ; And popping it into ES
pop ds                  ; and DS and setting them both to zero
sti                     ; Set the interrupts flag back one, now every single interrupt can interrupt my work
cld                     ; Default direction for string operations will be 'up', so incrementing adresses in RAM
mov si, 7c00h           ; Source, 7c00 since we are copying the entire MBR
mov di, 0600h           ; Destination, 600, since we are to relocate ourselves to not interfere with the loading of the VBR
mov cx, 0ffh            ; Copy 256 word's (512 bytes), or in other word's, the entire bootsector. Nice pun, right?
rep                     ; Repeat the following movsw's CX times
movsw                   ; Move word at offset DS:SI to ES:DI

jmp 0000h:relocated_code ; Jump to the relocated code

relocated_code:
    mov cx, 3            ; Loop 4 times for each of the partition table entries
    mov si, Par_tbl      ; loading the offset of the partition table into SI, 7BE
.find_active:
    cmp byte [si], 80h   ; Is it 80h?
    je active_found      ; Yes, then go check if there are any others marked as 'active'
    add si, 10h          ; No, add 16 to go to the next entry
    loop .find_active    ; Jump if CX is not zero to check again
    int 18h              ; No active partition, start ROM basic. Some or most BIOS'es will just display a 'Press any key to reboot' message
                         ; If it continues to execute then it will stop here, and you will need to power down or CRTL-ALT-DEL

active_found:            ; We found an active partition entry!
    mov bp, si           ; Save SI in BP for restoration later 
.test_partbl:            ; Test the rest of the partition table
    add si, 10h          ; Add 16 to get to the next entry
    cmp byte [si], 00h   ; Is it zero?
    jne short invalid_tbl      ; If not then there is an error
    loop .test_partbl    ; Keep checking the rest if CX is not zero
    mov si, bp           ; Restoring SI because Partition table is clean, lets keep going.

prep_chs:
    mov word dx, [si]    ; DL = Drive number, DH = Head
    mov word cx, [si+2]  ; CL = Sector, CH = Cylinder

load_vbr:
    mov di, 0006h        ; We will retry 6 times
    mov bx, 7c00h        ; Load our Volume Boot Record at 0000:7c00
    mov ax, 0201h        ; Read 1 Sector
    push di              ; Save di
    int 13h              ; Calling int 13h
    pop di               ; Restore DI
    jnc short read_OK    ; Did the reading suceed?      
                         ; Nope Calling
    xor ax, ax           ; Function 00h, reset drive
    int 13h              ; Calling int 13h
    pop di               ; Restore DI
    dec di               ; Decrement DI
    jnz short load_vbr   ; Try again
    mov si, error_loading ; Loading failed, move location of loading error message into SI
    call print_string    ; Print the error message
                         ; And lock up the machine

read_OK:                 ; Reading suceeded
    mov di, 7DFEh        ; Pointer to the end of or loaded VBR
    cmp word [di], 0AA55h ; Check is the VBR bootable? Checking to see if the 2 last bytes are 55AAh
    je short bootable    ; Yes, the VBR is bootable
    mov si, no_os        ; Nope, move loaction of error message. 'Missing OS!'
    jmp short print_string ; Display string and hang the machine

bootable:                ; Yez, it's bootable
    mov si, bp           ; SI = BP
    jmp 0000h:7c00h      ; And do a far jump to our nice newly loaded VBR, we are pretending to be the BIOS
    
;----------------
; MBR subroutines

invalid_tbl:             ; The partition table is invalid
    mov si, invalid_partbl ; Location of error message

print_string:
	mov ah, 0Eh	 ; int 10h teletype function
.repeat:
	lodsb		 ; Get character from our string
	cmp al, 0        ; Is it zero?
	je .done	 ; If it's zero, the it's the end of the string

	int 10h		 ; Otherwise, print it
	jmp short .repeat ; And move on to next character

.done:
	jmp short $      ; Hang the machine, you must power down or reboot



invalid_partbl db 'Invalid Partition Table!', 0
no_os          db 'Missing OS!', 0
error_loading  db 'Error loading OS!', 0

times 440 - ($-$$) db 00h   ; Padding the rest of the MBR with zeros

times 6 db 00h  ; Padding for the NT serial number

Par_tbl:
times 16*4 db 00h ; Filling the entire Partition Table with zeros 
db 055h, 0AAh     ; Boot signature, MUST NOT BE ALTERED
;-----------------------------------------------;
;                End Of My MBR                  ;
;-----------------------------------------------;

times 1048576*40 db 0 ; Filling up with 40 Megabytes of zero's to make it a full harddisk image. OPTIONAL
