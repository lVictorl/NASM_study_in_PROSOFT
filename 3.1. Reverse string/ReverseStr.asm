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
    mov eax, 4          ; sys_write
    mov ebx, 1          ; stdout
    mov ecx, prompt     ; указатель на сообщение
    mov edx, prompt_len ; длина сообщения
    int 0x80
    test eax, eax       ; проверка успешности записи
    js write_error      ; если ошибка
    
    ; ЧТЕНИЕ СТРОКИ С КЛАВИАТУРЫ
    mov eax, 3          ; sys_read
    mov ebx, 0          ; stdin
    mov ecx, input      ; буфер для ввода
    mov edx, 101        ; максимальная длина (100 символов + \n)
    int 0x80
    test eax, eax       ; проверка успешности чтения
    js read_error       ; если ошибка чтения
    jz empty_error      ; если ничего не прочитано
    
    ; Сохраняем длину введенной строки
    mov esi, eax        ; ESI = длина строки
    
    ; ПРОВЕРКА ДЛИНЫ СТРОКИ
    cmp esi, 101        ; сравнение с максимальной длиной
    jge too_long_error  ; если строка слишком длинная
    
    ; ПРОВЕРКА НА ПУСТУЮ СТРОКУ (только \n)
    cmp esi, 1
    jne .not_empty
    cmp byte [input], 10 ; проверка на символ новой строки
    je empty_error
.not_empty:
    
    ; УДАЛЕНИЕ СИМВОЛА НОВОЙ СТРОКИ
    mov edi, input      ; EDI = указатель на строку
    call remove_newline ; вызов функции удаления новой строки
    
    ; ПРОВЕРКА НА ПУСТУЮ СТРОКУ ПОСЛЕ УДАЛЕНИЯ \n
    call check_empty_string
    test eax, eax
    jnz empty_error
    
    ; РАЗВОРОТ СТРОКИ
    mov edi, input      ; EDI = исходная строка
    mov esi, reversed   ; ESI = буфер для результата
    call reverse_string ; вызов функции разворота
    
    ; ВЫВОД РЕЗУЛЬТАТА
    mov eax, 4          ; sys_write
    mov ebx, 1          ; stdout
    mov ecx, result     ; сообщение "Reversed: "
    mov edx, result_len
    int 0x80
    test eax, eax       ; проверка успешности записи
    js write_error      ; если ошибка
    
    mov eax, 4          ; sys_write для вывода развернутой строки
    mov ebx, 1
    mov ecx, reversed
    call get_string_length ; получаем длину развернутой строки
    mov edx, eax        ; EDX = длина строки
    int 0x80
    test eax, eax       ; проверка успешности записи
    js write_error      ; если ошибка
    
    ; ВЫВОД СИМВОЛА НОВОЙ СТРОКИ
    mov eax, 4
    mov ebx, 1
    mov ecx, newline
    mov edx, 1
    int 0x80
    test eax, eax       ; проверка успешности записи
    js write_error      ; если ошибка
    
    ; УСПЕШНОЕ ЗАВЕРШЕНИЕ ПРОГРАММЫ
    mov eax, 1          ; sys_exit
    mov ebx, 0          ; код возврата 0
    int 0x80

; ======================== ОБРАБОТЧИКИ ОШИБОК ========================
read_error:
    ; ОШИБКА ЧТЕНИЯ
    mov eax, 4
    mov ebx, 1
    mov ecx, error_read
    mov edx, error_read_len
    int 0x80
    jmp error_exit

write_error:
    ; ОШИБКА ЗАПИСИ
    mov eax, 4
    mov ebx, 1
    mov ecx, error_write
    mov edx, error_write_len
    int 0x80
    jmp error_exit

empty_error:
    ; ОШИБКА: ПУСТАЯ СТРОКА
    mov eax, 4
    mov ebx, 1
    mov ecx, error_empty
    mov edx, error_empty_len
    int 0x80
    jmp error_exit

too_long_error:
    ; ОШИБКА: СЛИШКОМ ДЛИННАЯ СТРОКА
    mov eax, 4
    mov ebx, 1
    mov ecx, error_too_long
    mov edx, error_too_long_len
    int 0x80

