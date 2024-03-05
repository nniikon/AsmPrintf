section .data

Msg:     db "12345- %s %d %u %x %o %b", 0x0a, 0x00
SubMsg1: db "ded", 0x00

section .text

global MyAMD64Printf

;global _start 

;_start:
;        push 0b10101010
;        mov r9, 0q712
;        mov r8, 0xAFC12
;        mov ecx, 123 
;        mov edx, -32 
;        mov rsi, SubMsg1
;        mov rdi, Msg
;        call MyAMD64Printf  
;
;        mov rax, 0x3c
;        xor rdi, rdi
;        syscall

;;==============================================================================
;; Printf clone for AMD64 ABI
;;
;; rdi                          - format string
;; rsi, rdx, rcx, r8, r9, stack - arguments
;;
;;==============================================================================
MyAMD64Printf:
        mov [PrintfReturnAddress], rbp
        pop rbp

        push r9       
        push r8       
        push rcx
        push rdx
        push rsi

        call MyPrintf

        pop rsi
        pop rdx
        pop rcx
        pop r8
        pop r9


        push rbp
        mov rbp, [PrintfReturnAddress]
        ret

;;==============================================================================
;; Printf clone
;;
;; rdi   - format string
;; stack - arguments
;;
;;      | n'th argument  |  - rbp + 16 + 8n
;;      |      ...       | 
;;      | 2st argument   |  - rbp + 24
;;      | 1st argument   |  - rbp + 16
;;      | return address |  - rbp + 8
;;      | saved rbp      | <- rbp
;;
;;==============================================================================
MyPrintf:
        push rbp
        mov rbp, rsp

    ; Save regs
        push r13

        mov r8, rdi

    ; Store the current argument shift
        mov r10, 16

    ; Store the current number of characters printed
        xor r13, r13

.printNextCharacter:
    ; Store the current format character
        mov bl, byte [r8]

    ; If it's a '\0'
        test bl, bl
        jz printfExit                                                          ; TODO: reverse statement to make it more effective   

    ; If it's a '%'
        cmp bl, '%'
        jz .getSpecifier

.getFormatString:
        call PrintFormatString
        add r13, rdx
        add r8, rdx
        jmp .printNextCharacter

.getSpecifier:
    ; Analyze the next symbol
        inc r8
        mov bl, byte [r8]

        call PrintSpecifier
    ; Move one symbol
        inc r8

        jmp .printNextCharacter

printfExit:

    ; Setup the return value
        mov rax, r13

    ; Restore regs
        pop r13

        mov rsp, rbp
        pop rbp
        ret

;;==============================================================================
;; Outputs a string until it meets '%' or '\0'
;;
;; Input:
;;      r8 - string address
;;
;; Destroys:
;;      rcx
;;
;; Returns:
;;      rdx - number of symbols outputted
;;==============================================================================
PrintFormatString:
        mov     dl, byte [r8]

    ; While guard
        test    dl, dl
        je      .ExitZero
        cmp     dl, '%'
        je      .ExitZero

        xor rdx, rdx
.percentStrlen:
        inc     rdx
        mov     cl, byte [r8+rdx]
        test    cl, cl
        je      .Exit
        cmp     cl, '%'
        jne     .percentStrlen

.Exit:
   
   ;-----------------------------------
   ; System call №1 (write to file)
   ;    rax - 1
   ;    rdi - file descriptor
   ;    rsi - string
   ;    rdx - string length
   ;-----------------------------------
        mov rax, 1
        mov rsi, r8 
        mov rdi, 1
        syscall

.ExitZero:
        ret


;;==============================================================================
;; Prints a specifier
;;
;; Input:
;;      r10 - data offset
;;      rbp - data pointer
;;
;;
;;==============================================================================
PrintSpecifier:
        sub     ebx, 37
        cmp     bl, 83
        ja      .printError
        movzx   ebx, bl
        jmp     [.jumpTable + rbx*8]
