extern ImagenFantasma_c
global ImagenFantasma_asm

section .data
%define OFFSET_x 16
%define OFFSET_y 24

transparencia: DD -1, -1, -1, 0
green: DD 0, -1, 0, 0
sumar: DB 0, 0, 0, 255, 0, 0, 0, 255, 0, 0, 0, 255, 0, 0, 0, 255
dividir: DD 8.0, 8.0, 8.0, 8.0
multiplicar: DD 0.9, 0.9, 0.9, 0.9

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

                ; convierto a float
                cvtdq2ps xmm0, xmm0     ; [ (float)brillo | ... | ... | ... ]
                ; divido por 4 y 2 (divido por 8)
                divps xmm0, xmm10       ; [ (float)brillo/2 | ... | ... | ... ]

                ;(3) Levanto pixeles que tendrán igual brillo extendiendo a dword y opero
                pmovzxbd xmm1, [rdi]        ; [p0]
                pmovzxbd xmm2, [rdi+4]      ; [p1]
                pmovzxbd xmm3, [rdi+r8]     ; [p4]
                pmovzxbd xmm4, [rdi+r8+4]   ; [p5]

                ; convierto a float
                cvtdq2ps xmm1, xmm1         ; [(float)p0]
                cvtdq2ps xmm2, xmm2         ; [(float)p1]
                cvtdq2ps xmm3, xmm3         ; [(float)p4]
                cvtdq2ps xmm4, xmm4         ; [(float)p5]

                ; multiplico por 0.9
                mulps xmm1, xmm11           ; [(float)p0*0.9]
                mulps xmm2, xmm11           ; [(float)p1*0.9]
                mulps xmm3, xmm11           ; [(float)p4*0.9]
                mulps xmm4, xmm11           ; [(float)p5*0.9]

                ; sumo brillo/2
                addps xmm1, xmm0            ; [(float)p0*0.9 + b/2]
                addps xmm2, xmm0            ; [(float)p1*0.9 + b/2]
                addps xmm3, xmm0            ; [(float)p4*0.9 + b/2]
                addps xmm4, xmm0            ; [(float)p5*0.9 + b/8]
                
                ; convierto a int truncando
                cvttps2dq xmm1, xmm1         ; [(float)p0*0.9 + b/2] -> int
                cvttps2dq xmm2, xmm2         ; [(float)p1*0.9 + b/2] -> int
                cvttps2dq xmm3, xmm3         ; [(float)p4*0.9 + b/2] -> int
                cvttps2dq xmm4, xmm4         ; [(float)p5*0.9 + b/2] -> int
                ; empaqueto
                packusdw xmm1, xmm2          ; [(int)p0*0.9 + b/2, (int)p1*0.9 + b/2]
                packusdw xmm3, xmm4          ; [(int)p4*0.9 + b/2, (int)p5*0.9 + b/2]

                packuswb xmm1, xmm1          ; [(int)p0*0.9 + b/2,(int)p1*0.9 + b/2,(int)p0*0.9 + b/2,(int)p1*0.9 + b/2]
                packuswb xmm3, xmm4          ; [(int)p4*0.9 + b/2,(int)p5*0.9 + b/2,(int)p4*0.9 + b/2,(int)p5*0.9 + b/2]
                
                ; arreglo transparencia
                paddusb xmm1, xmm12
                paddusb xmm3, xmm12

                ;(4) Muevo resultado a dst[j][i]
                movq [rsi], xmm1
                movq [rsi+r8], xmm3

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
