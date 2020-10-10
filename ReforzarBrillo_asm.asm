extern ReforzarBrillo_c
global ReforzarBrillo_asm
transparencia: Dw -1,-1,-1,0,-1,-1,-1,0
verde: DW 0,-1,0,0,0,-1,0,0
fix: DB 0,0,0,-1,0,0,0,-1,0,0,0,-1,0,0,0,-1
ReforzarBrillo_asm:
    push rbp
    mov rbp, rsp
    ;rdi -> *src
    ;rsi -> *dst
    ;edx -> N° columnas
    ;ecx -> N° filas
    ;r8d -> src_row_size
    ;r9d -> dst_row_size
    ;[rbp+16] -> umbralSup
    ;[rbp+24] -> umbralInf
    ;[rbp+32] -> brilloSup
    ;[rbp+40] -> brilloInf 
    movdqu xmm15, [transparencia]
    movdqu xmm14, [verde]
    movd xmm13, [rbp+16] ;umbralSup
    movd xmm12, [rbp+24] ;umbralInf
    movd xmm11, [rbp+32] ;brilloSup
    movd xmm10, [rbp+40] ;brilloInf
    movdqu xmm9, [fix]
   
    ;broadcasting
    pshufd xmm13,xmm13, 0x00    ;[us,us,us,us]
    pshufd xmm12,xmm12, 0x00    ;[ui,ui,ui,ui] 
    pshufd xmm11,xmm11, 0x00    ;[bs,bs,bs,bs]
    pshufd xmm10,xmm10, 0x00    ;[bi,bi,bi,bi]

    ;saturar brillos
    packssdw xmm11, xmm11       ;[bs,bs,bs,bs,bs,bs,bs,bs]
    packssdw xmm10, xmm10       ;[bi,bi,bi,bi,bi,bi,bi,bi]

    mov eax,edx
    .loopFil:
        cmp ecx, 0
        je .fin
        mov eax, edx
        .loopCol:
            cmp eax, 0
            je .finCol
            ;levantar
            pmovzxbw xmm0, [rdi]    ; xmm0 = [a1,r1,g1,b1,a0,r0,g0,b0]
            pmovzxbw xmm1, [rdi+8]  ; xmm1 = [a3,r3,g3,b3,a2,r2,g2,b2]
            ;limpiar transparencia
            pand xmm0, xmm15        ; xmm0 = [0,r1,g1,b1,0,r0,g0,b0]
            pand xmm1, xmm15        ; xmm1 = [0,r3,g3,b3,0,r2,g2,b2]
            movdqu xmm4, xmm0       ; xmm4 = [0,r1,g1,b1,0,r0,g0,b0]
            movdqu xmm5, xmm1       ; xmm5 = [0,r1,g1,b1,0,r0,g0,b0]
            ;extraer verde
            movdqu xmm2, xmm0       ; xmm2 = [0,r1,g1,b1,0,r0,g0,b0] 
            movdqu xmm3, xmm1       ; xmm3 = [0,r3,g3,b3,0,r2,g2,b2]
            pand xmm2, xmm14        ; xmm2 = [0,0,g1,0,0,0,g0,0] 
            pand xmm3, xmm14        ; xmm3 = [0,0,g3,0,0,0,g2,0] 
            paddw xmm0, xmm2        ; xmm0 = [0,r1,2*g1,b1,0,r0,2*g0,b0] 
            paddw xmm1, xmm3        ; xmm1 = [0,r3,2*g3,b3,0,r2,2*g2,b2]
            ;sumas horizontales
            phaddw xmm0, xmm0       ; xmm0 = [r1,2*g1+b1,r0,2*g0+b0,r1,2*g1+b1,r0,2*g0+b0]
            phaddw xmm1, xmm1       ; xmm1 = [r3,2*g3+b3,r2,2*g2+b2,r3,2*g3+b3,r2,2*g2+b2]
            phaddw xmm0, xmm0       ; xmm0 = [brillo_1*4,brillo_0*4,brillo_1*4,brillo_0*4,brillo_1*4,brillo_0*4,brillo_1*4,brillo_0*4] 
            phaddw xmm1, xmm1       ; xmm1 = [x3,brillo_3*4,brillo_2*4] 

            psrlw xmm0, 2
            psrlw xmm1, 2

            pmovzxwd xmm0, xmm0     ; xmm0 = [brillo_1,brillo_0,brillo_1,brillo_0]
            pmovzxwd xmm1, xmm1     ; xmm1 = [brillo_3,brillo_2,brillo_3,brillo_2]
            
            ;cuidado !!
            pshufd xmm0, xmm0, 0x50 ; xmm0 = [brillo_1,brillo_1,brillo_0,brillo_0]
            pshufd xmm1, xmm1, 0x50 ; xmm1 = [brillo_3,brillo_3,brillo_2,brillo_2]
        
            ;primera rama del if
            movdqu xmm6, xmm0       
            movdqu xmm7, xmm1
            pcmpgtd xmm6, xmm13
            pcmpgtd xmm7, xmm13
            pand xmm6, xmm11
            pand xmm7, xmm11
            paddsw xmm4, xmm6
            paddsw xmm5, xmm7
            
            ;segunda rama del if
            movdqu xmm6, xmm12
            movdqu xmm7, xmm12
            pcmpgtd xmm6, xmm0
            pcmpgtd xmm7, xmm1
            pand xmm6, xmm10
            pand xmm7, xmm10
            psubsw xmm4, xmm6
            psubsw xmm5, xmm7

            packuswb xmm4, xmm5
            paddusb xmm4,xmm9
            movdqu [rsi], xmm4
            sub eax,4
            add rdi, 16
            add rsi, 16
            jmp .loopCol
        .finCol:
        dec ecx
        jmp .loopFil
    .fin:
    pop rbp
    ret
