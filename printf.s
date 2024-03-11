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

        call MyPrintf

        push rbp
        mov rbp, [PrintfReturnAddress]
        ret

;;==============================================================================
;; Printf clone
;;
;; rdi   - format string
;; stack - arguments
;;
;;      |          ...          | 
;;      | 2'nd stack argument   |  ~ rbp + 24
;; r15  | 1'st stack argument   |  ~ rbp + 16
;;      +-----------------------+
;;      | return address        |  ~ rbp + 8
;;      | saved rbp             | <- rbp
;;      +-----------------------+
;; r10  | 1'st integer argument |  ~ rbp - 8 
;;      |          ...          | 
;;      | 5'th integer argument |  ~ rbp - 40 
;;      +-----------------------+
;; r14  | 1'st float argument   |  ~ rbp - 48
;;      | 2'nd float argument   |  ~ rbp - 56
;;      |          ...          | 
;;      | n'st float argument   |
;;      +-----------------------+
;;  * - n is determined by the rax register,
;;           which tells how much float registers are passed into the function
;;
;;==============================================================================
MyPrintf:
        push rbp
        mov rbp, rsp

    ;----------------------------------
    ; Allocate memory for the integer arguments
    ; At max we can save 5 ints in our frame
    ; Registers rsi, rdx, rcx, r8, r9 (read AMD64 ABI)
    ;   (Don't forget that the rdi register is holding a format string)
    ;----------------------------------
        sub rsp, 48
        mov [rbp -  8], rsi
        mov [rbp - 16], rdx
        mov [rbp - 24], rcx
        mov [rbp - 32], r8
        mov [rbp - 40], r9

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
        shl rax, 5
    ; Allocate 16n bytes on the stack
        sub rsp, rax

    ; Load to the stack the float arguments 
        shr rax, 5
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
        movsd qword [rbp - 104], xmm7
.float7:
        movsd qword [rbp - 96], xmm6
.float6:
        movsd qword [rbp - 88], xmm5
.float5:
        movsd qword [rbp - 80], xmm4
.float4:
        movsd qword [rbp - 72], xmm3
.float3:
        movsd qword [rbp - 64], xmm2
.float2:
        movsd qword [rbp - 56], xmm1
.float1:
        movsd qword [rbp - 48], xmm0

.noFloatArgs:
    ; Save regs
        push r13
        push r14
        push r15

    ; Save the format into r8
        mov r8, rdi

    ; Store the current integer argument shift
        mov r10, -8
    ; Store the current float argument shift
        mov r14, -48
    ; Store the current stack argument shift
        mov r15, 16
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
        pop r15
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
;; Get integer argument
;; 
;; Returns:
;;      rax - integer argument
;;==============================================================================
GetIntegerArgument:
        cmp r10, -48
        jnz .isNotOnStack
    
.isOnStack:
        mov rax, [rbp + r15]
        add r15, 8
        ret
.isNotOnStack:
        mov rax, [rbp + r10]
        sub r10, 8
        ret

;;==============================================================================
;; Get float argument
;; 
;; Returns:
;;      xmm0 - float argument
;;==============================================================================
GetFloatArgument:
        cmp r14, -112
        jnz .isNotOnStack
    
.isOnStack:
        movsd xmm0, [rbp + r15]
        add r15, 8
        ret
.isNotOnStack:
        movsd xmm0, [rbp + r14]
        sub r14, 8
        ret

;;==============================================================================
;; Prints a specifier
;;
;; Input:
;;      r10 - data offset
;;      rbp - data pointer
;;==============================================================================
PrintSpecifier:
        sub     ebx, '%'
        cmp     bl, 'x' - '%'
        ja      .printError
        movzx   ebx, bl
        jmp     [.jumpTable + rbx*8]
.jumpTable:
        dq          .printPercent
        times 'F' - '%' - 1 dq .printError 
        dq          .printFloat
        times 'X' - 'F' - 1 dq .printError 
        dq          .printHex
        times 'b' - 'X' - 1  dq .printError 
        dq   .printBinary
        dq   .printCharacter
        dq   .printInteger
        times 'f' - 'd' - 1  dq .printError 
        dq   .printFloat
        times 'i' - 'f' - 1  dq .printError 
        dq   .printInteger
        times 'n' - 'i' - 1  dq .printError 
        dq   .printNumberOfCharactersWritten
        dq   .printOctal
        dq   .printAddress
        times 's' - 'p' - 1  dq .printError 
        dq   .printString
        dq   .printError
        dq   .printUnsigned
        times 'x' - 'u' - 1  dq .printError 
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
;;=============================================================================
.printFloat:
        call GetFloatArgument 

    ; Output the integer part
        xor eax, eax
        cvttsd2si eax, xmm0
        mov rsi, PrintfIntBuffer
        
        call PrintInteger
        
    ; Increment the number of outputted symbols
        inc r13

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

        call PrintDecimal

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
        call GetIntegerArgument
        mov eax, eax

        mov rsi, PrintfIntBuffer

        call PrintInteger

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
        call GetIntegerArgument
        mov eax, eax

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
        inc r13

        ret
;;=============================================================================
;; Outputs the number of characters written so far by this call to the function
;;=============================================================================
.printNumberOfCharactersWritten:
        call GetIntegerArgument
        mov [rax], r13

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
        call GetIntegerArgument
        mov eax, eax

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
        call GetIntegerArgument
        mov dl, byte [rax]

    ; While guard
        test dl, dl
        je   .exitEmpty

        xor  rdx, rdx
.percentStrlen:
        inc  rdx
        mov  cl, [rax+rdx]
        test cl, cl
        jnz  .percentStrlen

   ;-----------------------------------
   ; System call №1 (write to file)
   ;    rax - 1
   ;    rdi - file descriptor
   ;    rsi - string
   ;    rdx - string length
   ;-----------------------------------
        mov rsi, rax 
        mov rax, 1
        mov rdi, 1
        syscall

    ; Increment the number of symbols outputted
        add r13, rdx 
        dec r13

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

        call GetIntegerArgument

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

;;=============================================================================
;; Converts an integer into a decimal part of a number. 
;; Input:
;;      eax - integer
;;      rsi - buffer
;;
;;=============================================================================
PrintDecimal:
    ; Start from the end of the buffer
        add rsi, PRINTF_BUFFER_SIZE - 1

    ; Repeat for exactly the number of float precision digits
        mov edi, PRINTF_FLOAT_PRECISION
    ; Convert the number to string
.unsignedToStr:
        xor rdx, rdx

        mov rbx, 10
        div rbx

     ; Convert the remainder to ASCII
        add dl, '0'

    ;  Store the character in the buffer
        dec rsi 
        mov [rsi], dl

        test edi, edi
        dec edi
        jnz .unsignedToStr

    ; Add dot to the beggining
        dec rsi
        mov byte [rsi], '.'
    
   ;-----------------------------------
   ; System call №1 (write to file)
   ;    rax - 1
   ;    rdi - file descriptor
   ;    rsi - string
   ;    rdx - string length
   ;-----------------------------------
        mov rdx, 7
        mov rax, 1
        mov rdi, 1
        syscall

    ; Increment the number of symbols outputted
        add r13, 7
        ret

segment .data

PRINTF_FLOAT_PRECISION  equ 6
FLOAT_PRECISION_FACT    dq  0x412e848000000000 ; double 1.0E+6
PrintfReturnAddress     dq  0
PRINTF_BUFFER_SIZE      equ 50
PrintfIntBuffer         db  PRINTF_BUFFER_SIZE dup(0)

Numbers                 db "0123456789abcdef", 0x00

PercentMsg              db "%", 0x00
PercentMsgLen           equ $ - PercentMsg