error_exit:
    ; ЗАВЕРШЕНИЕ ПРОГРАММЫ С ОШИБКОЙ
    mov eax, 1          ; sys_exit
    mov ebx, 1          ; код возврата 1 (ошибка)
    int 0x80

; ======================== ФУНКЦИИ ========================

; ФУНКЦИЯ: remove_newline
; Назначение: Удаляет символ новой строки из конца строки
; Вход: EDI - указатель на строку
; Выход: Строка без символа новой строки
remove_newline:
    push ebp
    mov ebp, esp
    push eax
    push edi
    
.search_loop:
    mov al, [edi]       ; Загружаем текущий символ
    cmp al, 0           ; Конец строки?
    je .done
    cmp al, 10          ; Символ новой строки?
    je .found_newline
    inc edi
    jmp .search_loop

.found_newline:
    mov byte [edi], 0   ; Заменяем символ новой строки на нуль-терминатор

.done:
    pop edi
    pop eax
    pop ebp
    ret

; ФУНКЦИЯ: reverse_string
; Назначение: Разворачивает строку задом наперед
; Вход: EDI - исходная строка, ESI - буфер для результата
; Выход: ESI содержит развернутую строку
reverse_string:
    push ebp
    mov ebp, esp
    push eax
    push ebx
    push ecx
    push edx
    push edi
    push esi
    
    ; НАХОЖДЕНИЕ ДЛИНЫ СТРОКИ
    mov ebx, edi        ; Сохраняем начало строки
    mov ecx, 0          ; Счетчик длины
    
.length_loop:
    cmp byte [edi], 0   ; Конец строки?
    je .length_done
    inc ecx             ; Увеличиваем счетчик
    inc edi             ; Переходим к следующему символу
    jmp .length_loop

.length_done:
    ; ПРОВЕРКА НА ПУСТУЮ СТРОКУ
    test ecx, ecx
    jz .reverse_done
    
    ; РАЗВОРОТ СТРОКИ
    mov edi, ebx        ; Восстанавливаем начало строки
    add edi, ecx        ; Переходим к концу строки
    dec edi             ; Последний символ (перед нуль-терминатором)
    
.reverse_loop:
    cmp ecx, 0          ; Все символы обработаны?
    je .reverse_done
    mov al, [edi]       ; Берем символ с конца
    mov [esi], al       ; Записываем в начало результата
    dec edi             ; Двигаемся назад по исходной строке
    inc esi             ; Двигаемся вперед по результату
    dec ecx             ; Уменьшаем счетчик
    jmp .reverse_loop

.reverse_done:
    mov byte [esi], 0   ; Добавляем нуль-терминатор
    
    pop esi
    pop edi
    pop edx
    pop ecx
    pop ebx
    pop eax
    pop ebp
    ret

; ФУНКЦИЯ: check_empty_string
; Назначение: Проверяет, является ли строка пустой
; Вход: EDI - указатель на строку
; Выход: EAX = 1 если пустая, 0 если нет
check_empty_string:
    push ebp
    mov ebp, esp
    push edi
    
    mov eax, 0          ; по умолчанию не пустая
.check_loop:
    mov cl, [edi]
    test cl, cl         ; конец строки?
    jz .is_empty
    cmp cl, 32          ; пробел?
    je .next_char
    cmp cl, 9           ; табуляция?
    je .next_char
    jmp .not_empty      ; нашли не-whitespace символ
    
.next_char:
    inc edi
    jmp .check_loop

.is_empty:
    mov eax, 1          ; строка пустая

.not_empty:
    pop edi
    pop ebp
    ret

; ФУНКЦИЯ: get_string_length
; Назначение: Вычисляет длину строки
; Вход: ECX - указатель на строку
; Выход: EAX - длина строки
get_string_length:
    push ebp
    mov ebp, esp
    push ecx
    
    mov eax, 0
.count_loop:
    cmp byte [ecx], 0
    je .done
    inc eax
    inc ecx
    jmp .count_loop
    
.done:
    pop ecx
    pop ebp
    ret