global _start

section .data
    message db  "Hello, world", 12
    length  equ $ - message
    filename db "output.txt", 0

section .text
_start:
    ; Открываем файл                syscall   ( rdi, rsi, rdx, r10, r8, r9)
    mov rax, 2             ; __x64_sys_open  (const char *filename, int flags, umode_t mode)
    mov rdi, filename
    mov rsi, 0x441         ; O_CREAT|O_WRONLY|O_TRUNC
    mov rdx, 0o644         ; Права доступа
    syscall

    ; Сохраняем дескриптор
    push rax

    ; Запись в файл
    mov rdi, rax           ; Дескриптор
    mov rax, 1             ; sys_write
    mov rsi, message
    mov rdx, length
    syscall

    ; Закрываем файл
    mov rax, 3             ; sys_close
    pop rdi                ; Восстанавливаем дескриптор
    syscall

    mov rax, 60            ; sys_exit
    xor rdi, rdi
    syscall
