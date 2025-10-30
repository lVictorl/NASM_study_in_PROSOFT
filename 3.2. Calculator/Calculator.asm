section .data
    ; Сегмент данных - константы и сообщения
    prompt1 db "Enter 1 number: ", 0
    prompt1_len equ $ - prompt1
    prompt2 db "Enter 2 number: ", 0
    prompt2_len equ $ - prompt2
    answer db "Answer: ", 0
    answer_len equ $ - answer
    newline db 10
    error_read db "Error: Failed to read input", 10, 0
    error_read_len equ $ - error_read
    error_write db "Error: Failed to write output", 10, 0
    error_write_len equ $ - error_write
    error_range db "Error: Number out of range (-32767 to 32767)", 10, 0
    error_range_len equ $ - error_range
    error_format db "Error: Invalid number format", 10, 0
    error_format_len equ $ - error_format
    error_empty db "Error: Empty input is not allowed", 10, 0
    error_empty_len equ $ - error_empty
    error_overflow db "Error: Arithmetic overflow", 10, 0
    error_overflow_len equ $ - error_overflow

section .bss
    ; Сегмент неинициализированных данных - буферы
    buffer resb 32      ; Буфер для ввода числа
    num1 resw 1         ; Первое число (16 бит)
    num2 resw 1         ; Второе число (16 бит)
    result_str resb 16  ; Строка для результата

section .text
    global _start

; ======================== ГЛАВНАЯ ПРОГРАММА ========================
_start:
    ; ВВОД ПЕРВОГО ЧИСЛА
    call read_number
    test eax, eax       ; проверка на ошибку
    jnz error_exit
    mov ax, [buffer]    ; загружаем преобразованное число
    mov [num1], ax      ; сохраняем первое число
    
    ; ВВОД ВТОРОГО ЧИСЛА
    call read_number
    test eax, eax       ; проверка на ошибку
    jnz error_exit
    mov ax, [buffer]    ; загружаем преобразованное число
    mov [num2], ax      ; сохраняем второе число
    
    ; ВЫЧИСЛЕНИЕ СУММЫ
    mov ax, [num1]      ; загружаем первое число
    mov bx, [num2]      ; загружаем второе число
    call sum            ; вызов функции сложения
    
    ; ПРОВЕРКА ПЕРЕПОЛНЕНИЯ
    jo overflow_error   ; если произошло переполнение
    
    mov bx, ax          ; сохраняем результат в BX
    
    ; ПРЕОБРАЗОВАНИЕ РЕЗУЛЬТАТА В СТРОКУ
    mov ax, bx          ; число для преобразования
    mov edi, result_str ; буфер для строки
    call int_to_string  ; вызов функции преобразования
    
    ; ВЫВОД РЕЗУЛЬТАТА
    mov eax, 4          ; sys_write
    mov ebx, 1
    mov ecx, answer     ; "Answer: "
    mov edx, answer_len
    int 0x80
    test eax, eax       ; проверка успешности записи
    js write_error      ; если ошибка
    
    ; Вычисляем длину строки результата
    mov ecx, result_str
    call get_string_length
    mov edx, eax        ; EDX = длина строки
    
    mov eax, 4          ; вывод самого числа
    mov ebx, 1
    mov ecx, result_str
    int 0x80
    test eax, eax       ; проверка успешности записи
    js write_error      ; если ошибка
    
    mov eax, 4          ; новая строка
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

; ======================== ФУНКЦИЯ ВВОДА ЧИСЛА ========================
; Функция читает и проверяет число, возвращает в buffer
read_number:
    push ebp
    mov ebp, esp
    
    ; Определяем какое число вводим (1 или 2)
    mov eax, [ebp+8]    ; получаем номер числа из стека
    test eax, eax
    jnz .second_number
    
.first_number:
    mov ecx, prompt1
    mov edx, prompt1_len
    jmp .print_prompt
    
.second_number:
    mov ecx, prompt2
    mov edx, prompt2_len
    
.print_prompt:
    ; ВЫВОД ПРИГЛАШЕНИЯ
    mov eax, 4          ; sys_write
    mov ebx, 1          ; stdout
    int 0x80
    test eax, eax       ; проверка успешности записи
    js .read_error
    
    ; ЧТЕНИЕ ВВОДА
    mov eax, 3          ; sys_read
    mov ebx, 0          ; stdin
    mov ecx, buffer     ; буфер для ввода
    mov edx, 32         ; максимальная длина
    int 0x80
    test eax, eax       ; проверка успешности чтения
    js .read_error
    jz .empty_error     ; если ничего не прочитано
    
    ; ПРОВЕРКА ДЛИНЫ ВВОДА
    cmp eax, 32
    jge .too_long_error
    
    ; УДАЛЕНИЕ СИМВОЛА НОВОЙ СТРОКИ
    mov edi, buffer
    call remove_newline
    
    ; ПРОВЕРКА НА ПУСТОЙ ВВОД
    call check_empty_string
    test eax, eax
    jnz .empty_error
    
    ; ПРЕОБРАЗОВАНИЕ СТРОКИ В ЧИСЛО
    mov esi, buffer     ; ESI = указатель на строку
    call string_to_int  ; вызов функции преобразования
    
    ; ПРОВЕРКА РЕЗУЛЬТАТА ПРЕОБРАЗОВАНИЯ
    cmp eax, 0          ; успех?
    je .success
    cmp eax, 1          ; ошибка формата?
    je .format_error
    cmp eax, 2          ; ошибка диапазона?
    je .range_error
    
