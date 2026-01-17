section .data
    ; Сегмент данных - константы и сообщения
    prompt1 db "Enter 1 number: ", 0
    prompt2 db "Enter 2 number: ", 0
    answer db "Answer: ", 0
    newline db 10
    error_read db "Error: Failed to read input", 10, 0
    error_write db "Error: Failed to write output", 10, 0
    error_range db "Error: Number out of 64-bit range", 10, 0
    error_format db "Error: Invalid number format", 10, 0
    error_empty db "Error: Empty input is not allowed", 10, 0
    error_overflow db "Error: Arithmetic overflow", 10, 0
    
    ; Константы для проверки диапазона 64-битных чисел
    ; (добавлены как данные, а не как непосредственные значения)
    max_positive_div10 dq 922337203685477580   ; 2^63/10
    min_negative_div10 dq -922337203685477580  ; -2^63/10

section .bss
    ; Сегмент неинициализированных данных - буферы
    buffer resb 64      ; Буфер для ввода числа
    num1 resq 1         ; Первое число (64 бит)
    num2 resq 1         ; Второе число (64 бит)
    result_str resb 32  ; Строка для результата

section .text
    global _start

; ======================== ГЛАВНАЯ ПРОГРАММА ========================
_start:
    ; ВВОД ПЕРВОГО ЧИСЛА
    mov rdi, 1
    call read_number
    test rax, rax       ; проверка на ошибку
    jnz error_exit
    
    ; ВВОД ВТОРОГО ЧИСЛА
    mov rdi, 2
    call read_number
    test rax, rax       ; проверка на ошибку
    jnz error_exit
    
    ; ВЫЧИСЛЕНИЕ СУММЫ
    mov rax, [num1]     ; загружаем первое число (64 бит)
    mov rbx, [num2]     ; загружаем второе число (64 бит)
    add rax, rbx        ; складываем числа
    jo overflow_error   ; проверка на переполнение
    
    ; ПРЕОБРАЗОВАНИЕ РЕЗУЛЬТАТА В СТРОКУ
    mov rdi, result_str ; буфер для строки
    call int64_to_string ; вызов функции преобразования 64-битного числа
    
    ; ВЫВОД РЕЗУЛЬТАТА
    mov rsi, answer     ; "Answer: "
    call strlen
    mov rdx, rax        ; EDX = длина строки
    mov rax, 1          ; sys_write
    mov rdi, 1          ; stdout
    syscall
    cmp rax, 0          ; проверка успешности записи
    jl write_error      ; если ошибка
    
    ; Вычисляем длину строки результата
    mov rsi, result_str
    call strlen
    mov rdx, rax        ; EDX = длина строки
    
    mov rax, 1          ; вывод самого числа
    mov rdi, 1          ; stdout
    mov rsi, result_str
    syscall
    cmp rax, 0          ; проверка успешности записи
    jl write_error      ; если ошибка
    
    mov rax, 1          ; новая строка
    mov rdi, 1
    mov rsi, newline
    mov rdx, 1
    syscall
    cmp rax, 0          ; проверка успешности записи
    jl write_error      ; если ошибка
    
    ; УСПЕШНОЕ ЗАВЕРШЕНИЕ ПРОГРАММЫ
    mov rax, 60         ; sys_exit
    mov rdi, 0          ; код возврата 0
    syscall

; ======================== ФУНКЦИЯ ВВОДА ЧИСЛА ========================
; Функция читает и проверяет число, возвращает в num1 или num2
; Вход: RDI - номер числа (1 или 2)
read_number:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    
    mov r12, rdi        ; сохраняем номер числа
    
    ; Определяем какое число вводим (1 или 2)
    cmp r12, 1
    jne .second_number
    
.first_number:
    mov rsi, prompt1
    jmp .print_prompt
    
.second_number:
    mov rsi, prompt2
    
.print_prompt:
    ; ВЫВОД ПРИГЛАШЕНИЯ
    call strlen
    mov rdx, rax        ; длина строки
    mov rax, 1          ; sys_write
    mov rdi, 1          ; stdout
    syscall
    cmp rax, 0          ; проверка успешности записи
    jl .read_error
    
    ; ЧТЕНИЕ ВВОДА
    mov rax, 0          ; sys_read
    mov rdi, 0          ; stdin
    mov rsi, buffer     ; буфер для ввода
    mov rdx, 64         ; максимальная длина
    syscall
    cmp rax, 0          ; проверка успешности чтения
    jl .read_error
    jz .empty_error     ; если ничего не прочитано
    
    ; ПРОВЕРКА ДЛИНЫ ВВОДА
    cmp rax, 64
    jge .too_long_error
    
    ; УДАЛЕНИЕ СИМВОЛА НОВОЙ СТРОКИ
    call remove_newline
    
    ; ПРОВЕРКА НА ПУСТОЙ ВВОД
    call check_empty_string
    test rax, rax
    jnz .empty_error
    
    ; ПРЕОБРАЗОВАНИЕ СТРОКИ В 64-БИТНОЕ ЧИСЛО
    mov rsi, buffer     ; RSI = указатель на строку
    call string_to_int64 ; вызов функции преобразования
    
    ; ПРОВЕРКА РЕЗУЛЬТАТА ПРЕОБРАЗОВАНИЯ
    cmp rax, 0          ; успех?
    je .save_number
    cmp rax, 1          ; ошибка формата?
    je .format_error
    cmp rax, 2          ; ошибка диапазона?
    je .range_error
    
