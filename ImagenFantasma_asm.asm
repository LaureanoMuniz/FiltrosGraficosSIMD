section .data
%define OFFSET_x 16
%define OFFSET_y 24
mascara: DD -1,-1,-1,0
mascara1: DD 0,-1,0,0
dividir: DD 8.0,8.0,8.0,8.0
multiplicar: DD 0.9,0.9,0.9,0.9
sumar: DB 0,0,0,255,0,0,0,255,0,0,0,255,0,0,0,255
extern ImagenFantasma_c
global ImagenFantasma_asm
section .text
ImagenFantasma_asm:
    push rbp
    mov rbp, rsp

    ;rdi -> puntero a src
    ;rsi -> puntero a dst
    ;edx -> ancho
    ;ecx -> altura
    ;r8d -> row_size
    ;r9d -> row_size
    ;[rbp+16] -> OFFSET x Che los levantamos en algun registro para ser mas rapido?
    ;[rbp+24] -> OFFSET y
    mov r8d, r8d ;limpio parte alta
    
    mov r10d, edx
    mov eax, r8d
    mov r9d, [rbp+OFFSET_y]
    mul r9d
    
    mov eax, eax
    shl rdx, 4
    
    mov r9, rax
    add r9, rdx

    add r9, rdi; ii
    
    mov edx, r10d

    mov eax, [rbp+OFFSET_x]
    shl rax, 2
  
    
    movdqu xmm15, [mascara] 
    movdqu xmm14, [mascara1]
    movdqu xmm10, [dividir]
    movdqu xmm11, [multiplicar]
    movdqu xmm12, [sumar]
    ; [ p0  | p1  | p2  | p3  ]
    ; [ p4  | p5  | p6  | p7  ]
    ; [ p8  | p9  | p10 | p11 ]
    ; [ p12 | p13 | p14 | p15 ]
    .loopFila:
        cmp ecx, 0 ;contador fila
        je .fin
        mov r10d, r8d ;contador columna
            .loopCol:
                cmp r10d, 0        
                je .NextFila
                ;Levantar "EL PIXEL"
                pmovzxbd xmm0, [rax+r9]    ; Levanto pixel [jj][ii]
                
                
                pand xmm0, xmm15        ; saco la transparencia
                
                movdqu xmm13, xmm14     ; muevo la mascara
                
                pand xmm13, xmm0        ; extraigo green
            
                paddw xmm0, xmm13       ; 2*[jj][ii].g
            
                ; calculo brillo
                phaddd xmm0, xmm0
                phaddd xmm0, xmm0       ; 2*[jj][ii].g + cosas

                ;conversion a float
                cvtdq2ps xmm0, xmm0     ; [ (float)brillo | ... | ... | ... ]
                divps xmm0, xmm10       ; [ (float)brillo/8 | ... | ... | ... ]

                pmovzxbd xmm1, [rdi]        ; [p0]
                pmovzxbd xmm2, [rdi+4]      ; [p1]
                pmovzxbd xmm3, [rdi+r8]     ; [p4]
                pmovzxbd xmm4, [rdi+r8+4]   ; [p5]

                cvtdq2ps xmm1, xmm1         ; [(float)p0]
                cvtdq2ps xmm2, xmm2         ; [(float)p1]
                cvtdq2ps xmm3, xmm3         ; [(float)p4]
                cvtdq2ps xmm4, xmm4         ; [(float)p5]

                mulps xmm1, xmm11           ; [(float)p0*0.9]
                mulps xmm2, xmm11           ; [(float)p1*0.9]
                mulps xmm3, xmm11           ; [(float)p4*0.9]
                mulps xmm4, xmm11           ; [(float)p5*0.9]

                addps xmm1, xmm0            ; [(float)p0*0.9 + b/8]
                addps xmm2, xmm0            ; [(float)p1*0.9 + b/8]
                addps xmm3, xmm0            ; [(float)p4*0.9 + b/8]
                addps xmm4, xmm0            ; [(float)p5*0.9 + b/8]

                cvttps2dq xmm1, xmm1         ; [(float)p0*0.9 + b/8] -> int
                cvttps2dq xmm2, xmm2         ; [(float)p1*0.9 + b/8] -> int
                cvttps2dq xmm3, xmm3         ; [(float)p4*0.9 + b/8] -> int
                cvttps2dq xmm4, xmm4         ; [(float)p5*0.9 + b/8] -> int

                packusdw xmm1, xmm2         ; [(int)p0*0.9 + b/8,(int)p1*0.9 + b/8]
                packusdw xmm3, xmm4         ; [(int)p4*0.9 + b/8,(int)p5*0.9 + b/8]

                packuswb xmm1, xmm1         ; [(int)p0*0.9 + b/8,(int)p1*0.9 + b/8,(int)p0*0.9 + b/8,(int)p1*0.9 + b/8]
                packuswb xmm3, xmm4         ; [(int)p4*0.9 + b/8,(int)p5*0.9 + b/8,(int)p4*0.9 + b/8,(int)p5*0.9 + b/8]
                ;arreglar transparencia
                paddusb xmm1, xmm12
                paddusb xmm3, xmm12

                movq [rsi], xmm1
                movq [rsi+r8], xmm3

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
