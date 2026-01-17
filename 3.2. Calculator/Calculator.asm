section .data
    ; Сегмент данных - константы и сообщения
    prompt1 db "Enter 1 number: ", 0
    prompt2 db "Enter 2 number: ", 0
    answer db "Answer: ", 0
    newline db 10
    error_read db "Error: Failed to read input", 10, 0
    error_write db "Error: Failed to write output", 10, 0
    error_range db "Error: Number out of range (-32767 to 32767)", 10, 0
    error_format db "Error: Invalid number format", 10, 0
    error_empty db "Error: Empty input is not allowed", 10, 0
    error_overflow db "Error: Arithmetic overflow", 10, 0

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
    mov rdi, 1
    call read_number
    test rax, rax       ; проверка на ошибку
    jnz error_exit
    mov ax, [buffer]    ; загружаем преобразованное число
    mov [num1], ax      ; сохраняем первое число
    
    ; ВВОД ВТОРОГО ЧИСЛА
    mov rdi, 2
    call read_number
    test rax, rax       ; проверка на ошибку
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
    mov rdi, result_str ; буфер для строки
    call int_to_string  ; вызов функции преобразования
    
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
; Функция читает и проверяет число, возвращает в buffer
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
    mov rdx, 32         ; максимальная длина
    syscall
    cmp rax, 0          ; проверка успешности чтения
    jl .read_error
    jz .empty_error     ; если ничего не прочитано
    
    ; ПРОВЕРКА ДЛИНЫ ВВОДА
    cmp rax, 32
    jge .too_long_error
    
    ; УДАЛЕНИЕ СИМВОЛА НОВОЙ СТРОКИ
    call remove_newline
    
    ; ПРОВЕРКА НА ПУСТОЙ ВВОД
    call check_empty_string
    test rax, rax
    jnz .empty_error
    
    ; ПРЕОБРАЗОВАНИЕ СТРОКИ В ЧИСЛО
    mov rsi, buffer     ; RSI = указатель на строку
    call string_to_int  ; вызов функции преобразования
    
    ; ПРОВЕРКА РЕЗУЛЬТАТА ПРЕОБРАЗОВАНИЯ
    cmp rax, 0          ; успех?
    je .success
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

; ФУНКЦИЯ: string_to_int
; Назначение: Преобразует строку в 16-битное целое число со знаком
; Вход: RSI - указатель на строку
; Выход: AX - число, RAX=0 (успех), 1 (ошибка формата), 2 (ошибка диапазона)
string_to_int:
    push rbx
    push rcx
    push rdx
    push rsi
    
    xor rax, rax        ; обнуляем результат
    xor rbx, rbx        ; флаг знака (0 = положительное)
    xor rcx, rcx        ; счетчик цифр
    mov rdx, 10         ; основание системы счисления
    
    ; ПРОВЕРКА ПУСТОЙ СТРОКИ
    cmp byte [rsi], 0
    je .format_error
    
    ; ПРОВЕРКА ЗНАКА
    cmp byte [rsi], '-' ; отрицательное число?
    jne .check_plus
    mov rbx, 1          ; устанавливаем флаг отрицательного
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
    
    ; ОБРАБОТКА ЦИФР
.digit_loop:
    mov cl, [rsi]       ; текущий символ
    cmp cl, 0           ; нуль-терминатор?
    je .end_digits
    
    ; ПРОВЕРКА НА ЦИФРУ
    cmp cl, '0'
    jb .format_error
    cmp cl, '9'
    ja .format_error
    
    sub cl, '0'         ; преобразование символа в цифру
    
    ; ПРОВЕРКА ПЕРЕПОЛНЕНИЯ ПЕРЕД УМНОЖЕНИЕМ
    cmp rax, 3276       ; 32767/10
    ja .range_error
    jb .ok_multiply
    ; если rax == 3276, проверяем последнюю цифру
    test rbx, rbx       ; положительное число?
    jz .check_positive_max
    cmp cl, 8           ; для -32768 максимальная цифра 8
    ja .range_error
    jmp .ok_multiply
    
.check_positive_max:
    cmp cl, 7           ; для 32767 максимальная цифра 7
    ja .range_error
    
.ok_multiply:
    imul rax, rdx       ; умножаем текущий результат на 10
    add rax, rcx        ; добавляем новую цифру
    
    inc rsi
    jmp .digit_loop

.end_digits:
    ; УЧЕТ ЗНАКА
    test rbx, rbx       ; проверка флага знака
    jz .positive_num
    neg rax             ; преобразование в отрицательное

.positive_num:
    ; ПРОВЕРКА ДИАПАЗОНА
    cmp rax, 32767
    jg .range_error
    cmp rax, -32768
    jl .range_error
    
    mov [buffer], ax    ; сохраняем результат
    xor rax, rax        ; успех
    jmp .done

.format_error:
    mov rax, 1          ; ошибка формата
    jmp .done

.range_error:
    mov rax, 2          ; ошибка диапазона

.done:
    pop rsi
    pop rdx
    pop rcx
    pop rbx
    ret

; ФУНКЦИЯ: int_to_string
; Назначение: Преобразует 16-битное целое число в строку
; Вход: AX - число, RDI - буфер для строки
; Выход: RDI содержит строку
int_to_string:
    push rbp
    mov rbp, rsp
    push rax
    push rbx
    push rcx
    push rdx
    push rdi
    
    mov rbx, 10         ; основание системы счисления
    mov rcx, 0          ; счетчик цифр
    
    ; ОБРАБОТКА НУЛЯ
    test ax, ax
    jnz .not_zero
    mov byte [rdi], '0'
    mov byte [rdi+1], 0
    jmp .done
    
.not_zero:
    ; ОБРАБОТКА ЗНАКА
    test ax, ax         ; проверка знака числа
    jns .positive
    neg ax              ; делаем число положительным
    mov byte [rdi], '-' ; добавляем знак минуса
    inc rdi

.positive:
    ; ВЫДЕЛЕНИЕ ЦИФР ИЗ ЧИСЛА
    movsx rax, ax       ; расширяем до 64 бит
.divide_loop:
    xor rdx, rdx        ; обнуляем RDX для деления
    div rbx             ; RDX:RAX / 10, остаток в RDX
    add dl, '0'         ; преобразуем цифру в символ
    push dx             ; сохраняем цифру в стек
    inc rcx             ; увеличиваем счетчик цифр
    test rax, rax       ; число стало нулем?
    jnz .divide_loop
    
    ; ФОРМИРОВАНИЕ СТРОКИ ИЗ СТЕКА
.pop_loop:
    pop ax              ; извлекаем цифру из стека
    mov [rdi], al       ; записываем в буфер
    inc rdi
    loop .pop_loop
    
    mov byte [rdi], 0   ; добавляем нуль-терминатор
    
.done:
    pop rdi
    pop rdx
    pop rcx
    pop rbx
    pop rax
    pop rbp
    ret

; ФУНКЦИЯ: sum
; Назначение: Складывает два 16-битных числа
; Вход: AX - первое число, BX - второе число
; Выход: AX - сумма, флаги установлены для проверки переполнения
sum:
    push rbp
    mov rbp, rsp
    
    add ax, bx          ; сложение чисел
    ; Флаг OF будет установлен при переполнении со знаком
    
    pop rbp
    ret