.format_error:
    call format_error_handler
    mov rax, 1
    jmp .done
    
.range_error:
    call range_error_handler
    mov rax, 1
    jmp .done
    
.read_error:
    call read_error_handler
    mov rax, 1
    jmp .done
    
.empty_error:
    call empty_error_handler
    mov rax, 1
    jmp .done
    
.too_long_error:
    ; Ошибка слишком длинного ввода
    mov rax, 1
    jmp .done

.save_number:
    ; Сохраняем число в num1 или num2
    cmp r12, 1
    jne .save_num2
    mov [num1], rbx     ; сохраняем первое число (64 бит)
    jmp .success
    
.save_num2:
    mov [num2], rbx     ; сохраняем второе число (64 бит)
    
.success:
    xor rax, rax        ; успешное завершение
    
.done:
    pop r12
    pop rbx
    pop rbp
    ret

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
    mov rsi, error_overflow
    call strlen
    mov rdx, rax
    mov rax, 1
    mov rdi, 1
    syscall
    jmp error_exit

read_error_handler:
    mov rsi, error_read
    call strlen
    mov rdx, rax
    mov rax, 1
    mov rdi, 1
    syscall
    ret

write_error_handler:
    mov rsi, error_write
    call strlen
    mov rdx, rax
    mov rax, 1
    mov rdi, 1
    syscall
    ret

range_error_handler:
    mov rsi, error_range
    call strlen
    mov rdx, rax
    mov rax, 1
    mov rdi, 1
    syscall
    ret

format_error_handler:
    mov rsi, error_format
    call strlen
    mov rdx, rax
    mov rax, 1
    mov rdi, 1
    syscall
    ret

empty_error_handler:
    mov rsi, error_empty
    call strlen
    mov rdx, rax
    mov rax, 1
    mov rdi, 1
    syscall
    ret

error_exit:
    ; ЗАВЕРШЕНИЕ ПРОГРАММЫ С ОШИБКОЙ
    mov rax, 60         ; sys_exit
    mov rdi, 1          ; код возврата 1 (ошибка)
    syscall

; ======================== ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ ========================

; ФУНКЦИЯ: strlen
; Назначение: Вычисляет длину строки
; Вход: RSI - указатель на строку
; Выход: RAX - длина строки
strlen:
    push rcx
    mov rcx, rsi
    xor rax, rax
.count_loop:
    cmp byte [rcx], 0
    je .done
    inc rax
    inc rcx
    jmp .count_loop
.done:
    pop rcx
    ret

; ФУНКЦИЯ: remove_newline
; Назначение: Удаляет символ новой строки из конца строки в buffer
remove_newline:
    mov rdi, buffer
.search_loop:
    mov al, [rdi]
    cmp al, 0
    je .done
    cmp al, 10
    je .found_newline
    inc rdi
    jmp .search_loop
.found_newline:
    mov byte [rdi], 0
.done:
    ret

; ФУНКЦИЯ: check_empty_string
; Назначение: Проверяет, является ли строка в buffer пустой
check_empty_string:
    mov rdi, buffer
    xor rax, rax
.check_loop:
    mov cl, [rdi]
    test cl, cl
    jz .is_empty
    cmp cl, 32
    je .next_char
    cmp cl, 9
    je .next_char
    jmp .not_empty
.next_char:
    inc rdi
    jmp .check_loop
.is_empty:
    mov rax, 1
.not_empty:
    ret

; ФУНКЦИЯ: string_to_int64
; Назначение: Преобразует строку в 64-битное целое число со знаком
; Вход: RSI - указатель на строку
; Выход: RAX = 0 (успех), RBX = число; RAX = 1 (ошибка формата), RAX = 2 (ошибка диапазона)
string_to_int64:
    push rbp
    mov rbp, rsp
    push rcx
    push rdx
    push r8
    push r9
    push r10
    
    xor rbx, rbx        ; обнуляем результат (будет в RBX)
    xor r8, r8          ; флаг знака (0 = положительное)
    mov rcx, 10         ; основание системы счисления
    
    ; ПРОВЕРКА ПУСТОЙ СТРОКИ
    cmp byte [rsi], 0
    je .format_error
    
    ; ПРОВЕРКА ЗНАКА
    cmp byte [rsi], '-' ; отрицательное число?
    jne .check_plus
    mov r8, 1           ; устанавливаем флаг отрицательного
    inc rsi             ; пропускаем знак '-'
    jmp .after_sign

.check_plus:
    cmp byte [rsi], '+' ; явный плюс?
    jne .after_sign
    inc rsi             ; пропускаем знак '+'

