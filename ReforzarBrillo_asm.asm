extern ReforzarBrillo_c
global ReforzarBrillo_asm
transparencia: DB -1,-1,-1,0,-1,-1,-1,0,-1,-1,-1,0,-1,-1,-1,0
green: DB 0,-1,0,0,0,-1,0,0,0,-1,0,0,0,-1,0,0
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
    movdqu xmm14, [green]
    movdqu xmm9, [fix]
    
    movd xmm13, [rbp+16] ;umbralSup
    movd xmm12, [rbp+24] ;umbralInf
    movd xmm11, [rbp+32] ;brilloSup
    movd xmm10, [rbp+40] ;brilloInf
   
   
    ;broadcasting
    pshufd xmm13,xmm13, 0x00    ;[us,us,us,us]
    pshufd xmm12,xmm12, 0x00    ;[ui,ui,ui,ui] 
    pshufd xmm11,xmm11, 0x00    ;[bs,bs,bs,bs]
    pshufd xmm10,xmm10, 0x00    ;[bi,bi,bi,bi]

    ;saturar brillos
    packusdw xmm11, xmm11       ;[bs,bs,bs,bs,bs,bs,bs,bs]
    packuswb xmm11, xmm11       ;[bs,bs,bs,bs,bs,bs,bs,bs,bs,bs,bs,bs,bs,bs,bs,bs]   
    packusdw xmm10, xmm10       ;[bi,bi,bi,bi,bi,bi,bi,bi]
    packuswb xmm10, xmm10       ;[bi,bi,bi,bi,bi,bi,bi,bi,bi,bi,bi,bi,bi,bi,bi,bi]

    mov eax,edx
    .loopFil:
        cmp ecx, 0
        je .fin
        mov eax, edx
        .loopCol:
            cmp eax, 0
            je .finCol
            ;levantar
            movdqu xmm4, [rdi]    ; xmm4 = [a3,r3,g3,b3,a2,r2,g2,b2,a1,r1,g1,b1,a0,r0,g0,b0]
            ;limpiar transparencia
            pand xmm4, xmm15        ; xmm4 = [0,r3,g3,b3,0,r2,g2,b2,0,r1,g1,b1,0,r0,g0,b0]
            
            
            ;extraer verde
            movdqu xmm2, xmm4       ; xmm2 = [0,r3,g3,b3,0,r2,g2,b2,0,r1,g1,b1,0,r0,g0,b0]
            pand xmm2, xmm14        ; xmm2 = [0,0,g3,0,0,0,g2,0,0,0,g1,0,0,0,g0,0]
            movdqu xmm3, xmm4       ; xmm3 = [0,r3,g3,b3,0,r2,g2,b2,0,r1,g1,b1,0,r0,g0,b0]
            psubusb xmm3, xmm2      ; xmm3 = [0,r3,0,b3,0,r2,0,b2,0,r1,0,b1,0,r0,0,b0]
            psrlw xmm2, 7;          ; xmm2 = [0,2*g3,0,2*g2,0,2*g1,0,2*g0] corrigo la posicion de verde para que quede alineada a word y multiplico por 2.                                
            phaddw xmm3, xmm3       ; xmm3 = [r3+b3,r2+b2,r1+b1,r0+b0,r3+b3,r2+b2,r1+b1,r0+b0]
            pmovzxwd xmm3, xmm3     ; xmm3 = [r3+b3, r2+b2,r1+b1,r0+b0]
            paddd xmm3, xmm2        ; xmm3 = [brillo3*4, brillo2*4, brillo1*4, brillo0*4]
            psrld xmm3, 2           ; xmm3 = [brillo3, brillo2, brillo1, brillo0]
  
    
            ;primera rama del if
            movdqu xmm6, xmm3       ;  xmm6 = [brillo3,brillo2,brillo1,brillo0]
            pcmpgtd xmm6, xmm13     ; comparo los brillos en xmm6 contra el umbral superior. Si un brillo de xmm6 es superior al umbral se guarda en su posicion 0xFFFFFFFF, si no se guardan 0x00000000. 
            pand xmm6, xmm11        ; En las posiciones mayores al umbral coloco 16 brillos superiores a sumar
            paddusb xmm4, xmm6       ; xmm4 = [0+x,r3+x,g3+x,b3+x,0+x,r2+x,g2+x,b2+x,0+x,r1+x,g1+x,b1+x,0+x,r0+x,g0+x,b0+x] x es 0 o bsup dependiendo de si supera el brillo umbral.
           
            ;segunda rama del if
            movdqu xmm6, xmm12      ; xmm6 = [ui,ui,ui,ui]
            pcmpgtd xmm6, xmm3      ; comparo los brillos inferiores contra los brillos en xmm0. Si el umbral inf es superior a un brillo de xmm0 se guarda en su posicion 0xFFFFFFFF, si no se guardan 0x00000000.
            pand xmm6, xmm10        ; En las posiciones donde el brillo es menor al umbral coloco 16 brillos inferiores a restar.
            psubusb xmm4, xmm6       ; xmm4 = [0+x-y,r3+x-y,g3+x-y,b3+x-y,0+x-y,r2+x-y,g2+x-y,b2+x-y,0+x-y,r1+x-y,g1+x-y,b1+x-y,0+x-y,r0+x-y,g0+x-y,b0+x-y] y es 0 o binf dependiendo de si es inferior al brillo umbral inferior.
           

            paddusb xmm4,xmm9       ; arreglo la transparencia saturandola a 255.
            movdqu [rsi], xmm4      ; muevo los 4 pixeles arreglados.
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
