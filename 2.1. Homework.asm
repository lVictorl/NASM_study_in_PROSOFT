global _start                      ; делаем метку метку _start видимой извне
 
section .data                      ; секция данных
    message db  "Hello world!",10  ; строка для вывода на консоль
    length  equ $ - message
    text_error_init db "Error in init", 13
    length_error_init  equ $ - text_error_init
    text_error_print db "Error in time print", 19


 
section .text                      ; объявление секции кода
_start:                            ; точка входа в программу
    mov rax, 1                     ; 1 - номер системного вызова функции write
    mov rdi, 1                     ; 1 - дескриптор файла стандартного вызова stdout
    mov rsi, message               ; адрес строки для вывод
    mov rdx, length                ; количество байтов
    cmp rdx, 10
    jnz .error_init                      
    syscall                        ; выполняем системный вызов write
    
    cmp rdx, 0
    jl .error_printing

    mov rax, 60                    ; 60 - номер системного вызова exit
    syscall                        ; выполняем системный вызов exit
    
    cmp rdi,0

.error_init:
    pushf
    mov rax, 1                     ; 1 - номер системного вызова функции write
    mov rdi, 1                     ; 1 - дескриптор файла стандартного вызова stdout
    mov rsi, text_error_init
    mov rdx, length_error_init
    syscall
    popf
    ret

.error_printing:
    pushf
    mov rax, 1                     ; 1 - номер системного вызова функции write
    mov rdi, 1                     ; 1 - дескриптор файла стандартного вызова stdout
    mov rsi, text_error_printing
    mov rdx, length_error_printing
    syscall  
    popf
    ret