.after_sign:
    ; ПРОВЕРКА НА ОТСУТСТВИЕ ЦИФР ПОСЛЕ ЗНАКА
    cmp byte [rsi], 0
    je .format_error
    
    ; Загружаем константы для проверки диапазона
    mov r9, [max_positive_div10]   ; 922337203685477580
    mov r10, [min_negative_div10]  ; -922337203685477580
    
    ; ОБРАБОТКА ЦИФР
.digit_loop:
    mov dl, [rsi]       ; текущий символ
    cmp dl, 0           ; нуль-терминатор?
    je .end_digits
    
    ; ПРОВЕРКА НА ЦИФРУ
    cmp dl, '0'
    jb .format_error
    cmp dl, '9'
    ja .format_error
    
    sub dl, '0'         ; преобразование символа в цифру
    movzx rdx, dl
    
    ; ПРОВЕРКА ПЕРЕПОЛНЕНИЯ
    test r8, r8
    jnz .negative_check
    
    ; ПРОВЕРКА ДЛЯ ПОЛОЖИТЕЛЬНЫХ ЧИСЕЛ
.positive_check:
    ; Если текущее значение > max_div10, то ошибка
    cmp rbx, r9
    jg .range_error
    jl .positive_ok
    ; Если текущее значение == max_div10, то последняя цифра должна быть <= 7
    cmp rdx, 7
    jg .range_error
    
.positive_ok:
    ; Умножаем текущий результат на 10
    imul rbx, rcx
    ; Добавляем цифру
    add rbx, rdx
    jmp .next_digit

.negative_check:
    ; ПРОВЕРКА ДЛЯ ОТРИЦАТЕЛЬНЫХ ЧИСЕЛ
    ; Отрицательное число - накапливаем положительное значение, затем сделаем отрицательным
    ; Сравниваем с положительным пределом, но проверяем другую логику
    
    ; Для отрицательных чисел мы строим положительное число, а затем инвертируем знак
    ; Проверка: если текущее положительное значение > max_div10, то после инверсии будет < min
    cmp rbx, r9
    jg .range_error
    jl .negative_ok
    ; Если текущее значение == max_div10, то последняя цифра должна быть <= 8 (для -2^63)
    cmp rdx, 8
    jg .range_error
    
.negative_ok:
    ; Умножаем текущий результат на 10
    imul rbx, rcx
    ; Добавляем цифру
    add rbx, rdx
    
.next_digit:
    inc rsi
    jmp .digit_loop

.end_digits:
    ; УЧЕТ ЗНАКА
    test r8, r8
    jz .positive_num
    ; Для отрицательного числа инвертируем знак
    neg rbx

.positive_num:
    ; УСПЕШНОЕ ЗАВЕРШЕНИЕ
    xor rax, rax        ; успех
    jmp .done

.format_error:
    mov rax, 1          ; ошибка формата
    jmp .done

.range_error:
    mov rax, 2          ; ошибка диапазона

.done:
    pop r10
    pop r9
    pop r8
    pop rdx
    pop rcx
    pop rbp
    ret

; ФУНКЦИЯ: int64_to_string
; Назначение: Преобразует 64-битное целое число в строку
; Вход: RAX - число, RDI - буфер для строки
; Выход: RDI содержит строку
int64_to_string:
    push rbp
    mov rbp, rsp
    push rax
    push rbx
    push rcx
    push rdx
    push rdi
    push r12
    
    mov r12, rdi        ; сохраняем начало буфера
    mov rbx, 10         ; основание системы счисления
    xor rcx, rcx        ; счетчик цифр
    
    ; ОБРАБОТКА НУЛЯ
    test rax, rax
    jnz .not_zero
    mov byte [rdi], '0'
    mov byte [rdi+1], 0
    jmp .done
    
.not_zero:
    ; ОБРАБОТКА ЗНАКА
    test rax, rax       ; проверка знака числа
    jns .positive
    neg rax             ; делаем число положительным
    mov byte [rdi], '-' ; добавляем знак минуса
    inc rdi

.positive:
    ; ВЫДЕЛЕНИЕ ЦИФР ИЗ ЧИСЛА
.divide_loop:
    xor rdx, rdx        ; обнуляем RDX для деления
    div rbx             ; RDX:RAX / 10, остаток в RDX
    add dl, '0'         ; преобразуем цифру в символ
    push dx             ; сохраняем цифру в стек
    inc rcx             ; увеличиваем счетчик цифр
    test rax, rax       ; число стало нулем?
    jnz .divide_loop
    
    ; ФОРМИРОВАНИЕ СТРОКИ ИЗ СТЕКА
    mov rdi, r12
    cmp byte [rdi], '-' ; был ли знак минуса?
    jne .pop_loop
    inc rdi             ; пропускаем знак минуса
    
.pop_loop:
    pop ax              ; извлекаем цифру из стека
    mov [rdi], al       ; записываем в буфер
    inc rdi
    loop .pop_loop
    
    mov byte [rdi], 0   ; добавляем нуль-терминатор
    
.done:
    pop r12
    pop rdi
    pop rdx
    pop rcx
    pop rbx
    pop rax
    pop rbp
    ret
