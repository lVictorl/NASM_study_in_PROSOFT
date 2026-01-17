global _start                      ; делаем метку метку _start видимой извне
 
section .data                      ; секция данных
    message db  "Hello world!",10  ; строка для вывода на консоль
    length  equ $ - message
    text_error_init db "Error in init", 10
    length_error_init  equ $ - text_error_init
    text_error_print db "Error in time print", 10
    length_error_print equ $ - text_error_print 

    text_error_write db "Error write", 10
    length_error_write equ $ - text_error_write


 
section .text                      ; объявление секции кода
_start:                            ; точка входа в программу
    mov rax, 1                     ; 1 - номер системного вызова функции write
    mov rdi, 1                     ; 1 - дескриптор файла стандартного вызова stdout
    mov rsi, message               ; адрес строки для вывод
    mov rdx, length                ; количество байтов
    cmp rdx, 13
    syscall                        ; выполняем системный вызов write
    ; После записи в rax записывается результат операции

    ; Соответсвенно, следующие проверки:
    cmp rax,0
    jl .error_printing ; Если отрицательное число -> Ошибка записи

    cmp rax, length
    jne .error_write ; Записалось не всё

    mov rax, 60                    ; 60 - номер системного вызова exit
    mov rdi, 0
    syscall                        ; выполняем системный вызов exit
    

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
    mov rsi, text_error_print
    mov rdx, length_error_print
    syscall  
    popf
    ret

.error_write:
    pushf
    mov rax, 1                     ; 1 - номер системного вызова функции write
    mov rdi, 1                     ; 1 - дескриптор файла стандартного вызова stdout
    mov rsi, text_error_write
    mov rdx, length_error_write
    syscall  
    popf
    ret
