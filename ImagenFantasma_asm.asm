extern ImagenFantasma_c
global ImagenFantasma_asm

section .data
%define OFFSET_x 16
%define OFFSET_y 24

transparencia: DD -1, -1, -1, 0
green: DD 0, -1, 0, 0
sumar: DB 0, 0, 0, 255, 0, 0, 0, 255, 0, 0, 0, 255, 0, 0, 0, 255
dividir: DD 8.0, 8.0, 8.0, 8.0
multiplicar: DW 29, 29, 29, 29, 29, 29, 29, 29

section .text
ImagenFantasma_asm:
    push rbp
    mov rbp, rsp

    ; rdi -> *src
    ; rsi -> *dst
    ; edx -> columnas
    ; ecx -> filas
    ; r8d -> src_row_size
    ; r9d -> dst_row_size
    ; [rbp+16] -> OFFSET x  
    ; [rbp+24] -> OFFSET y
    
    ; (1) Preparo índices ii y jj
    mov r8d, r8d  ; limpio parte alta
    mov r10d, edx ; r10d = columnas 
    
    ; offset_y es el desplazamiento en filas -> lo multiplico por row_size
    mov eax, r8d            ; eax = src_row_size
    mov r9d, [rbp+OFFSET_y] ; r9d = offset_y
    mul r9d                 ; eax = offset_y en bytes (parte baja) 
                            ; edx = offset_y en bytes (parte alta)
    ; combino edx con eax                        
    mov eax, eax ; limpio parte alta
    shl rdx, 4   
    mov r9, rax  ; r9 = offset_y en bytes (parte baja)
    add r9, rdx  ; r9 = offset_y en bytes 
    add r9, rdi  ; r9 = rdi + offset_y en bytes = offset_jj
    
    ; offset_x es el desplazamiento en columnas -> lo multiplico por col_size (4)
    mov eax, [rbp+OFFSET_x] ; eax = offset_x
    shl rax, 2              ; eax = offset_x en bytes = offset_ii
  
    ; repongo valor de edx
    mov edx, r10d ; edx = columnas

    ; levanto máscaras de memoria
    movdqu xmm15, [transparencia] 
    movdqu xmm14, [green]
    movdqu xmm10, [dividir]
    movdqu xmm11, [multiplicar]
    movdqu xmm12, [sumar]
    
    ; [ p0  | p1  | p2  | p3  ]
    ; [ p4  | p5  | p6  | p7  ]
    ; [ p8  | p9  | p10 | p11 ]
    ; [ p12 | p13 | p14 | p15 ]
    
    .loopFila:
        cmp ecx, 0 ; contador de fila
        je .fin
        mov r10d, r8d ; reseteo contador de columna
    
            .loopCol:
                cmp r10d, 0        
                je .NextFila
                
                ;(2) Levanto pixel src[jj][ii] extendiendo a dowrd
                pmovzxbd xmm0, [rax + r9] ; xmm0 = [a, r, g, b]   
                ; saco transparencia
                pand xmm0, xmm15        ; xmm0 = [0, r, g, b]

                movdqu xmm13, xmm14     
                ; extraigo green
                pand xmm13, xmm0        ; xmm13 = [0, 0, g, 0] = ggg
                ; duplico green
                paddw xmm0, xmm13       ; 2*src[jj][ii].g
            
                ;(2) Calculo brillo
                phaddd xmm0, xmm0
                phaddd xmm0, xmm0       ; b = (rrr + 2 * ggg + bbb);

                ; convierto a word
                packusdw xmm0, xmm0     ; [ (rrr + 2 * ggg + bbb) | ... | ... | ... | ... | ... | ... | ... ]
                ; divido por 4 y 2 (divido por 8)
                psrlw xmm0, 3       ; [ brillo/2 | ... | ... | ... | ... | ... | ... | ... ]

                ;(3) Levanto pixeles que tendrán igual brillo extendiendo a dword y opero
                pmovzxbw xmm1, [rdi]        ; [ p1 | p0 ]
                pmovzxbw xmm2, [rdi+r8]     ; [ p5 | p4 ]

                ; multiplico por 29 WARNING!!!

                pmullw xmm1, xmm11          ; [ p1*29 | p0*29 ]
                pmullw xmm2, xmm11          ; [ p5*29 | p4*29 ]
                
                ; divido por 32
                
                psrlw xmm1, 5               ; [ (p1*29)/32 | (p0*29)/32 ]
                psrlw xmm2, 5               ; [ (p5*29)/32 | (p4*29)/32 ]

                ; sumo brillo/2
                
                paddusw xmm1, xmm0          ; [ (p1*29)/32 + b/2 | (p0*29)/32 + b/2 ]
                paddusw xmm2, xmm0          ; [ (p5*29)/32 + b/2 | (p4*29)/32 + b/2 ]
                
                ; empaqueto
                
                packuswb xmm1, xmm1          ; [ p1*0.9 + b/2, p0*0.9 + b/2, p1*0.9 + b/2, p0*0.9 + b/2 ]
                packuswb xmm2, xmm2          ; [ p5*0.9 + b/2, p4*0.9 + b/2, p5*0.9 + b/2, p4*0.9 + b/2 ]
                
                ; arreglo transparencia
                
                paddusb xmm1, xmm12
                paddusb xmm2, xmm12

                ;(4) Muevo resultado a dst[j][i]
                movq [rsi], xmm1
                movq [rsi+r8], xmm2

                ;(5) Actualizo direcciones e índices
                add rdi, 8 
                add rsi, 8
                sub r10d, 8
                add rax, 4
                jmp .loopCol

        .NextFila:
            sub ecx, 2
            mov eax, [rbp+OFFSET_x]
            shl rax, 2
            add rdi, r8
            add rsi, r8
            add r9, r8
            jmp .loopFila
    .fin:
    pop rbp
    ret
