global _start

section .data
    ; Сохраняемое в файл сообщение
    message db  "Hello, world", 12
    length  equ $ - message
    filename db "output.txt", 0
    
    ; Сообщения об ошибках
    error_open_msg db "Error: Failed to open file", 0xA, 0
    error_write_msg db "Error: Failed to write to file", 0xA, 0
    error_close_msg db "Error: Failed to close file", 0xA, 0
    error_partial_write_msg db "Error: Partial write to file", 0xA, 0

    ; Длины сообщений
    error_open_len equ $ - error_open_msg
    error_write_len equ $ - error_write_msg
    error_close_len equ $ - error_close_msg
    error_partial_write_len equ $ - error_partial_write_msg 

section .text
    ; Функция вывода строки в stderr
    ; rsi - указатель на строку, rdx - длина строки
    print_error:
        mov rax, 1              ; sys_write
        mov rdi, 2              ; stderr
        syscall
        ret
    
    ; Функция выхода с кодом ошибки
    ; rdi - код ошибки
    exit_with_error:
        mov rax, 60             ; sys_exit
        syscall
    
    ; Проверка целостности записи по количеству байт
    ; После прерывания 1 (запись) в rax устанавливается,
    ; Либо количество записанныйх байт (>0),
    ; Либо код ошибки (<0)
    check_write_count:
        ; Так как rdx не изменялся после записи в него длины сообщения, 
        ; его не трогам
        cmp rax, rdx            ; Сравниваем фактическое и ожидаемое количество
        ret                     ; Возвращаемся с установленными флагами

_start:
    ; Открываем файл                syscall   ( rdi, rsi, rdx, r10, r8, r9)
    mov rax, 2             ; __x64_sys_open  (const char *filename, int flags, umode_t mode)
    mov rdi, filename
    mov rsi, 0x666         ; O_CREAT|O_WRONLY|O_TRUNC  ()
    mov rdx, 0o666         ; Права доступа             (rw-rw-rw-)
    syscall

    ; Проверка ошибки открытия
    cmp rax, 0
    jl error_open           ; Если rax < 0 - ошибка открытия

    ; Сохраняем дескриптор
    push rax

    ; Запись в файл
    mov rdi, rax           ; Дескриптор
    mov rax, 1             ; sys_write
    mov rsi, message
    mov rdx, length
    syscall

    ; Проверка ошибки записи
    cmp rax, 0
    jl error_write          ; Если rax < 0 - ошибка записи

    ; Проверка количества записанных байт с помощью подпрограммы
    call check_write_count   ; Вызываем подпрограмму для сравнения rax и rdx
    jnz error_partial_write  ; Если флаг zero не поднят, значит они не равны
    ; и сообщение записано не полность -> Ошибка

    ; Закрываем файл
    mov rax, 3             ; sys_close
    pop rdi                ; Восстанавливаем дескриптор
    syscall

    
    ; Проверка ошибки закрытия
    cmp rax, 0
    jl error_close          ; Если rax < 0 - ошибка закрытия

    ; Успешное завершение
    mov rax, 60             ; sys_exit
    xor rdi, rdi            ; код 0
    syscall


; Обработчики ошибок

; Обработчик ошибки открытия файла
error_open:
    mov rsi, error_open_msg
    mov rdx, error_open_len
    call print_error
    mov rdi, 1              ; код ошибки для открытия
    jmp exit_with_error

; Обработчик ошибки записи в файл
error_write:
    ; Нужно закрыть файл перед выходом, т.к. он уже открыт
    mov rbx, rax            ; сохраняем код ошибки записи
    mov rax, 3              ; sys_close
    pop rdi                 ; получаем дескриптор из стека
    syscall
    
    mov rsi, error_write_msg
    mov rdx, error_write_len
    call print_error
    mov rdi, 2              ; код ошибки для записи
    jmp exit_with_error

; Обработчик ошибки частичной записи в файл
error_partial_write:
    ; Закрываем файл перед выходом, т.к. он уже открыт
    mov rbx, rax            ; сохраняем количество фактически записанных байт
    mov rax, 3              ; sys_close
    pop rdi                 ; получаем дескриптор из стека
    syscall
    
    mov rsi, error_partial_write_msg
    mov rdx, error_partial_write_len
    call print_error
    mov rdi, 4              ; код ошибки для частичной записи
    jmp exit_with_error

; Обработчик ошибки закрытия файла
error_close:
    mov rsi, error_close_msg
    mov rdx, error_close_len
    call print_error
    mov rdi, 3              ; код ошибки для закрытия
    jmp exit_with_error
