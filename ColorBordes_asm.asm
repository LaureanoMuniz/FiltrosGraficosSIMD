extern ColorBordes_c
global ColorBordes_asm

;void ColorBordes_asm (uint8_t *src, uint8_t *dst, int width, int height, int src_row_size, int dst_row_size);

section .data
blanco: DB 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255
transparencias1: DB 0, 0, 0, 255, 0, 0, 0, 255, 0, 0, 0, 255, 0, 0, 0, 255
transparencias2: DB 255, 255, 255, 0, 255, 255, 255, 0, 255, 255, 255, 0, 255, 255, 255, 0 

section .text

ColorBordes_asm:
    push rbp
    mov rbp, rsp

    ; rdi = *src
    ; rsi = *dst
    ; edx = width  -> columnas
    ; ecx = height -> filas
    ; r8d = src_row_size
    ;(0) Pinto de blanco los bordes de la primer fila de la imagen destino
    
    mov r8d, r8d
    xor r9d, r9d  ; índice 
    mov r11d, edx ; r11d = columnas
    sub r11d, 2   ; r11d = columnas-2
    shr r11d, 1   ; r11d = (columnas-2)/2
    shr edx, 2    ; contador columnas para ciclos de bordes
    mov r10d, edx ; contador columnas para ciclos de bordes
    movdqu xmm15, [blanco] ; xmm15 = [b,b,b,b,b,b,b,b,b,b,b,b,b,b,b,b]
    movdqu xmm14, [transparencias1]
    movdqu xmm13, [transparencias2]

.bordesPrimerFila:
    cmp edx, 0    ;edx queda en 0
    je .preciclo 
    movdqu [rsi + r9*8], xmm15 
    add r9d, 2
    dec edx
    jmp .bordesPrimerFila

.preciclo:
    ; Empiezo desde la fila 1 (por el margen de 1 pixel)
    lea rdi, [rdi + r8 + 4] ;fila 1 columna 1 src
    lea rsi, [rsi + r8]     ;fila 1 columna 0 dst
    sub ecx, 1
    ;[p0, p1,  p2,  p3]
    ;[p4, p5,  p6,  p7]
    ;[p8, p9, p10, p11]

    
.cicloFilas:
    cmp ecx, 1
    mov edx, edx ;limpio edx para bordesUltimaFila
    je .bordesUltimaFila
    ; Pinto de blanco el primer pixel de la fila 
    movd [rsi], xmm15 
    add rsi, 4 ; columna 1  
    mov eax, r11d      ; rax = columnas a recorrer
    
    .cicloColumnas:
        cmp eax, 0
        je .siguienteFila

        ;(1) Levanto extendiendo componentes de byte a word
        neg r8
        pmovzxbw xmm0, [rdi + r8 - 4]  ; xmm0 = [p1, p0]
        pmovzxbw xmm1, [rdi + r8 + 4]  ; xmm1 = [p3, p2]
        pmovzxbw xmm2, [rdi - 4]       ; xmm2 = [p5, p4]
        pmovzxbw xmm3, [rdi + 4]       ; xmm3 = [p7, p6]
        neg r8
        pmovzxbw xmm4, [rdi + r8 - 4]  ; xmm4 = [p9, p8]
        pmovzxbw xmm5, [rdi + r8 + 4]  ; xmm5 = [p11, p10]
        ;registro acumulador del resultado
        pxor xmm6, xmm6

        movdqu xmm7, xmm0  ; xmm7  = [p1, p0]
        movdqu xmm8, xmm1  ; xmm8  = [p3, p2]
        movdqu xmm9, xmm4  ; xmm9  = [p9, p8]
        movdqu xmm10, xmm5 ; xmm10 = [p11, p10]

        ;(2) Obtengo diferencias horizontales
        ;restas
        psubw xmm0, xmm1 ; xmm0 = [p1-p3, p0-p2]
        psubw xmm2, xmm3 ; xmm2 = [p5-p7, p6-p4]
        psubw xmm4, xmm5 ; xmm4 = [p9-p11, p8-p10]
        ;absoluto
        pabsw xmm0, xmm0 ; xmm0 = [abs(p1-p3), abs(p0-p2)]
        pabsw xmm2, xmm2 ; xmm2 = [abs(p5-p7), abs(p6-p4)]
        pabsw xmm4, xmm4 ; xmm4 = [abs(p9-p11), abs(p8-p10)]
        ;Sumo diferencias horizontales al resultado
        paddw xmm6, xmm0 ; xmm6 = [d(1-3), d(0-2)]
        paddw xmm6, xmm2 ; xmm6 = [d(1-3) + d(5-7),d(0-2) + d(4-6)]
        paddw xmm6, xmm4 ; xmm6 = [d(1-3) + d(5-7) + d(9-11), d(0-2) + d(4-6) + d(8-10)]
        
        ;(3) Obtengo diferencias verticales
        ;restas
        psubw xmm7, xmm9  ; xmm7 = [p1-p9, p0-p8] 
        psubw xmm8, xmm10 ; xmm8 = [p3-p11, p2-p10]
        ;absoluto
        pabsw xmm7, xmm7  ; xmm7 = [abs(p1-p9), abs(p0-p8)]
        pabsw xmm8, xmm8  ; xmm8 = [abs(p3-p11), abs(p2-p10)]
        ;Sumo diferencias verticales al resultado
        paddw xmm6, xmm7  ; xmm6 = [res + d(1-9),resh + d(0-8)]
        paddw xmm6, xmm8  ; xmm6 = [res + d(1-9) + d(3-11), res + d(0-8) + d(2-10)]
        ;sumo los que faltan. A p6 le falta 2-10 y a p5 le falta 1-9
        psrldq xmm7, 8    ; xmm7 = [0, abs(p1-p9)]
        pslldq xmm8, 8    ; xmm8 = [abs(p2-p10), 0]
        pxor   xmm7, xmm8 ; xmm7 = [abs(p2-p10), abs(p1-p9)]
        paddw  xmm6, xmm7 ; xmm6 = [resp6, resp5]

        ;(4) Convierto devuelta a byte
        packuswb xmm6, xmm6 ; xmm6 = [resp6, resp5, resp6, resp5]
        
        ;arreglo transparencias
        pand xmm6, xmm13
        por xmm6, xmm14

        ;(5) Muevo resultados a matriz destino
        movq [rsi], xmm6

        ;(6) Actualizo índices
        add rdi, 8
        add rsi, 8
        dec eax
        jmp .cicloColumnas

.siguienteFila:
    add rdi, 8
    ;pinto de blanco el ultimo elemento de la fila
    movd [rsi], xmm15
    add rsi, 4
    dec ecx
    jmp .cicloFilas

;(7) Pinto de blanco la ultima fila.
.bordesUltimaFila:
    cmp r10d, 0
    je .fin
    movdqu [rsi + rdx*8], xmm15 
    add edx, 2
    dec r10d 
    jmp .bordesUltimaFila

.fin:
    pop rbp
    ret
