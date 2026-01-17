section .data
    ; Сегмент данных - константы и сообщения
    prompt db "Enter your string: ", 0
    prompt_len equ $ - prompt
    result db "Reversed: ", 0
    result_len equ $ - result
    newline db 10
    error_read db "Error: Failed to read input", 10, 0
    error_read_len equ $ - error_read
    error_write db "Error: Failed to write output", 10, 0
    error_write_len equ $ - error_write
    error_empty db "Error: Empty string is not allowed", 10, 0
    error_empty_len equ $ - error_empty
    error_too_long db "Error: String too long (max 100 chars)", 10, 0
    error_too_long_len equ $ - error_too_long

section .bss
    ; Сегмент неинициализированных данных - буферы
    input resb 102      ; Буфер для ввода (100 символов + \n + \0)
    reversed resb 101   ; Буфер для развернутой строки

section .text
    global _start

; ======================== ГЛАВНАЯ ПРОГРАММА ========================
_start:
    ; ВЫВОД ПРИГЛАШЕНИЯ К ВВОДУ
    ; syscall: write(fd, buf, count)
    mov rax, 1          ; sys_write
    mov rdi, 1          ; stdout
    mov rsi, prompt
    mov rdx, prompt_len
    syscall
    test rax, rax       ; проверка успешности записи
    js write_error      ; если ошибка
    
    ; ЧТЕНИЕ СТРОКИ С КЛАВИАТУРЫ
    ; syscall: read(fd, buf, count)
    mov rax, 0          ; sys_read
    mov rdi, 0          ; stdin
    mov rsi, input
    mov rdx, 101        ; максимальная длина (100 символов + \n)
    syscall
    test rax, rax       ; проверка успешности чтения
    js read_error       ; если ошибка чтения
    jz empty_error      ; если ничего не прочитано
    
    ; Сохраняем длину введенной строки
    mov r12, rax        ; R12 = длина строки (сохраняем, т.к. rax будет изменяться)
    
    ; ПРОВЕРКА ДЛИНЫ СТРОКИ
    cmp r12, 101        ; сравнение с максимальной длиной
    jge too_long_error  ; если строка слишком длинная
    
    ; ПРОВЕРКА НА ПУСТУЮ СТРОКУ (только \n)
    cmp r12, 1
    jne .not_empty
    cmp byte [input], 10 ; проверка на символ новой строки
    je empty_error
.not_empty:
    
    ; УДАЛЕНИЕ СИМВОЛА НОВОЙ СТРОКИ
    mov rdi, input      ; RDI = указатель на строку
    call remove_newline ; вызов функции удаления новой строки
    
    ; ПРОВЕРКА НА ПУСТУЮ СТРОКУ ПОСЛЕ УДАЛЕНИЯ \n
    mov rdi, input      ; Убедимся, что RDI содержит input
    call check_empty_string
    test rax, rax
    jnz empty_error
    
    ; РАЗВОРОТ СТРОКИ
    mov rdi, input      ; RDI = исходная строка
    mov rsi, reversed   ; RSI = буфер для результата
    call reverse_string ; вызов функции разворота
    ; Теперь в RAX указатель на начало развернутой строки
    
    ; Сохраняем указатель на развернутую строку
    mov r13, rax        ; R13 = указатель на развернутую строку
    
    ; ВЫВОД СООБЩЕНИЯ "Reversed: "
    mov rax, 1          ; sys_write
    mov rdi, 1          ; stdout
    mov rsi, result
    mov rdx, result_len
    syscall
    test rax, rax       ; проверка успешности записи
    js write_error      ; если ошибка
    
    ; ВЫВОД РАЗВЕРНУТОЙ СТРОКИ
    ; Сначала вычислим длину развернутой строки
    mov rdi, r13        ; RDI = указатель на развернутую строку
    call get_string_length ; RAX = длина строки
    mov rdx, rax        ; RDX = длина для write
    
    ; Теперь выводим
    mov rax, 1          ; sys_write
    mov rdi, 1          ; stdout
    mov rsi, r13        ; RSI = указатель на развернутую строку
    syscall
    test rax, rax       ; проверка успешности записи
    js write_error      ; если ошибка
    
    ; ВЫВОД СИМВОЛА НОВОЙ СТРОКИ
    mov rax, 1
    mov rdi, 1
    mov rsi, newline
    mov rdx, 1
    syscall
    test rax, rax       ; проверка успешности записи
    js write_error      ; если ошибка
    
    ; УСПЕШНОЕ ЗАВЕРШЕНИЕ ПРОГРАММЫ
    ; syscall: exit(status)
    mov rax, 60         ; sys_exit
    mov rdi, 0          ; код возврата 0
    syscall

; ======================== ОБРАБОТЧИКИ ОШИБОК ========================
read_error:
    ; ОШИБКА ЧТЕНИЯ
    mov rax, 1
    mov rdi, 1
    mov rsi, error_read
    mov rdx, error_read_len
    syscall
    jmp error_exit