.format_error:
    call format_error_handler
    mov eax, 1
    jmp .done
    
.range_error:
    call range_error_handler
    mov eax, 1
    jmp .done
    
.read_error:
    call read_error_handler
    mov eax, 1
    jmp .done
    
.empty_error:
    call empty_error_handler
    mov eax, 1
    jmp .done
    
.too_long_error:
    ; Ошибка слишком длинного ввода
    mov eax, 1
    jmp .done
    
.success:
    mov eax, 0          ; успешное завершение
    
.done:
    pop ebp
    ret 4

; ======================== ОБРАБОТЧИКИ ОШИБОК ========================
read_error:
    call read_error_handler
    jmp error_exit

write_error:
    call write_error_handler
    jmp error_exit

range_error:
    call range_error_handler
    jmp error_exit

format_error:
    call format_error_handler
    jmp error_exit

empty_error:
    call empty_error_handler
    jmp error_exit

overflow_error:
    mov eax, 4
    mov ebx, 1
    mov ecx, error_overflow
    mov edx, error_overflow_len
    int 0x80
    jmp error_exit

read_error_handler:
    mov eax, 4
    mov ebx, 1
    mov ecx, error_read
    mov edx, error_read_len
    int 0x80
    ret

write_error_handler:
    mov eax, 4
    mov ebx, 1
    mov ecx, error_write
    mov edx, error_write_len
    int 0x80
    ret

range_error_handler:
    mov eax, 4
    mov ebx, 1
    mov ecx, error_range
    mov edx, error_range_len
    int 0x80
    ret

format_error_handler:
    mov eax, 4
    mov ebx, 1
    mov ecx, error_format
    mov edx, error_format_len
    int 0x80
    ret

empty_error_handler:
    mov eax, 4
    mov ebx, 1
    mov ecx, error_empty
    mov edx, error_empty_len
    int 0x80
    ret

error_exit:
    ; ЗАВЕРШЕНИЕ ПРОГРАММЫ С ОШИБКОЙ
    mov eax, 1          ; sys_exit
    mov ebx, 1          ; код возврата 1 (ошибка)
    int 0x80

; ======================== ФУНКЦИИ ========================

; ФУНКЦИЯ: remove_newline
; Назначение: Удаляет символ новой строки из конца строки
remove_newline:
    push ebp
    mov ebp, esp
    push eax
    push edi
    
    mov edi, buffer
.search_loop:
    mov al, [edi]
    cmp al, 0
    je .done
    cmp al, 10
    je .found_newline
    inc edi
    jmp .search_loop

.found_newline:
    mov byte [edi], 0

.done:
    pop edi
    pop eax
    pop ebp
    ret

; ФУНКЦИЯ: check_empty_string
; Назначение: Проверяет, является ли строка пустой
check_empty_string:
    push ebp
    mov ebp, esp
    push edi
    
    mov edi, buffer
    mov eax, 0
.check_loop:
    mov cl, [edi]
    test cl, cl
    jz .is_empty
    cmp cl, 32
    je .next_char
    cmp cl, 9
    je .next_char
    jmp .not_empty
    
.next_char:
    inc edi
    jmp .check_loop

.is_empty:
    mov eax, 1

.not_empty:
    pop edi
    pop ebp
    ret

; ФУНКЦИЯ: string_to_int
; Назначение: Преобразует строку в 16-битное целое число со знаком
; Вход: ESI - указатель на строку
; Выход: AX - число, EAX=0 (успех), 1 (ошибка формата), 2 (ошибка диапазона)
string_to_int:
    push ebp
    mov ebp, esp
    push ebx
    push ecx
    push edx
    push esi
    
    xor eax, eax        ; обнуляем результат
    xor ebx, ebx        ; флаг знака (0 = положительное)
    xor ecx, ecx        ; счетчик цифр
    mov edx, 10         ; основание системы счисления
    
    ; ПРОВЕРКА ПУСТОЙ СТРОКИ
    cmp byte [esi], 0
    je .format_error
    
    ; ПРОВЕРКА ЗНАКА
    cmp byte [esi], '-' ; отрицательное число?
    jne .check_plus
    mov ebx, 1          ; устанавливаем флаг отрицательного
    inc esi             ; пропускаем знак '-'
    jmp .after_sign

