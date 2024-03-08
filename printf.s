section .data

Msg:     db "12345- %s %d %u %x %o %b", 0x0a, 0x00
SubMsg1: db "ded", 0x00

section .text

global MyAMD64Printf

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
;;      | n'th integer argument |  ~ rbp + 16 + 8n
;;      |          ...          | 
;;      | 2'nd integer argument |  ~ rbp + 24
;;      | 1'st integer argument |  ~ rbp + 16
;;      | return address        |  ~ rbp + 8
;;      | saved rbp             | <- rbp
;;      | 1'st float argument   |  ~ rbp - 8 
;;      | 2'st float argument   |  ~ rbp - 16 
;;      |          ...          | 
;;      | 8'st float argument   |  ~ rbp - 64
;;
;;==============================================================================
MyPrintf:
        push rbp
        mov rbp, rsp

    ; Check if there's any float arguments
        test eax, eax
        jz .noFloatArgs

    ;----------------------------------
    ; Allocate memory for the float arguments
    ; At max we can save 8 floats in our frame
    ; Registers xmm0-xmm7 (read AMD64 ABI)
    ;----------------------------------
        cmp eax, 8
        jbe .regFloats
.stkFloats:
    ; We only need to allocate stack memory for the registers
        mov eax, 8
.regFloats:
        mov eax, eax
        shl rax, 4
        sub rsp, rax

    ; Load to the stack the float arguments 
        shr rax, 4
        jmp [.jumpTable + rax * 8]
.jumpTable:
        dq     .noFloatArgs
        dq     .float1
        dq     .float2 
        dq     .float3 
        dq     .float4 
        dq     .float5 
        dq     .float6 
        dq     .float7 
        dq     .float8 
.float8:
        movsd qword [rbp - 64], xmm7
.float7:
        movsd qword [rbp - 56], xmm6
.float6:
        movsd qword [rbp - 48], xmm5
.float5:
        movsd qword [rbp - 40], xmm4
.float4:
        movsd qword [rbp - 32], xmm3
.float3:
        movsd qword [rbp - 24], xmm2
.float2:
        movsd qword [rbp - 16], xmm1
.float1:
        movsd qword [rbp - 8], xmm0

.noFloatArgs:
    ; Save regs
        push r13
        push r14

    ; Save the format into r8
        mov r8, rdi

    ; Store the current integer argument shift
        mov r10, 16
    ; Store the current float argument shift
        mov r14, -8 

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
        pop r14
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
;;                                                 with a fixed precision of 6
;; FIXME: 3 system calls is probably too much 
;;=============================================================================
.printFloat:
    ; Load the number into xmm0
        movsd xmm0, qword [rbp + r14]

    ; Output the integer part
        xor eax, eax
        cvttsd2si eax, xmm0
        mov rsi, PrintfIntBuffer
        
        call PrintInteger
        
    ; Output the dot
   ;-----------------------------------
   ; System call №1 (write to file)
   ;    rax - 1
   ;    rdi - file descriptor
   ;    rsi - string
   ;    rdx - string length
   ;-----------------------------------
        mov rax, 1
        mov rdx, 1
        mov rdi, 1
        mov rsi, FloatDelimiter 
        syscall

    ; Output the multiplied by 10^n decimal part
        cvttpd2dq xmm1, xmm0
        cvtdq2pd  xmm1, xmm1
        subsd     xmm0, xmm1
        mulsd     xmm0, [FLOAT_PRECISION_FACT]
        cvttsd2si eax, xmm0

        test eax, eax
        jns .positiveFraction
.negativeFraction:
        neg eax
.positiveFraction:
        mov rsi, PrintfIntBuffer

        call PrintInteger

        ret
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
    ; Put the number into rax
        mov eax, [r10 + rbp]
        mov rsi, PrintfIntBuffer

        call PrintInteger

    ; Move to the next argument
        add r10, 8
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

        mov rcx, PrintfIntBuffer
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

        mov rsi, PrintfIntBuffer
        mov rcx, rsi

    ; Start from the end of the buffer
        add rcx, PRINTF_BUFFER_SIZE - 1

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
        add rsi, PRINTF_BUFFER_SIZE

    ; Increment the number of symbols outputted
        add r13, rdx
        dec r13

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
;; Converts an unsigned integer into 2^n-cimal representation
;;
;; Input:   cl - n
;;=============================================================================
PrintNumberByBits:
        push r12

    ; Put the number into rax
        mov eax, [r10 + rbp]

        mov rsi, PrintfIntBuffer
        mov rdi, rsi

    ; Start from the end of the buffer
        add rdi, PRINTF_BUFFER_SIZE - 1

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
        add rsi, PRINTF_BUFFER_SIZE
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

;;=============================================================================
;; Converts an integer into decimal representation
;; Input:
;;      eax - integer
;;      rsi - buffer
;;
;;=============================================================================
PrintInteger:
    ; Save the regs
        push r12
        xor r12, r12

    ; Start from the end of the buffer
        mov rcx, rsi
        add rcx, PRINTF_BUFFER_SIZE - 1

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
        add rsi, PRINTF_BUFFER_SIZE
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

    ; Restore the regs
        pop r12
        ret

segment .data

PRINTF_FLOAT_PRECISION  equ 6
FLOAT_PRECISION_FACT    dq  0x412e848000000000 ; double 1.0E+6
PrintfReturnAddress     dq  0
PRINTF_BUFFER_SIZE      equ 50
PrintfIntBuffer         db      PRINTF_BUFFER_SIZE dup(0)
PrintfFracBuffer        db '.', PRINTF_BUFFER_SIZE dup(0)
FloatDelimiter          db '.', 0x00

Numbers                 db "0123456789ABCDEF", 0x00

PercentMsg              db "%", 0x00
PercentMsgLen           equ $ - PercentMsg