write_error:
    ; ОШИБКА ЗАПИСИ
    mov rax, 1
    mov rdi, 1
    mov rsi, error_write
    mov rdx, error_write_len
    syscall
    jmp error_exit

empty_error:
    ; ОШИБКА: ПУСТАЯ СТРОКА
    mov rax, 1
    mov rdi, 1
    mov rsi, error_empty
    mov rdx, error_empty_len
    syscall
    jmp error_exit

too_long_error:
    ; ОШИБКА: СЛИШКОМ ДЛИННАЯ СТРОКА
    mov rax, 1
    mov rdi, 1
    mov rsi, error_too_long
    mov rdx, error_too_long_len
    syscall

error_exit:
    ; ЗАВЕРШЕНИЕ ПРОГРАММЫ С ОШИБКОЙ
    mov rax, 60         ; sys_exit
    mov rdi, 1          ; код возврата 1 (ошибка)
    syscall

; ======================== ФУНКЦИИ ========================

; ФУНКЦИЯ: remove_newline
; Назначение: Удаляет символ новой строки из конца строки
; Вход: RDI - указатель на строку
; Выход: Строка без символа новой строки (нуль-терминированная)
remove_newline:
    push rbp
    mov rbp, rsp
    
.search_newline:
    cmp byte [rdi], 0   ; Конец строки?
    je .nl_done
    cmp byte [rdi], 10  ; Символ новой строки?
    je .found_newline
    inc rdi
    jmp .search_newline

.found_newline:
    mov byte [rdi], 0   ; Заменяем символ новой строки на нуль-терминатор

.nl_done:
    pop rbp
    ret

; ФУНКЦИЯ: reverse_string
; Назначение: Разворачивает строку задом наперед
; Вход: RDI - указатель на исходную строку (нуль-терминированная)
;       RSI - указатель на буфер для результата (должен быть достаточно большим)
; Выход: RAX - указатель на начало развернутой строки (тот же что и RSI на входе)
reverse_string:
    push rbp
    mov rbp, rsp
    push rbx
    push rcx
    push rdx
    
    ; Сохраняем начало буфера для результата
    mov rax, rsi        ; RAX будет хранить начало результата
    
    ; Находим длину исходной строки
    mov rbx, rdi        ; RBX = текущая позиция в исходной строке
    mov rcx, 0          ; RCX = длина строки
    
.find_length:
    cmp byte [rbx], 0
    je .length_found
    inc rcx
    inc rbx
    jmp .find_length

.length_found:
    ; Проверка на пустую строку
    test rcx, rcx
    jz .empty_string
    
    ; Устанавливаем указатель на конец исходной строки
    mov rbx, rdi
    add rbx, rcx
    dec rbx             ; RBX указывает на последний символ
    
    ; Разворачиваем строку
.reverse_loop:
    test rcx, rcx
    jz .reverse_done
    mov dl, byte [rbx]  ; Берем символ с конца
    mov byte [rsi], dl  ; Записываем в начало результата
    dec rbx
    inc rsi
    dec rcx
    jmp .reverse_loop

.empty_string:
    mov byte [rsi], 0
    jmp .reverse_done

.reverse_done:
    mov byte [rsi], 0   ; Добавляем нуль-терминатор
    
    ; RAX уже содержит начало результата
    pop rdx
    pop rcx
    pop rbx
    pop rbp
    ret

; ФУНКЦИЯ: check_empty_string
; Назначение: Проверяет, является ли строка пустой (содержит только whitespace символы)
; Вход: RDI - указатель на строку
; Выход: RAX = 1 если пустая, 0 если нет
check_empty_string:
    push rbp
    mov rbp, rsp
    
    mov rax, 0          ; по умолчанию не пустая
.check_loop:
    mov dl, byte [rdi]
    test dl, dl         ; конец строки?
    jz .is_empty
    cmp dl, 32          ; пробел?
    je .next_char
    cmp dl, 9           ; табуляция?
    je .next_char
    jmp .not_empty      ; нашли не-whitespace символ
    
.next_char:
    inc rdi
    jmp .check_loop

.is_empty:
    mov rax, 1          ; строка пустая

.not_empty:
    pop rbp
    ret

; ФУНКЦИЯ: get_string_length
; Назначение: Вычисляет длину нуль-терминированной строки
; Вход: RDI - указатель на строку
; Выход: RAX - длина строки (без учета нуль-терминатора)
get_string_length:
    push rbp
    mov rbp, rsp
    push rdi            ; Сохраняем оригинальный указатель
    
    mov rax, 0
.count_chars:
    cmp byte [rdi], 0
    je .count_complete
    inc rax
    inc rdi
    jmp .count_chars
    
.count_complete:
    pop rdi             ; Восстанавливаем оригинальный указатель
    pop rbp
    ret