.jumpTable:
        dq   .printPercent
        dq   .printError
        dq   .printError
        dq   .printError
        dq   .printError
        dq   .printError
        dq   .printError
        dq   .printError
        dq   .printError
        dq   .printError
        dq   .printError
        dq   .printError
        dq   .printError
        dq   .printError
        dq   .printError
        dq   .printError
        dq   .printError
        dq   .printError
        dq   .printError
        dq   .printError
        dq   .printError
        dq   .printError
        dq   .printError
        dq   .printError
        dq   .printError
        dq   .printError
        dq   .printError
        dq   .printError
        dq   .printError
        dq   .printError
        dq   .printError
        dq   .printError
        dq   .printError
        dq   .printFloat
        dq   .printError
        dq   .printError
        dq   .printError
        dq   .printError
        dq   .printError
        dq   .printError
        dq   .printError
        dq   .printError
        dq   .printError
        dq   .printError
        dq   .printError
        dq   .printError
        dq   .printError
        dq   .printError
        dq   .printError
        dq   .printError
        dq   .printError
        dq   .printHex
        dq   .printError
        dq   .printError
        dq   .printError
        dq   .printError
        dq   .printError
        dq   .printError
        dq   .printError
        dq   .printError
        dq   .printError
        dq   .printBinary
        dq   .printCharacter
        dq   .printInteger
        dq   .printError
        dq   .printFloat
        dq   .printError
        dq   .printError
        dq   .printInteger
        dq   .printError
        dq   .printError
        dq   .printError
        dq   .printError
        dq   .printNumberOfCharactersWritten
        dq   .printOctal
        dq   .printAddress
        dq   .printError
        dq   .printError
        dq   .printString
        dq   .printError
        dq   .printUnsigned
        dq   .printError
        dq   .printError
        dq   .printHex

;;=============================================================================
;; Handles error cased.
;;=============================================================================
.printError:
    ; Set return value to -1
        mov r13, -1

    ; Restore rsp
        add rsp, 16

    ; Evacuate
        jmp printfExit

;;=============================================================================
;; Converts floating-point number to the decimal notation
;;                                                       with a fixed precision
;;=============================================================================
.printFloat:
;;=============================================================================
;; Converts an unsigned integer into hexadecimal representation
;;=============================================================================
.printHex:
        mov rcx, 4
        call PrintNumberByBits
        ret
;;=============================================================================
;; Converts a signed integer into decimal representation
;;=============================================================================
.printInteger:
        push r12

    ; Put the number into rax
        mov eax, [r10 + rbp]

        mov rsi, PrintfBuffer
        mov rcx, rsi

    ; Start from the end of the buffer
        add rcx, PrintfBufferSize - 1

        test eax, eax
        jns .isPositive

.isNegative:
        neg eax
    ; Set IsNegative flag 
        mov r12, 1
.isPositive:

    ; Convert the number to string
.signedToStr:
        xor rdx, rdx

        mov rbx, 10
        div rbx

     ; Convert the remainder to ASCII
        add dl, '0'

        dec rcx
    ;  Store the character in the buffer
        mov [rcx], dl

    ; Check if there are more digits
        test rax, rax
        jnz .signedToStr
    
    ; Check the isNegative flag
        test r12, r12
        jz .noMinus

.addMinus:
        dec rcx
        mov byte [rcx], '-';
.noMinus:
    ; Calculate the string's length
        sub rsi, rcx
        add rsi, PrintfBufferSize
   ;-----------------------------------
   ; System call №1 (write to file)
   ;    rax - 1
   ;    rdi - file descriptor
   ;    rsi - string
   ;    rdx - string length
   ;-----------------------------------
        mov rdx, rsi
        mov rax, 1
        mov rsi, rcx
        mov rdi, 1
        syscall

    ; Increment the number of symbols outputted
        add r13, rdx 
        dec r13
    ; Move to the next argument
        add r10, 8
        pop r12
        ret
;;=============================================================================
;; Converts an unsigned integer into octal representation
;;=============================================================================
.printOctal:
        mov rcx, 3
        call PrintNumberByBits
        ret
;;=============================================================================
;; Writes a single character
;;=============================================================================
.printCharacter:
        mov rax, [r10 + rbp]

        mov rcx, PrintfBuffer
        mov byte [rcx], al
   ;-----------------------------------
   ; System call №1 (write to file)
   ;    rax - 1
   ;    rdi - file descriptor
   ;    rsi - string
   ;    rdx - string length
   ;-----------------------------------
        mov rdx, 1 
        mov rax, 1
        mov rsi, rcx
        mov rdi, 1
        syscall

    ; Increment the number of symbols outputted
        add r13, rdx 
        dec r13

    ; Move to the next argument
        add r10, 8
        ret
;;=============================================================================
;; Outputs the number of characters written so far by this call to the function
;; FIXME: it doesn't work like this =(
;;=============================================================================
.printNumberOfCharactersWritten:
        mov rax, [r10 + rbp] 
        mov [rax], r13

    ; Move to the next argument
        add r10, 8

        ret
;;=============================================================================
;; Converts an unsigned integer into binary representation 
;;=============================================================================
.printBinary:
        mov rcx, 1
        call PrintNumberByBits
        ret
;;=============================================================================
;; Converts an unsigned integer into decimal representation  
;;=============================================================================
.printUnsigned:
    ; Put the number into rax
        mov eax, [r10 + rbp]

        call PrintUnsigned

    ; Move to the next argument
        add r10, 8
        ret