.check_plus:
    cmp byte [esi], '+' ; явный плюс?
    jne .after_sign
    inc esi             ; пропускаем знак '+'

.after_sign:
    ; ПРОВЕРКА НА ОТСУТСТВИЕ ЦИФР ПОСЛЕ ЗНАКА
    cmp byte [esi], 0
    je .format_error
    
    ; ОБРАБОТКА ЦИФР
.digit_loop:
    mov cl, [esi]       ; текущий символ
    cmp cl, 0           ; нуль-терминатор?
    je .end_digits
    
    ; ПРОВЕРКА НА ЦИФРУ
    cmp cl, '0'
    jb .format_error
    cmp cl, '9'
    ja .format_error
    
    sub cl, '0'         ; преобразование символа в цифру
    
    ; ПРОВЕРКА ПЕРЕПОЛНЕНИЯ ПЕРЕД УМНОЖЕНИЕМ
    cmp eax, 3276       ; 32767/10
    ja .range_error
    jb .ok_multiply
    ; если eax == 3276, проверяем последнюю цифру
    test ebx, ebx       ; положительное число?
    jz .check_positive_max
    cmp cl, 8           ; для -32768 максимальная цифра 8
    ja .range_error
    jmp .ok_multiply
    
.check_positive_max:
    cmp cl, 7           ; для 32767 максимальная цифра 7
    ja .range_error
    
.ok_multiply:
    imul eax, edx       ; умножаем текущий результат на 10
    add eax, ecx        ; добавляем новую цифру
    
    inc esi
    jmp .digit_loop

.end_digits:
    ; УЧЕТ ЗНАКА
    test ebx, ebx       ; проверка флага знака
    jz .positive_num
    neg eax             ; преобразование в отрицательное

.positive_num:
    ; ПРОВЕРКА ДИАПАЗОНА
    cmp eax, 32767
    jg .range_error
    cmp eax, -32768
    jl .range_error
    
    mov [buffer], ax    ; сохраняем результат
    mov eax, 0          ; успех
    jmp .done

.format_error:
    mov eax, 1          ; ошибка формата
    jmp .done

.range_error:
    mov eax, 2          ; ошибка диапазона

.done:
    pop esi
    pop edx
    pop ecx
    pop ebx
    pop ebp
    ret

; ФУНКЦИЯ: int_to_string
; Назначение: Преобразует 16-битное целое число в строку
; Вход: AX - число, EDI - буфер для строки
; Выход: EDI содержит строку
int_to_string:
    push ebp
    mov ebp, esp
    push eax
    push ebx
    push ecx
    push edx
    push edi
    
    mov ebx, 10         ; основание системы счисления
    mov ecx, 0          ; счетчик цифр
    
    ; ОБРАБОТКА НУЛЯ
    test ax, ax
    jnz .not_zero
    mov byte [edi], '0'
    mov byte [edi+1], 0
    jmp .done
    
.not_zero:
    ; ОБРАБОТКА ЗНАКА
    test ax, ax         ; проверка знака числа
    jns .positive
    neg ax              ; делаем число положительным
    mov byte [edi], '-' ; добавляем знак минуса
    inc edi

.positive:
    ; ВЫДЕЛЕНИЕ ЦИФР ИЗ ЧИСЛА
.divide_loop:
    xor edx, edx        ; обнуляем EDX для деления
    div bx              ; DX:AX / 10, остаток в DX
    add dl, '0'         ; преобразуем цифру в символ
    push dx             ; сохраняем цифру в стек
    inc ecx             ; увеличиваем счетчик цифр
    test ax, ax         ; число стало нулем?
    jnz .divide_loop
    
    ; ФОРМИРОВАНИЕ СТРОКИ ИЗ СТЕКА
.pop_loop:
    pop ax              ; извлекаем цифру из стека
    mov [edi], al       ; записываем в буфер
    inc edi
    loop .pop_loop
    
    mov byte [edi], 0   ; добавляем нуль-терминатор
    
.done:
    pop edi
    pop edx
    pop ecx
    pop ebx
    pop eax
    pop ebp
    ret

; ФУНКЦИЯ: sum
; Назначение: Складывает два 16-битных числа
; Вход: AX - первое число, BX - второе число
; Выход: AX - сумма, флаги установлены для проверки переполнения
sum:
    push ebp
    mov ebp, esp
    
    add ax, bx          ; сложение чисел
    ; Флаг OF будет установлен при переполнении со знаком
    
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