;;=============================================================================
;; Writes an implementation defined character sequence defining a pointer. 
;;=============================================================================
.printAddress:
        jmp .printHex
;;=============================================================================
;; Writes a character string 
;;=============================================================================
.printString:
        xor dx, dx
        mov r9, [r10 + rbp]
        mov dl, byte [r9]

    ; While guard
        test dl, dl
        je   .exitEmpty

        xor  rdx, rdx
.percentStrlen:
        inc  rdx
        mov  cl, [r9+rdx]
        test cl, cl
        jne  .percentStrlen

   ;-----------------------------------
   ; System call №1 (write to file)
   ;    rax - 1
   ;    rdi - file descriptor
   ;    rsi - string
   ;    rdx - string length
   ;-----------------------------------
        mov rax, 1
        mov rsi, r9 
        mov rdi, 1
        syscall

    ; Increment the number of symbols outputted
        add r13, rdx 
        dec r13
    ; Move to the next argument
        add r10, 8

.exitEmpty:
        ret

;;=============================================================================
;; Writes literal %
;;=============================================================================
.printPercent:
   ;-----------------------------------
   ; System call №1 (write to file)
   ;    rax - 1
   ;    rdi - file descriptor
   ;    rsi - string
   ;    rdx - string length
   ;-----------------------------------
        mov rax, 1
        mov rdi, 1
        mov rsi, PercentMsg
        mov rdx, PercentMsgLen
        syscall

    ; Increment the number of symbols outputted
        inc r13
        ret
;;=============================================================================


;;=============================================================================
;; Converts an unsigned integer into decimal representation  
;;
;; Input:   eax - number
;;=============================================================================
PrintUnsigned:
        mov rsi, PrintfBuffer
        mov rcx, rsi

    ; Start from the end of the buffer
        add rcx, PrintfBufferSize - 1

     ; Null-terminate the string
        mov byte [rcx], 0

    ; Convert the number to string
.unsignedToStr:
        xor rdx, rdx

        mov rbx, 10
        div rbx

     ; Convert the remainder to ASCII
        add dl, '0'

    ;  Store the character in the buffer
        dec rcx
        mov [rcx], dl

    ; Check if there are more digits
        test eax, eax
        jnz .unsignedToStr

    ; Calculate the string's length
        sub rsi, rcx
        add rsi, PrintfBufferSize
   ;-----------------------------------
   ; System call №1 (write to file)
   ;    rax - 1
   ;    rdi - file descriptor
   ;    rsi - string
   ;    rdx - string length
   ;-----------------------------------
        mov rdx, rsi
        mov rax, 1
        mov rsi, rcx
        mov rdi, 1
        syscall

    ; Increment the number of symbols outputted
        add r13, rdx
        dec r13

        ret


;;=============================================================================
;; Converts an unsigned integer into 2^n-cimal representation
;;
;; Input:   cl - n
;;=============================================================================
PrintNumberByBits:
        push r12

    ; Put the number into rax
        mov eax, [r10 + rbp]

        mov rsi, PrintfBuffer
        mov rdi, rsi

    ; Start from the end of the buffer
        add rdi, PrintfBufferSize - 1

     ; Null-terminate the string
        mov byte [rdi], 0

    ; Calculate the mask for a digit
        mov r12, 1
        shl r12, cl
        dec r12

    ; Convert the number to string
.binaryToStr:
        mov edx, eax

    ; Get the digit
        and rdx, r12 

    ; Get the remainder
        shr eax, cl

     ; Convert the remainder to ASCII
        add edx, Numbers
        mov dl, byte [edx]

        dec rdi 
    ;  Store the character in the buffer
        mov [rdi], dl

    ; Check if there are more digits
        test eax, eax
        jnz .binaryToStr

    ; Calculate the string's length
        sub rsi, rdi 
        add rsi, PrintfBufferSize
   ;-----------------------------------
   ; System call №1 (write to file)
   ;    rax - 1
   ;    rdi - file descriptor
   ;    rsi - string
   ;    rdx - string length
   ;-----------------------------------
        mov rdx, rsi
        mov rax, 1
        mov rsi, rdi 
        mov rdi, 1
        syscall

    ; Move to the next argument
        add r10, 8

    ; Increment the number of symbols outputted
        add r13, rdx
        dec r13

        pop r12
        ret


segment .data

PrintfReturnAddress dq 0
PrintfBufferSize    equ 50
PrintfBuffer        db PrintfBufferSize dup(0)

Numbers             db "0123456789ABCDEF", 0x00

PercentMsg:         db "%", 0x00
PercentMsgLen:  equ $ - PercentMsg
