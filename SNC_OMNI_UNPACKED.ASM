; Exact, analysis-oriented disassembly of the unpacked SNC_OMNI.COM runtime.
; Derived from SNC_OMNI.COM by reimplementing its own unpacker.
;
; Instructions are normal NASM where it reproduces the original bytes exactly.
; Ambiguous encodings remain as db bytes with the disassembly in comments.
; Labels/comments are for analysis only.
; Build check: nasm -f bin SNC_OMNI_UNPACKED.ASM -o SNC_OMNI_unpacked_rebuilt.com

bits 16
org 0100h

%macro _reg8_id 2
    %ifidni %2, al
        %assign %1 0
    %elifidni %2, cl
        %assign %1 1
    %elifidni %2, dl
        %assign %1 2
    %elifidni %2, bl
        %assign %1 3
    %elifidni %2, ah
        %assign %1 4
    %elifidni %2, ch
        %assign %1 5
    %elifidni %2, dh
        %assign %1 6
    %elifidni %2, bh
        %assign %1 7
    %else
        %error "unsupported 8-bit register"
    %endif
%endmacro

%macro _reg16_id 2
    %ifidni %2, ax
        %assign %1 0
    %elifidni %2, cx
        %assign %1 1
    %elifidni %2, dx
        %assign %1 2
    %elifidni %2, bx
        %assign %1 3
    %elifidni %2, sp
        %assign %1 4
    %elifidni %2, bp
        %assign %1 5
    %elifidni %2, si
        %assign %1 6
    %elifidni %2, di
        %assign %1 7
    %else
        %error "unsupported 16-bit register"
    %endif
%endmacro

%macro _reg32_id 2
    %ifidni %2, eax
        %assign %1 0
    %elifidni %2, ecx
        %assign %1 1
    %elifidni %2, edx
        %assign %1 2
    %elifidni %2, ebx
        %assign %1 3
    %elifidni %2, esp
        %assign %1 4
    %elifidni %2, ebp
        %assign %1 5
    %elifidni %2, esi
        %assign %1 6
    %elifidni %2, edi
        %assign %1 7
    %else
        %error "unsupported 32-bit register"
    %endif
%endmacro

; Force the opcode direction bit used by the original binary for reg/reg forms
; where NASM's normal mnemonic picks the equivalent opposite encoding.
%macro _op_r_rm8 3
    _reg8_id %%reg, %2
    _reg8_id %%rm, %3
    db %1, 0C0h + (%%reg << 3) + %%rm
%endmacro

%macro _op_r_rm16 3
    _reg16_id %%reg, %2
    _reg16_id %%rm, %3
    db %1, 0C0h + (%%reg << 3) + %%rm
%endmacro

%macro _op_r_rm32 3
    _reg32_id %%reg, %2
    _reg32_id %%rm, %3
    db 066h, %1, 0C0h + (%%reg << 3) + %%rm
%endmacro

%macro xor_r_rm8 2
    _op_r_rm8 032h, %1, %2
%endmacro
%macro mov_r_rm8 2
    _op_r_rm8 08Ah, %1, %2
%endmacro
%macro add_r_rm8 2
    _op_r_rm8 002h, %1, %2
%endmacro
%macro sub_r_rm8 2
    _op_r_rm8 02Ah, %1, %2
%endmacro
%macro cmp_r_rm8 2
    _op_r_rm8 03Ah, %1, %2
%endmacro
%macro or_r_rm8 2
    _op_r_rm8 00Ah, %1, %2
%endmacro

%macro xor_r_rm16 2
    _op_r_rm16 033h, %1, %2
%endmacro
%macro mov_r_rm16 2
    _op_r_rm16 08Bh, %1, %2
%endmacro
%macro add_r_rm16 2
    _op_r_rm16 003h, %1, %2
%endmacro
%macro sub_r_rm16 2
    _op_r_rm16 02Bh, %1, %2
%endmacro
%macro cmp_r_rm16 2
    _op_r_rm16 03Bh, %1, %2
%endmacro
%macro or_r_rm16 2
    _op_r_rm16 00Bh, %1, %2
%endmacro

%macro xor_r_rm32 2
    _op_r_rm32 033h, %1, %2
%endmacro
%macro sub_r_rm32 2
    _op_r_rm32 02Bh, %1, %2
%endmacro


; Unpacked runtime entry point.
intro_start:
    mov ax,cs                              ; 0100: 8C C8
    mov ds,ax                              ; 0102: 8E D8
    mov di,0x4248                          ; 0104: BF 48 42
    add ax,0x1000                          ; 0107: 05 00 10
    stosw                                  ; 010A: AB
    add ax,0x1000                          ; 010B: 05 00 10
    stosw                                  ; 010E: AB
    add ax,0x1000                          ; 010F: 05 00 10
    mov cx,0x14                            ; 0112: B9 14 00
    stosw                                  ; 0115: AB
    inc ah                                 ; 0116: FE C4
    loop 0x115                             ; 0118: E2 FB
    mov di,0x13ae                          ; 011A: BF AE 13
    mov cx,0x1fde                          ; 011D: B9 DE 1F
    xor_r_rm8 al, al                       ; 0120: 32 C0 / xor al,al
    rep stosb                              ; 0122: F3 AA
; Try to reset MPU-401 and enter UART mode.
probe_mpu401:
    mov dx,0x331                           ; 0124: BA 31 03
    mov ax,0xff                            ; 0127: B8 FF 00
    out dx,al                              ; 012A: EE
loc_012B:
    dec ah                                 ; 012B: FE CC
    jz short 0x143                         ; 012D: 74 14
    in al,dx                               ; 012F: EC
    test al,0x80                           ; 0130: A8 80
    jnz short 0x12b                        ; 0132: 75 F7
    dec dx                                 ; 0134: 4A
    in al,dx                               ; 0135: EC
    cmp al,0xfe                            ; 0136: 3C FE
    jnz short 0x143                        ; 0138: 75 09
    inc dx                                 ; 013A: 42
loc_013B:
    in al,dx                               ; 013B: EC
    test al,0x40                           ; 013C: A8 40
    jnz short 0x13b                        ; 013E: 75 FB
    mov al,0x3f                            ; 0140: B0 3F
    out dx,al                              ; 0142: EE
; Expand packed music streams into runtime channel buffers.
build_midi_channels:
    mov si,0xde3                           ; 0143: BE E3 0D
    mov bx,0x1708                          ; 0146: BB 08 17
    mov di,0x3396                          ; 0149: BF 96 33
midi_channel_decode_loop:
    lodsw                                  ; 014C: AD
    dec al                                 ; 014D: FE C8
    js short 0x16b                         ; 014F: 78 1A
    mov [bx+0x2],al                        ; 0151: 88 47 02
    add al,0xc0                            ; 0154: 04 C0
    call 0x6d5                             ; 0156: E8 7C 05
    mov [bx+0x4],di                        ; 0159: 89 7F 04
    call 0x63b                             ; 015C: E8 DC 04
    xor_r_rm8 al, al                       ; 015F: 32 C0 / xor al,al
    stosb                                  ; 0161: AA
    add bx,byte +0x6                       ; 0162: 83 C3 06
    inc word [0x1406]                      ; 0165: FF 06 06 14
    jmp short 0x14c                        ; 0169: EB E1
; Build scene geometry, switch to VGA mode 13h, draw title text, build palette and textures.
init_video_and_palette:
    call 0xc80                             ; 016B: E8 12 0B
    mov ax,0x13                            ; 016E: B8 13 00
    int 0x10                               ; 0171: CD 10
    xchg al,ah                             ; 0173: 86 E0
    mov bx,0x1c                            ; 0175: BB 1C 00
    mov bp,0x1364                          ; 0178: BD 64 13
    mov cx,0x9                             ; 017B: B9 09 00
    mov dx,0x106                           ; 017E: BA 06 01
    int 0x10                               ; 0181: CD 10
    add_r_rm16 bp, cx                      ; 0183: 03 E9 / add bp,cx
    mov cl,0x11                            ; 0185: B1 11
    mov dx,0xc01                           ; 0187: BA 01 0C
    int 0x10                               ; 018A: CD 10
    push ds                                ; 018C: 1E
    pop es                                 ; 018D: 07
    mov bx,0x3                             ; 018E: BB 03 00
palette_component_loop:
    mov si,0xf28                           ; 0191: BE 28 0F
    mov di,0x1408                          ; 0194: BF 08 14
    xor_r_rm8 dh, dh                       ; 0197: 32 F6 / xor dh,dh
    lodsb                                  ; 0199: AC
    movzx cx,al                            ; 019A: 0F B6 C8
palette_ramp_loop:
    push cx                                ; 019D: 51
    mov cl,[si]                            ; 019E: 8A 0C
    mov ah,[bx+si]                         ; 01A0: 8A 20
    sub_r_rm16 ax, dx                      ; 01A2: 2B C2 / sub ax,dx
    push dx                                ; 01A4: 52
    cwd                                    ; 01A5: 99
    idiv cx                                ; 01A6: F7 F9
    pop dx                                 ; 01A8: 5A
palette_interp_store:
    add_r_rm16 dx, ax                      ; 01A9: 03 D0 / add dx,ax
    mov [es:bx+di-0x1],dh                  ; 01AB: 26 88 71 FF
    add di,byte +0x3                       ; 01AF: 83 C7 03
    loop 0x1a9                             ; 01B2: E2 F5
    add si,byte +0x4                       ; 01B4: 83 C6 04
    pop cx                                 ; 01B7: 59
    loop 0x19d                             ; 01B8: E2 E3
    dec bx                                 ; 01BA: 4B
    jnz short 0x191                        ; 01BB: 75 D4
    mov bx,0x22                            ; 01BD: BB 22 00
    push word 0x320                        ; 01C0: 68 20 03
    push byte +0x5                         ; 01C3: 6A 05
    call 0x6e8                             ; 01C5: E8 20 05
    mov bx,0x20                            ; 01C8: BB 20 00
    push byte +0x70                        ; 01CB: 6A 70
    push byte +0xf                         ; 01CD: 6A 0F
    call 0x6e8                             ; 01CF: E8 16 05
generate_texture18_vertical_noise:
    mov es,[0x4270]                        ; 01D2: 8E 06 70 42
    mov al,0x14                            ; 01D6: B0 14
    call 0x6e0                             ; 01D8: E8 05 05
    mov di,0x40                            ; 01DB: BF 40 00
    mov cx,0xfc0                           ; 01DE: B9 C0 0F
texture18_noise_loop:
    mov bx,0x4                             ; 01E1: BB 04 00
    call 0x699                             ; 01E4: E8 B2 04
    add al,[es:di-0x40]                    ; 01E7: 26 02 45 C0
    add al,[es:di-0x3f]                    ; 01EB: 26 02 45 C1
    dec ax                                 ; 01EF: 48
    shr ax,1                               ; 01F0: D1 E8
    stosb                                  ; 01F2: AA
    loop 0x1e1                             ; 01F3: E2 EC
generate_texture19_scatter:
    mov es,[0x4272]                        ; 01F5: 8E 06 72 42
    mov al,0x3                             ; 01F9: B0 03
    call 0x6e0                             ; 01FB: E8 E2 04
    mov cx,0x1000                          ; 01FE: B9 00 10
texture19_noise_loop:
    mov bx,0x1000                          ; 0201: BB 00 10
    call 0x699                             ; 0204: E8 92 04
    mov_r_rm16 di, ax                      ; 0207: 8B F8 / mov di,ax
    inc byte [es:di]                       ; 0209: 26 FE 05
    loop 0x201                             ; 020C: E2 F3
    push ds                                ; 020E: 1E
    pop es                                 ; 020F: 07
; Generate 30 random sparkle positions used by texture 1 and end field.
generate_sparkle_positions:
    mov cx,0x1e                            ; 0210: B9 1E 00
    mov di,0x41ed                          ; 0213: BF ED 41
sparkle_position_loop:
    mov bx,0x100                           ; 0216: BB 00 01
    call 0x699                             ; 0219: E8 7D 04
    stosb                                  ; 021C: AA
    mov bx,0xec0                           ; 021D: BB C0 0E
    add bx,0x80                            ; 0220: 81 C3 80 00
    call 0x699                             ; 0224: E8 72 04
    add ax,strict word 0x40         ; 0227: 05 40 00
    stosw                                  ; 022A: AB
    loop 0x216                             ; 022B: E2 E9
generate_texture0:
    mov es,[0x424c]                        ; 022D: 8E 06 4C 42
    xor_r_rm16 di, di                      ; 0231: 33 FF / xor di,di
    mov cx,0x1000                          ; 0233: B9 00 10
generate_texture0_loop:
    mov_r_rm16 ax, di                      ; 0236: 8B C7 / mov ax,di
    test al,0x8                            ; 0238: A8 08
    jng short 0x23e                        ; 023A: 7E 02
    not al                                 ; 023C: F6 D0
loc_023E:
    and al,0xf                             ; 023E: 24 0F
    mov_r_rm16 bx, ax                      ; 0240: 8B D8 / mov bx,ax
    mov_r_rm16 ax, di                      ; 0242: 8B C7 / mov ax,di
    shr ax,byte 0x6                        ; 0244: C1 E8 06
    test al,0x8                            ; 0247: A8 08
    jng short 0x24d                        ; 0249: 7E 02
    not al                                 ; 024B: F6 D0
loc_024D:
    and al,0xf                             ; 024D: 24 0F
    cmp_r_rm8 al, bl                       ; 024F: 3A C3 / cmp al,bl
    jng short 0x255                        ; 0251: 7E 02
    mov_r_rm16 ax, bx                      ; 0253: 8B C3 / mov ax,bx
loc_0255:
    add al,0xe0                            ; 0255: 04 E0
    stosb                                  ; 0257: AA
    loop 0x236                             ; 0258: E2 DC
derive_textures_from_noise_sources:
    mov si,0x1005                          ; 025A: BE 05 10
    mov dl,0x4                             ; 025D: B2 04
derive_texture_loop:
    movzx bx,dl                            ; 025F: 0F B6 DA
    mov es,[bx+0x424c]                     ; 0262: 8E 87 4C 42
    lodsw                                  ; 0266: AD
    mov_r_rm8 bl, al                       ; 0267: 8A D8 / mov bl,al
    mov fs,[bx+0x424c]                     ; 0269: 8E A7 4C 42
    xor_r_rm16 di, di                      ; 026D: 33 FF / xor di,di
    mov cx,0x1000                          ; 026F: B9 00 10
copy_texture_noise_loop:
    mov al,[fs:di]                         ; 0272: 64 8A 05
    add_r_rm8 al, ah                       ; 0275: 02 C4 / add al,ah
    stosb                                  ; 0277: AA
    loop 0x272                             ; 0278: E2 F8
    inc dx                                 ; 027A: 42
    inc dx                                 ; 027B: 42
    cmp dl,0x1e                            ; 027C: 80 FA 1E
    jng short 0x25f                        ; 027F: 7E DE
apply_texture_rect_recipes:
    mov cx,0x1a                            ; 0281: B9 1A 00
    mov si,0xf69                           ; 0284: BE 69 0F
texture_rect_loop:
    push cx                                ; 0287: 51
    mov bl,[si]                            ; 0288: 8A 1C
    mov_r_rm8 dl, bl                       ; 028A: 8A D3 / mov dl,bl
    shr dl,byte 0x4                        ; 028C: C0 EA 04
    and bx,byte +0xf                       ; 028F: 83 E3 0F
    add_r_rm16 bx, bx                      ; 0292: 03 DB / add bx,bx
    mov es,[bx+0x424c]                     ; 0294: 8E 87 4C 42
    movzx cx,[si+0x2]                      ; 0298: 0F B6 4C 02
texture_rect_y_loop:
    movzx bx,[si+0x1]                      ; 029C: 0F B6 5C 01
texture_rect_x_loop:
    mov_r_rm16 di, cx                      ; 02A0: 8B F9 / mov di,cx
    shl di,byte 0x6                        ; 02A2: C1 E7 06
    add_r_rm16 di, bx                      ; 02A5: 03 FB / add di,bx
    mov_r_rm8 al, dl                       ; 02A7: 8A C2 / mov al,dl
    dec al                                 ; 02A9: FE C8
    jz short 0x2c0                         ; 02AB: 74 13
    dec al                                 ; 02AD: FE C8
    jz short 0x2bd                         ; 02AF: 74 0C
    mov_r_rm16 ax, bx                      ; 02B1: 8B C3 / mov ax,bx
    add_r_rm16 ax, cx                      ; 02B3: 03 C1 / add ax,cx
    and al,0x4                             ; 02B5: 24 04
    jz short 0x2bb                         ; 02B7: 74 02
    mov al,0x98                            ; 02B9: B0 98
loc_02BB:
    jmp short 0x2c0                        ; 02BB: EB 03
texture_rect_copy_old:
    mov al,[es:di]                         ; 02BD: 26 8A 05
texture_rect_store:
    add al,[si+0x5]                        ; 02C0: 02 44 05
    mov [es:di],al                         ; 02C3: 26 88 05
    inc bx                                 ; 02C6: 43
    cmp bl,[si+0x3]                        ; 02C7: 3A 5C 03
    jng short 0x2a0                        ; 02CA: 7E D4
    inc cx                                 ; 02CC: 41
    cmp cl,[si+0x4]                        ; 02CD: 3A 4C 04
    jng short 0x29c                        ; 02D0: 7E CA
    add si,byte +0x6                       ; 02D2: 83 C6 06
    pop cx                                 ; 02D5: 59
    loop 0x287                             ; 02D6: E2 AF
texture11_red_fade_dots:
    mov es,[0x4262]                        ; 02D8: 8E 06 62 42
    mov di,0xfff                           ; 02DC: BF FF 0F
    mov cx,0x14                            ; 02DF: B9 14 00
    mov al,0x5e                            ; 02E2: B0 5E
texture11_red_fade_row:
    push cx                                ; 02E4: 51
    shl cx,byte 0x3                        ; 02E5: C1 E1 03
texture11_red_fade_dot:
    push di                                ; 02E8: 57
    push ax                                ; 02E9: 50
    mov bx,0x40                            ; 02EA: BB 40 00
    call 0x699                             ; 02ED: E8 A9 03
    sub_r_rm16 di, ax                      ; 02F0: 2B F8 / sub di,ax
    pop ax                                 ; 02F2: 58
    stosb                                  ; 02F3: AA
    pop di                                 ; 02F4: 5F
    loop 0x2e8                             ; 02F5: E2 F1
    pop cx                                 ; 02F7: 59
    dec al                                 ; 02F8: FE C8
    sub di,byte +0x40                      ; 02FA: 83 EF 40
    loop 0x2e4                             ; 02FD: E2 E5
; Build 128x256 lighting/fog/color lookup table at 4274h.
build_light_lookup_table:
    push ds                                ; 02FF: 1E
    pop es                                 ; 0300: 07
    mov di,0x4274                          ; 0301: BF 74 42
    xor_r_rm8 bl, bl                       ; 0304: 32 DB / xor bl,bl
loc_0306:
    inc bl                                 ; 0306: FE C3
    xor_r_rm16 cx, cx                      ; 0308: 33 C9 / xor cx,cx
loc_030A:
    mov_r_rm8 al, cl                       ; 030A: 8A C1 / mov al,cl
    and al,0x1f                            ; 030C: 24 1F
    mul bl                                 ; 030E: F6 E3
    add_r_rm16 ax, ax                      ; 0310: 03 C0 / add ax,ax
    mov_r_rm8 al, cl                       ; 0312: 8A C1 / mov al,cl
    and al,0xe0                            ; 0314: 24 E0
    add_r_rm8 al, ah                       ; 0316: 02 C4 / add al,ah
    stosb                                  ; 0318: AA
    inc cl                                 ; 0319: FE C1
    cmp cl,0xc0                            ; 031B: 80 F9 C0
    jnz short 0x30a                        ; 031E: 75 EA
loc_0320:
    mov_r_rm8 al, cl                       ; 0320: 8A C1 / mov al,cl
    stosb                                  ; 0322: AA
    inc cl                                 ; 0323: FE C1
    jnz short 0x320                        ; 0325: 75 F9
    cmp bl,0x80                            ; 0327: 80 FB 80
    jnz short 0x306                        ; 032A: 75 DA
; Save old IRQ vectors, install timer/keyboard handlers, seed backbuffer.
install_interrupts:
    mov [0x338c],sp                        ; 032C: 89 26 8C 33
    mov ax,0x3508                          ; 0330: B8 08 35
    int 0x21                               ; 0333: CD 21
    mov [0x3390],es                        ; 0335: 8C 06 90 33
    mov [0x338e],bx                        ; 0339: 89 1E 8E 33
    mov ax,0x2508                          ; 033D: B8 08 25
    mov dx,0x563                           ; 0340: BA 63 05
    int 0x21                               ; 0343: CD 21
    mov bx,0xd51                           ; 0345: BB 51 0D
    call 0x6ac                             ; 0348: E8 61 03
    mov ax,0x3509                          ; 034B: B8 09 35
    int 0x21                               ; 034E: CD 21
    mov [0x3394],es                        ; 0350: 8C 06 94 33
    mov [0x3392],bx                        ; 0354: 89 1E 92 33
    mov ax,0x2509                          ; 0358: B8 09 25
    mov dx,0x602                           ; 035B: BA 02 06
    int 0x21                               ; 035E: CD 21
    push ds                                ; 0360: 1E
    mov es,[0x424a]                        ; 0361: 8E 06 4A 42
    push word 0xa000                       ; 0365: 68 00 A0
    pop ds                                 ; 0368: 1F
    mov si,0x640                           ; 0369: BE 40 06
    xor_r_rm16 di, di                      ; 036C: 33 FF / xor di,di
    mov cx,0x7d00                          ; 036E: B9 00 7D
    lodsb                                  ; 0371: AC
    stosb                                  ; 0372: AA
    stosb                                  ; 0373: AA
    loop 0x371                             ; 0374: E2 FB
    pop ds                                 ; 0376: 1F
; Upload palette, consume timer ticks, animate, transform, sort, render, blit.
main_frame_loop:
    xor_r_rm8 al, al                       ; 0377: 32 C0 / xor al,al
    mov dx,0x3c8                           ; 0379: BA C8 03
    out dx,al                              ; 037C: EE
    inc dx                                 ; 037D: 42
    mov si,0x1408                          ; 037E: BE 08 14
    mov cx,0x300                           ; 0381: B9 00 03
    rep outsb                              ; 0384: F3 6E
    mov cx,[0x1404]                        ; 0386: 8B 0E 04 14
    mov word [0x1404],0x0                  ; 038A: C7 06 04 14 00 00
    or_r_rm16 cx, cx                       ; 0390: 0B C9 / or cx,cx
    jz near 0x41d                          ; 0392: 0F 84 87 00
process_ticks_loop:
    push cx                                ; 0396: 51
    mov si,0x13f6                          ; 0397: BE F6 13
    dec word [si+0xa]                      ; 039A: FF 4C 0A
    jns short 0x3c7                        ; 039D: 79 28
    mov bx,[si+0x8]                        ; 039F: 8B 5C 08
    mov al,[bx+0x12e3]                     ; 03A2: 8A 87 E3 12
    or_r_rm8 al, al                        ; 03A6: 0A C0 / or al,al
    jz near 0x526                          ; 03A8: 0F 84 7A 01
    mov_r_rm16 bx, ax                      ; 03AC: 8B D8 / mov bx,ax
    and bl,0x7                             ; 03AE: 80 E3 07
    mov [si+0xc],bl                        ; 03B1: 88 5C 0C
    dec bl                                 ; 03B4: FE CB
    jnz short 0x3bc                        ; 03B6: 75 04
    neg word [0x1360]                      ; 03B8: F7 1E 60 13
loc_03BC:
    and ax,0xf8                            ; 03BC: 25 F8 00
    add_r_rm16 ax, ax                      ; 03BF: 03 C0 / add ax,ax
    mov [si+0xa],ax                        ; 03C1: 89 44 0A
    inc word [si+0x8]                      ; 03C4: FF 44 08
apply_scene_command:
    mov al,[si+0xc]                        ; 03C7: 8A 44 0C
    cbw                                    ; 03CA: 98
    dec ax                                 ; 03CB: 48
    jnz short 0x3d5                        ; 03CC: 75 07
    mov bx,[0x1360]                        ; 03CE: 8B 1E 60 13
    add [si+0x6],bx                        ; 03D2: 01 5C 06
loc_03D5:
    mov cx,0x3                             ; 03D5: B9 03 00
    dec ax                                 ; 03D8: 48
    jnz short 0x3dd                        ; 03D9: 75 02
    inc word [si]                          ; 03DB: FF 04
loc_03DD:
    dec ax                                 ; 03DD: 48
    jnz short 0x3e2                        ; 03DE: 75 02
    dec word [si]                          ; 03E0: FF 0C
loc_03E2:
    inc si                                 ; 03E2: 46
    inc si                                 ; 03E3: 46
    loop 0x3d8                             ; 03E4: E2 F2
update_camera_position:
    mov si,0x13f8                          ; 03E6: BE F8 13
    mov cl,0x3                             ; 03E9: B1 03
    lodsw                                  ; 03EB: AD
    sar ax,byte 0x2                        ; 03EC: C1 F8 02
    push ax                                ; 03EF: 50
    loop 0x3eb                             ; 03F0: E2 F9
    imul ax,[si-0x4],byte +0x10            ; 03F2: 6B 44 FC 10
    push ax                                ; 03F6: 50
    call 0xbfc                             ; 03F7: E8 02 08
    mov cl,0x3                             ; 03FA: B1 03
    xor_r_rm16 si, si                      ; 03FC: 33 F6 / xor si,si
    fld dword [si+0x13a2]                  ; 03FE: D9 84 A2 13
    fimul word [0x13f6]                    ; 0402: DE 0E F6 13
    fidiv word [0xdd5]                     ; 0406: DE 36 D5 0D
    fadd dword [si+0x137e]                 ; 040A: D8 84 7E 13
    fstp dword [si+0x137e]                 ; 040E: D9 9C 7E 13
    add si,byte +0x4                       ; 0412: 83 C6 04
    loop 0x3fe                             ; 0415: E2 E7
    pop cx                                 ; 0417: 59
    dec cx                                 ; 0418: 49
    jnz near 0x396                         ; 0419: 0F 85 79 FF
; Door/opening animation and once-only sparkle burst into source buffer.
animate_door_texture:
    mov ax,[0x1362]                        ; 041D: A1 62 13
    or_r_rm16 ax, ax                       ; 0420: 0B C0 / or ax,ax
    jns short 0x428                        ; 0422: 79 04
    xor_r_rm16 ax, ax                      ; 0424: 33 C0 / xor ax,ax
    jmp short 0x457                        ; 0426: EB 2F
door_spark_once:
    cmp byte [0x1403],0x0                  ; 0428: 80 3E 03 14 00
    jnz short 0x457                        ; 042D: 75 28
    inc byte [0x1403]                      ; 042F: FE 06 03 14
    push ax                                ; 0433: 50
    mov es,[0x424a]                        ; 0434: 8E 06 4A 42
    mov cx,0x64                            ; 0438: B9 64 00
    push cx                                ; 043B: 51
    mov bx,0xc1c0                          ; 043C: BB C0 C1
    call 0x699                             ; 043F: E8 57 02
    add ax,0x1900                          ; 0442: 05 00 19
    mov_r_rm16 di, ax                      ; 0445: 8B F8 / mov di,ax
    and ah,0x7                             ; 0447: 80 E4 07
    mov dx,0x13b                           ; 044A: BA 3B 01
    mov cx,0x2                             ; 044D: B9 02 00
    call 0x611                             ; 0450: E8 BE 01
    pop cx                                 ; 0453: 59
    loop 0x43b                             ; 0454: E2 E5
    pop ax                                 ; 0456: 58
clamp_door_frame:
    cmp ax,strict word 0x18         ; 0457: 3D 18 00
    jng short 0x45f                        ; 045A: 7E 03
    mov ax,0x18                            ; 045C: B8 18 00
loc_045F:
    shl ax,byte 0x6                        ; 045F: C1 E0 06
    push ds                                ; 0462: 1E
    mov es,[0x4266]                        ; 0463: 8E 06 66 42
    mov ds,[0x426a]                        ; 0467: 8E 1E 6A 42
    mov_r_rm16 si, ax                      ; 046B: 8B F0 / mov si,ax
    xor_r_rm16 di, di                      ; 046D: 33 FF / xor di,di
    mov cx,0x400                           ; 046F: B9 00 04
    rep movsw                              ; 0472: F3 A5
    mov si,0x800                           ; 0474: BE 00 08
    sub_r_rm16 si, ax                      ; 0477: 2B F0 / sub si,ax
    push si                                ; 0479: 56
    mov ch,0x4                             ; 047A: B5 04
    rep movsw                              ; 047C: F3 A5
    pop di                                 ; 047E: 5F
    mov_r_rm16 cx, ax                      ; 047F: 8B C8 / mov cx,ax
    xor_r_rm16 ax, ax                      ; 0481: 33 C0 / xor ax,ax
    rep stosw                              ; 0483: F3 AB
    pop ds                                 ; 0485: 1F
copy_backbuffer_to_texture_source:
    push ds                                ; 0486: 1E
    mov es,[0x4248]                        ; 0487: 8E 06 48 42
    mov ds,[0x424a]                        ; 048B: 8E 1E 4A 42
    call 0x630                             ; 048F: E8 9E 01
    pop ds                                 ; 0492: 1F
transform_vertices_and_render:
    mov cx,[0x1768]                        ; 0493: 8B 0E 68 17
    mov si,0x176c                          ; 0497: BE 6C 17
    mov di,0xc454                          ; 049A: BF 54 C4
    mov bx,0x13ae                          ; 049D: BB AE 13
    mov dx,0x3                             ; 04A0: BA 03 00
loc_04A3:
    fild word [si]                         ; 04A3: DF 04
    fsub dword [0x137e]                    ; 04A5: D8 26 7E 13
    fmul dword [bx]                        ; 04A9: D8 0F
    fild word [si+0x2]                     ; 04AB: DF 44 02
    fsub dword [0x1382]                    ; 04AE: D8 26 82 13
    fmul dword [bx+0x4]                    ; 04B2: D8 4F 04
    fild word [si+0x4]                     ; 04B5: DF 44 04
    fsub dword [0x1386]                    ; 04B8: D8 26 86 13
    fmul dword [bx+0x8]                    ; 04BC: D8 4F 08
    faddp st1                              ; 04BF: DE C1
    faddp st1                              ; 04C1: DE C1
    fstp dword [di]                        ; 04C3: D9 1D
    add di,byte +0x4                       ; 04C5: 83 C7 04
    add bx,byte +0xc                       ; 04C8: 83 C3 0C
    dec dx                                 ; 04CB: 4A
    jnz short 0x4a3                        ; 04CC: 75 D5
    add si,byte +0x8                       ; 04CE: 83 C6 08
    loop 0x49d                             ; 04D1: E2 CA
; Compute face depth keys and sort face records for painter-style rendering.
sort_faces_by_depth:
    push ds                                ; 04D3: 1E
    pop es                                 ; 04D4: 07
    mov di,0xd714                          ; 04D5: BF 14 D7
    push di                                ; 04D8: 57
    mov si,0x23ec                          ; 04D9: BE EC 23
    mov_r_rm16 ax, si                      ; 04DC: 8B C6 / mov ax,si
    mov cx,[0x176a]                        ; 04DE: 8B 0E 6A 17
face_depth_loop:
    fldz                                   ; 04E2: D9 EE
    push cx                                ; 04E4: 51
    mov cx,0x4                             ; 04E5: B9 04 00
face_depth_vertex_loop:
    imul bx,[si],byte +0xc                 ; 04E8: 6B 1C 0C
    inc si                                 ; 04EB: 46
    inc si                                 ; 04EC: 46
    fsub dword [bx-0x3ba4]                 ; 04ED: D8 A7 5C C4
    loop 0x4e8                             ; 04F1: E2 F5
    pop cx                                 ; 04F3: 59
    fistp word [di]                        ; 04F4: DF 1D
    inc di                                 ; 04F6: 47
    inc di                                 ; 04F7: 47
    stosw                                  ; 04F8: AB
    add ax,strict word 0xa          ; 04F9: 05 0A 00
    inc si                                 ; 04FC: 46
    inc si                                 ; 04FD: 46
    loop 0x4e2                             ; 04FE: E2 E2
render_sorted_faces:
    push di                                ; 0500: 57
    call 0x65a                             ; 0501: E8 56 01
    mov cx,[0x176a]                        ; 0504: 8B 0E 6A 17
    mov si,0xd714                          ; 0508: BE 14 D7
render_face_loop:
    lodsw                                  ; 050B: AD
    lodsw                                  ; 050C: AD
    mov_r_rm16 bx, ax                      ; 050D: 8B D8 / mov bx,ax
    pusha                                  ; 050F: 60
    call 0xa09                             ; 0510: E8 F6 04
    popa                                   ; 0513: 61
    loop 0x50b                             ; 0514: E2 F5
    push ds                                ; 0516: 1E
    push word 0xa000                       ; 0517: 68 00 A0
    pop es                                 ; 051A: 07
    mov ds,[0x4248]                        ; 051B: 8E 1E 48 42
    call 0x630                             ; 051F: E8 0E 01
    pop ds                                 ; 0522: 1F
    jmp 0x377                              ; 0523: E9 51 FE
; Restore interrupts, video mode, MIDI notes, and return to DOS.
shutdown_and_exit:
    push cs                                ; 0526: 0E
    pop ds                                 ; 0527: 1F
    mov sp,[0x338c]                        ; 0528: 8B 26 8C 33
    mov cx,0xf                             ; 052C: B9 0F 00
    mov_r_rm16 ax, cx                      ; 052F: 8B C1 / mov ax,cx
    add al,0xb0                            ; 0531: 04 B0
    call 0x6b9                             ; 0533: E8 83 01
    mov al,0x7b                            ; 0536: B0 7B
    call 0x6b9                             ; 0538: E8 7E 01
    xor_r_rm8 al, al                       ; 053B: 32 C0 / xor al,al
    call 0x6b9                             ; 053D: E8 79 01
    loop 0x52f                             ; 0540: E2 ED
    push ds                                ; 0542: 1E
    mov ax,0x2509                          ; 0543: B8 09 25
    lds dx,[0x3392]                        ; 0546: C5 16 92 33
    int 0x21                               ; 054A: CD 21
    pop ds                                 ; 054C: 1F
    push ds                                ; 054D: 1E
    xor_r_rm16 bx, bx                      ; 054E: 33 DB / xor bx,bx
    call 0x6ac                             ; 0550: E8 59 01
    mov ax,0x2508                          ; 0553: B8 08 25
    lds dx,[0x338e]                        ; 0556: C5 16 8E 33
    int 0x21                               ; 055A: CD 21
    pop ds                                 ; 055C: 1F
    mov ax,0x3                             ; 055D: B8 03 00
    int 0x10                               ; 0560: CD 10
    ret                                    ; 0562: C3
; IRQ0 timer: drive MIDI sequencer, animation counters, texture sparkle updates.
irq0_timer_handler:
    pusha                                  ; 0563: 60
    push ds                                ; 0564: 1E
    push es                                ; 0565: 06
    push cs                                ; 0566: 0E
    pop ds                                 ; 0567: 1F
    mov cx,[0x1406]                        ; 0568: 8B 0E 06 14
    mov si,0x1708                          ; 056C: BE 08 17
irq0_midi_channel_loop:
    dec word [si]                          ; 056F: FF 0C
    jg short 0x59f                         ; 0571: 7F 2C
    mov ax,[si+0x2]                        ; 0573: 8B 44 02
    add al,0x80                            ; 0576: 04 80
    call 0x6cc                             ; 0578: E8 51 01
    mov bx,[si+0x4]                        ; 057B: 8B 5C 04
    mov ah,0x7f                            ; 057E: B4 7F
    cmp byte [bx],0x0                      ; 0580: 80 3F 00
    jz short 0x599                         ; 0583: 74 14
    mov ah,[bx]                            ; 0585: 8A 27
    mov [si+0x3],ah                        ; 0587: 88 64 03
    mov al,[si+0x2]                        ; 058A: 8A 44 02
    add al,0x90                            ; 058D: 04 90
    call 0x6cc                             ; 058F: E8 3A 01
    mov al,[bx+0x1]                        ; 0592: 8A 47 01
    mov bl,0x1d                            ; 0595: B3 1D
    mul bl                                 ; 0597: F6 E3
irq0_channel_done:
    mov [si],ax                            ; 0599: 89 04
    add word [si+0x4],byte +0x2            ; 059B: 83 44 04 02
loc_059F:
    add si,byte +0x6                       ; 059F: 83 C6 06
    loop 0x56f                             ; 05A2: E2 CB
irq0_update_animation_counters:
    inc word [0x1404]                      ; 05A4: FF 06 04 14
    inc byte [0x4247]                      ; 05A8: FE 06 47 42
    and byte [0x4247],0x7                  ; 05AC: 80 26 47 42 07
    jnz short 0x5fa                        ; 05B1: 75 47
irq0_update_texture1_sparkles:
    push ds                                ; 05B3: 1E
    pop es                                 ; 05B4: 07
    mov di,0x1648                          ; 05B5: BF 48 16
    mov_r_rm16 si, di                      ; 05B8: 8B F7 / mov si,di
    lodsw                                  ; 05BA: AD
    inc si                                 ; 05BB: 46
    mov cx,0x5d                            ; 05BC: B9 5D 00
    rep movsb                              ; 05BF: F3 A4
    stosw                                  ; 05C1: AB
    mov es,[0x424e]                        ; 05C2: 8E 06 4E 42
    call 0x6de                             ; 05C6: E8 15 01
    mov cl,0x1e                            ; 05C9: B1 1E
    mov bx,0x41ed                          ; 05CB: BB ED 41
irq0_sparkle_loop:
    dec byte [bx]                          ; 05CE: FE 0F
    mov ah,[bx]                            ; 05D0: 8A 27
    and ah,0x3f                            ; 05D2: 80 E4 3F
    cmp ah,0x1f                            ; 05D5: 80 FC 1F
    jna short 0x5df                        ; 05D8: 76 05
    not ah                                 ; 05DA: F6 D4
    and ah,0x1f                            ; 05DC: 80 E4 1F
loc_05DF:
    shr ah,1                               ; 05DF: D0 EC
    mov di,[bx+0x1]                        ; 05E1: 8B 7F 01
    push cx                                ; 05E4: 51
    push bx                                ; 05E5: 53
    mov dx,0x3b                            ; 05E6: BA 3B 00
    mov cx,0xe000                          ; 05E9: B9 00 E0
    call 0x611                             ; 05EC: E8 22 00
    pop bx                                 ; 05EF: 5B
    pop cx                                 ; 05F0: 59
    add bx,byte +0x3                       ; 05F1: 83 C3 03
    loop 0x5ce                             ; 05F4: E2 D8
    inc word [0x1362]                      ; 05F6: FF 06 62 13
irq0_ack:
    mov al,0x20                            ; 05FA: B0 20
    out 0x20,al                            ; 05FC: E6 20
    pop es                                 ; 05FE: 07
    pop ds                                 ; 05FF: 1F
    popa                                   ; 0600: 61
    iret                                   ; 0601: CF
; IRQ1 keyboard handler: Esc exits by jumping into shutdown.
irq1_keyboard_handler:
    push ax                                ; 0602: 50
    mov al,0x20                            ; 0603: B0 20
    out 0x20,al                            ; 0605: E6 20
    in al,0x60                             ; 0607: E4 60
    dec al                                 ; 0609: FE C8
    pop ax                                 ; 060B: 58
    jz near 0x526                          ; 060C: 0F 84 16 FF
    iret                                   ; 0610: CF
; Draw reusable 5x5 brightness sprite, used for sparkles/stars.
draw_5x5_sprite:
    mov si,0x1021                          ; 0611: BE 21 10
    mov bl,0x5                             ; 0614: B3 05
draw_5x5_row:
    mov bh,0x5                             ; 0616: B7 05
draw_5x5_pixel_loop:
    lodsb                                  ; 0618: AC
    sub_r_rm8 al, ah                       ; 0619: 2A C4 / sub al,ah
    jng short 0x624                        ; 061B: 7E 07
    add_r_rm8 al, ch                       ; 061D: 02 C5 / add al,ch
    shl al,cl                              ; 061F: D2 E0
    mov [es:di],al                         ; 0621: 26 88 05
draw_5x5_next_pixel:
    inc di                                 ; 0624: 47
    dec bh                                 ; 0625: FE CF
    jnz short 0x618                        ; 0627: 75 EF
    add_r_rm16 di, dx                      ; 0629: 03 FA / add di,dx
    dec bl                                 ; 062B: FE CB
    jnz short 0x616                        ; 062D: 75 E7
    ret                                    ; 062F: C3
copy_64000_bytes:
    xor_r_rm16 di, di                      ; 0630: 33 FF / xor di,di
    xor_r_rm16 si, si                      ; 0632: 33 F6 / xor si,si
    mov cx,0x3e80                          ; 0634: B9 80 3E
    rep movsd                              ; 0637: F3 66 A5
    ret                                    ; 063A: C3
; Small recursive stream expander used for MIDI/asset data.
decode_rle_or_script:
    mov cl,[si]                            ; 063B: 8A 0C
    or_r_rm8 cl, cl                        ; 063D: 0A C9 / or cl,cl
    jz short 0x656                         ; 063F: 74 15
    jns short 0x653                        ; 0641: 79 10
decode_nested_repeat:
    push cx                                ; 0643: 51
    push si                                ; 0644: 56
    inc si                                 ; 0645: 46
    call 0x63b                             ; 0646: E8 F2 FF
    pop si                                 ; 0649: 5E
    pop cx                                 ; 064A: 59
    inc cl                                 ; 064B: FE C1
    jnz short 0x643                        ; 064D: 75 F4
    mov_r_rm16 si, ax                      ; 064F: 8B F0 / mov si,ax
    jmp short 0x63b                        ; 0651: EB E8
decode_copy_word:
    movsw                                  ; 0653: A5
    jmp short 0x63b                        ; 0654: EB E5
decode_end_block:
    inc si                                 ; 0656: 46
    mov_r_rm16 ax, si                      ; 0657: 8B C6 / mov ax,si
    ret                                    ; 0659: C3
; In-place quicksort of 4-byte face records by depth key.
quicksort_faces:
    pop ax                                 ; 065A: 58
    pop cx                                 ; 065B: 59
    pop bx                                 ; 065C: 5B
    push ax                                ; 065D: 50
    cmp_r_rm16 cx, bx                      ; 065E: 3B CB / cmp cx,bx
    jng short 0x698                        ; 0660: 7E 36
    mov_r_rm16 si, bx                      ; 0662: 8B F3 / mov si,bx
    mov_r_rm16 di, cx                      ; 0664: 8B F9 / mov di,cx
    mov dx,[si]                            ; 0666: 8B 14
qsort_scan_left:
    cmp [si],dx                            ; 0668: 39 14
    jng short 0x671                        ; 066A: 7E 05
    add si,byte +0x4                       ; 066C: 83 C6 04
    jmp short 0x668                        ; 066F: EB F7
qsort_scan_right:
    cmp [di],dx                            ; 0671: 39 15
    jnl short 0x67a                        ; 0673: 7D 05
    sub di,byte +0x4                       ; 0675: 83 EF 04
    jmp short 0x671                        ; 0678: EB F7
qsort_maybe_swap:
    cmp_r_rm16 si, di                      ; 067A: 3B F7 / cmp si,di
    jg short 0x68a                         ; 067C: 7F 0C
    lodsd                                  ; 067E: 66 AD
    xchg [di],eax                          ; 0680: 66 87 05
    mov [si-0x4],eax                       ; 0683: 66 89 44 FC
    sub di,byte +0x4                       ; 0687: 83 EF 04
qsort_partition_done:
    cmp_r_rm16 si, di                      ; 068A: 3B F7 / cmp si,di
    jng short 0x668                        ; 068C: 7E DA
    push si                                ; 068E: 56
    push cx                                ; 068F: 51
    push bx                                ; 0690: 53
    push di                                ; 0691: 57
    call 0x65a                             ; 0692: E8 C5 FF
    call 0x65a                             ; 0695: E8 C2 FF
loc_0698:
    ret                                    ; 0698: C3
; LCG random generator, returns AX in range 0..BX-1.
random_bounded:
    mov si,0xddb                           ; 0699: BE DB 0D
    lodsd                                  ; 069C: 66 AD
    mul dword [si]                         ; 069E: 66 F7 24
    inc eax                                ; 06A1: 66 40
    mov [si],eax                           ; 06A3: 66 89 04
    lodsw                                  ; 06A6: AD
    lodsw                                  ; 06A7: AD
    mul bx                                 ; 06A8: F7 E3
    xchg ax,dx                             ; 06AA: 92
    ret                                    ; 06AB: C3
program_pit:
    mov al,0x36                            ; 06AC: B0 36
    out 0x43,al                            ; 06AE: E6 43
    mov_r_rm8 al, bl                       ; 06B0: 8A C3 / mov al,bl
    out 0x40,al                            ; 06B2: E6 40
    mov_r_rm8 al, bh                       ; 06B4: 8A C7 / mov al,bh
    out 0x40,al                            ; 06B6: E6 40
    ret                                    ; 06B8: C3
mpu_send_byte:
    mov dx,0x331                           ; 06B9: BA 31 03
    push ax                                ; 06BC: 50
    xor_r_rm16 ax, ax                      ; 06BD: 33 C0 / xor ax,ax
loc_06BF:
    dec ah                                 ; 06BF: FE CC
    jz short 0x6c8                         ; 06C1: 74 05
    in al,dx                               ; 06C3: EC
    test al,0x40                           ; 06C4: A8 40
    jnz short 0x6bf                        ; 06C6: 75 F7
loc_06C8:
    pop ax                                 ; 06C8: 58
    dec dx                                 ; 06C9: 4A
    out dx,al                              ; 06CA: EE
    ret                                    ; 06CB: C3
midi_note_off:
    call 0x6d5                             ; 06CC: E8 06 00
    mov al,0x7f                            ; 06CF: B0 7F
    call 0x6b9                             ; 06D1: E8 E5 FF
    ret                                    ; 06D4: C3
midi_send_word:
    call 0x6b9                             ; 06D5: E8 E1 FF
    mov_r_rm8 al, ah                       ; 06D8: 8A C4 / mov al,ah
    call 0x6b9                             ; 06DA: E8 DC FF
    ret                                    ; 06DD: C3
clear_texture_zero_ax:
    xor_r_rm16 ax, ax                      ; 06DE: 33 C0 / xor ax,ax
clear_texture:
    xor_r_rm16 di, di                      ; 06E0: 33 FF / xor di,di
    mov cx,0x1000                          ; 06E2: B9 00 10
    rep stosb                              ; 06E5: F3 AA
    ret                                    ; 06E7: C3
; Generate circle/noise texture into ES:0000. Args: radius, iteration count.
generate_circle_noise_texture:
    push bp                                ; 06E8: 55
    mov_r_rm16 bp, sp                      ; 06E9: 8B EC / mov bp,sp
    mov es,[bx+0x424c]                     ; 06EB: 8E 87 4C 42
    call 0x6de                             ; 06EF: E8 EC FF
    mov si,0x41ad                          ; 06F2: BE AD 41
    mov dx,[bp+0x4]                        ; 06F5: 8B 56 04
    mov_r_rm8 al, dl                       ; 06F8: 8A C2 / mov al,dl
    imul dl                                ; 06FA: F6 EA
    mov_r_rm16 di, ax                      ; 06FC: 8B F8 / mov di,ax
    mov_r_rm16 cx, dx                      ; 06FE: 8B CA / mov cx,dx
    add_r_rm16 cx, cx                      ; 0700: 03 C9 / add cx,cx
circle_width_loop:
    mov_r_rm8 al, dl                       ; 0702: 8A C2 / mov al,dl
    imul dl                                ; 0704: F6 EA
    neg ax                                 ; 0706: F7 D8
    add_r_rm16 ax, di                      ; 0708: 03 C7 / add ax,di
    mov [si],ax                            ; 070A: 89 04
    fild word [si]                         ; 070C: DF 04
    fsqrt                                  ; 070E: D9 FA
    fistp word [si]                        ; 0710: DF 1C
    inc si                                 ; 0712: 46
    inc si                                 ; 0713: 46
    dec dx                                 ; 0714: 4A
    loop 0x702                             ; 0715: E2 EB
    mov cx,[bp+0x6]                        ; 0717: 8B 4E 06
circle_noise_iteration_loop:
    push cx                                ; 071A: 51
    mov bx,0x1000                          ; 071B: BB 00 10
    call 0x699                             ; 071E: E8 78 FF
    mov_r_rm16 di, ax                      ; 0721: 8B F8 / mov di,ax
    mov si,0x41ad                          ; 0723: BE AD 41
    mov cx,[bp+0x4]                        ; 0726: 8B 4E 04
    add_r_rm16 cx, cx                      ; 0729: 03 C9 / add cx,cx
circle_noise_row_loop:
    push cx                                ; 072B: 51
    lodsw                                  ; 072C: AD
    mov_r_rm16 cx, ax                      ; 072D: 8B C8 / mov cx,ax
    add_r_rm16 cx, cx                      ; 072F: 03 C9 / add cx,cx
    jz short 0x741                         ; 0731: 74 0E
    push di                                ; 0733: 57
    sub_r_rm16 di, ax                      ; 0734: 2B F8 / sub di,ax
circle_noise_span_loop:
    and di,0xfff                           ; 0736: 81 E7 FF 0F
    inc byte [es:di]                       ; 073A: 26 FE 05
    inc di                                 ; 073D: 47
    loop 0x736                             ; 073E: E2 F6
    pop di                                 ; 0740: 5F
loc_0741:
    add di,byte +0x40                      ; 0741: 83 C7 40
    pop cx                                 ; 0744: 59
    loop 0x72b                             ; 0745: E2 E4
    pop cx                                 ; 0747: 59
    loop 0x71a                             ; 0748: E2 D0
    pop bp                                 ; 074A: 5D
    ret 0x4                                ; 074B: C2 04 00
; Core soft rasterizer: clipping/bounds, perspective-correct texture setup, scanline draw.
draw_polygon_scanlines:
    enter 0x96,0x0                         ; 074E: C8 96 00 00
    mov ax,0x8001                          ; 0752: B8 01 80
    mov_r_rm16 bx, ax                      ; 0755: 8B D8 / mov bx,ax
    mov_r_rm16 si, ax                      ; 0757: 8B F0 / mov si,ax
    neg ax                                 ; 0759: F7 D8
    mov_r_rm16 dx, ax                      ; 075B: 8B D0 / mov dx,ax
    mov di,[bp+0x8]                        ; 075D: 8B 7E 08
    xor_r_rm16 cx, cx                      ; 0760: 33 C9 / xor cx,cx
raster_bounds_loop:
    cmp ax,[di+0x12]                       ; 0762: 3B 45 12
    jng short 0x76a                        ; 0765: 7E 03
    mov ax,[di+0x12]                       ; 0767: 8B 45 12
loc_076A:
    cmp bx,[di+0x12]                       ; 076A: 3B 5D 12
    jnl short 0x772                        ; 076D: 7D 03
    mov bx,[di+0x12]                       ; 076F: 8B 5D 12
loc_0772:
    cmp dx,[di+0xc]                        ; 0772: 3B 55 0C
    jng short 0x782                        ; 0775: 7E 0B
    mov dx,[di+0xc]                        ; 0777: 8B 55 0C
    mov [bp-0x84],cx                       ; 077A: 89 8E 7C FF
    mov [bp-0x86],cx                       ; 077E: 89 8E 7A FF
loc_0782:
    cmp si,[di+0xc]                        ; 0782: 3B 75 0C
    jnl short 0x78a                        ; 0785: 7D 03
    mov si,[di+0xc]                        ; 0787: 8B 75 0C
loc_078A:
    add di,byte +0x24                      ; 078A: 83 C7 24
    inc cx                                 ; 078D: 41
    cmp cx,[bp+0x6]                        ; 078E: 3B 4E 06
    jnz short 0x762                        ; 0791: 75 CF
    cmp bx,byte +0x0                       ; 0793: 83 FB 00
    jl near 0x9bb                          ; 0796: 0F 8C 21 02
    cmp ax,0x140                           ; 079A: 3D 40 01
    jg near 0x9bb                          ; 079D: 0F 8F 1A 02
    cmp si,byte +0x15                      ; 07A1: 83 FE 15
    jl near 0x9bb                          ; 07A4: 0F 8C 13 02
    cmp dx,0xb3                            ; 07A8: 81 FA B3 00
    jg near 0x9bb                          ; 07AC: 0F 8F 0B 02
    mov [bp-0x7e],dx                       ; 07B0: 89 56 82
    mov [bp-0x80],si                       ; 07B3: 89 76 80
    cmp word [bp-0x80],0xb3                ; 07B6: 81 7E 80 B3 00
    jng short 0x7c2                        ; 07BB: 7E 05
    mov word [bp-0x80],0xb3                ; 07BD: C7 46 80 B3 00
loc_07C2:
    mov ax,[bp-0x7e]                       ; 07C2: 8B 46 82
    cmp ax,[bp-0x80]                       ; 07C5: 3B 46 80
    jz near 0x9bb                          ; 07C8: 0F 84 EF 01
    mov [bp-0x82],ax                       ; 07CC: 89 86 7E FF
    mov bx,[bp+0x4]                        ; 07D0: 8B 5E 04
    add_r_rm16 bx, bx                      ; 07D3: 03 DB / add bx,bx
    mov es,[0x4248]                        ; 07D5: 8E 06 48 42
    mov fs,[bx+0x424c]                     ; 07D9: 8E A7 4C 42
raster_y_loop:
    mov ax,[bp-0x82]                       ; 07DD: 8B 86 7E FF
    cmp ax,[bp-0x80]                       ; 07E1: 3B 46 80
    jg near 0x9bb                          ; 07E4: 0F 8F D3 01
raster_left_edge_advance:
    mov ax,[bp-0x82]                       ; 07E8: 8B 86 7E FF
    cmp ax,[bp-0x80]                       ; 07EC: 3B 46 80
    jnl short 0x816                        ; 07EF: 7D 25
    mov si,[bp+0x8]                        ; 07F1: 8B 76 08
    imul bx,[bp-0x84],byte +0x24           ; 07F4: 6B 9E 7C FF 24
    add_r_rm16 si, bx                      ; 07F9: 03 F3 / add si,bx
    cmp ax,[si+0xc]                        ; 07FB: 3B 44 0C
    jnz short 0x816                        ; 07FE: 75 16
    mov bx,[bp-0x84]                       ; 0800: 8B 9E 7C FF
    dec bx                                 ; 0804: 4B
    jnl short 0x80b                        ; 0805: 7D 04
    mov bx,[bp+0x6]                        ; 0807: 8B 5E 06
    dec bx                                 ; 080A: 4B
loc_080B:
    mov [bp-0x84],bx                       ; 080B: 89 9E 7C FF
    xor_r_rm16 di, di                      ; 080F: 33 FF / xor di,di
    call 0x9bf                             ; 0811: E8 AB 01
    jmp short 0x7e8                        ; 0814: EB D2
raster_right_edge_advance:
    mov ax,[bp-0x82]                       ; 0816: 8B 86 7E FF
    cmp ax,[bp-0x80]                       ; 081A: 3B 46 80
    jnl short 0x846                        ; 081D: 7D 27
    mov si,[bp+0x8]                        ; 081F: 8B 76 08
    imul bx,[bp-0x86],byte +0x24           ; 0822: 6B 9E 7A FF 24
    add_r_rm16 si, bx                      ; 0827: 03 F3 / add si,bx
    cmp ax,[si+0xc]                        ; 0829: 3B 44 0C
    jnz short 0x846                        ; 082C: 75 18
    mov bx,[bp-0x86]                       ; 082E: 8B 9E 7A FF
    inc bx                                 ; 0832: 43
    cmp bx,[bp+0x6]                        ; 0833: 3B 5E 06
    jl short 0x83a                         ; 0836: 7C 02
    xor_r_rm16 bx, bx                      ; 0838: 33 DB / xor bx,bx
loc_083A:
    mov [bp-0x86],bx                       ; 083A: 89 9E 7A FF
    mov di,0x14                            ; 083E: BF 14 00
    call 0x9bf                             ; 0841: E8 7B 01
    jmp short 0x816                        ; 0844: EB D0
raster_draw_scanline:
    cmp word [bp-0x82],byte +0x15          ; 0846: 83 BE 7E FF 15
    jl near 0x9a4                          ; 084B: 0F 8C 55 01
    xor_r_rm32 ebx, ebx                    ; 084F: 66 33 DB / xor ebx,ebx
    xor_r_rm32 ecx, ecx                    ; 0852: 66 33 C9 / xor ecx,ecx
    mov bx,[bp-0x3a]                       ; 0855: 8B 5E C6
    mov [bp-0x7a],bx                       ; 0858: 89 5E 86
    mov cx,[bp-0x26]                       ; 085B: 8B 4E DA
    mov [bp-0x7c],cx                       ; 085E: 89 4E 84
    sub_r_rm16 cx, bx                      ; 0861: 2B CB / sub cx,bx
    jz near 0x9a4                          ; 0863: 0F 84 3D 01
    cmp word [bp-0x7c],byte +0x0           ; 0867: 83 7E 84 00
    jng near 0x9a4                         ; 086B: 0F 8E 35 01
    cmp word [bp-0x7a],0x140               ; 086F: 81 7E 86 40 01
    jg near 0x9a4                          ; 0874: 0F 8F 2C 01
    neg bx                                 ; 0878: F7 DB
    jns short 0x880                        ; 087A: 79 04
    xor_r_rm16 bx, bx                      ; 087C: 33 DB / xor bx,bx
    jmp short 0x885                        ; 087E: EB 05
loc_0880:
    mov word [bp-0x7a],0x0                 ; 0880: C7 46 86 00 00
loc_0885:
    mov di,0x10                            ; 0885: BF 10 00
raster_clip_left_interpolate_loop:
    mov eax,[bp+di-0x28]                   ; 0888: 66 8B 43 D8
    sub eax,[bp+di-0x3c]                   ; 088C: 66 2B 43 C4
    cdq                                    ; 0890: 66 99
    jcxz 0x89b                             ; 0892: E3 07
    idiv ecx                               ; 0894: 66 F7 F9
    mov [bp+di-0x50],eax                   ; 0897: 66 89 43 B0
loc_089B:
    mov eax,[bp+di-0x50]                   ; 089B: 66 8B 43 B0
    imul ebx                               ; 089F: 66 F7 EB
    add eax,[bp+di-0x3c]                   ; 08A2: 66 03 43 C4
    mov [bp+di-0x14],eax                   ; 08A6: 66 89 43 EC
    sub di,byte +0x4                       ; 08AA: 83 EF 04
    jnz short 0x888                        ; 08AD: 75 D9
    mov ax,[bp-0x40]                       ; 08AF: 8B 46 C0
    mov [cs:0x98d],ax                      ; 08B2: 2E A3 8D 09
    cmp word [bp-0x7c],0x140               ; 08B6: 81 7E 84 40 01
    jng short 0x8c2                        ; 08BB: 7E 05
    mov word [bp-0x7c],0x140               ; 08BD: C7 46 84 40 01
loc_08C2:
    imul di,[bp-0x82],word 0x140           ; 08C2: 69 BE 7E FF 40 01
    add di,[bp-0x7a]                       ; 08C8: 03 7E 86
    mov bx,0x100                           ; 08CB: BB 00 01
    mov eax,[bp-0x10]                      ; 08CE: 66 8B 46 F0
    imul ebx                               ; 08D2: 66 F7 EB
    idiv dword [bp-0x8]                    ; 08D5: 66 F7 7E F8
    mov [bp-0x8c],ax                       ; 08D9: 89 86 74 FF
    mov eax,[bp-0xc]                       ; 08DD: 66 8B 46 F4
    imul ebx                               ; 08E1: 66 F7 EB
    idiv dword [bp-0x8]                    ; 08E4: 66 F7 7E F8
    mov [bp-0x8e],ax                       ; 08E8: 89 86 72 FF
raster_span_chunk_loop:
    mov cx,[bp-0x7c]                       ; 08EC: 8B 4E 84
    sub cx,[bp-0x7a]                       ; 08EF: 2B 4E 86
    jng near 0x9a4                         ; 08F2: 0F 8E AE 00
    cmp cx,byte +0x10                      ; 08F6: 83 F9 10
    jng short 0x8fe                        ; 08F9: 7E 03
    mov cx,0x10                            ; 08FB: B9 10 00
loc_08FE:
    mov eax,[bp-0x8e]                      ; 08FE: 66 8B 86 72 FF
    mov [bp-0x8a],eax                      ; 0903: 66 89 86 76 FF
    mov eax,[bp-0x4c]                      ; 0908: 66 8B 46 B4
    imul ecx                               ; 090C: 66 F7 E9
    add [bp-0x10],eax                      ; 090F: 66 01 46 F0
    mov eax,[bp-0x48]                      ; 0913: 66 8B 46 B8
    imul ecx                               ; 0917: 66 F7 E9
    add [bp-0xc],eax                       ; 091A: 66 01 46 F4
    mov eax,[bp-0x44]                      ; 091E: 66 8B 46 BC
    imul ecx                               ; 0922: 66 F7 E9
    add [bp-0x8],eax                       ; 0925: 66 01 46 F8
    mov bx,0x100                           ; 0929: BB 00 01
    mov eax,[bp-0x10]                      ; 092C: 66 8B 46 F0
    imul ebx                               ; 0930: 66 F7 EB
    idiv dword [bp-0x8]                    ; 0933: 66 F7 7E F8
    mov [bp-0x8c],ax                       ; 0937: 89 86 74 FF
    mov eax,[bp-0xc]                       ; 093B: 66 8B 46 F4
    imul ebx                               ; 093F: 66 F7 EB
    idiv dword [bp-0x8]                    ; 0942: 66 F7 7E F8
    mov [bp-0x8e],ax                       ; 0946: 89 86 72 FF
    mov ax,[bp-0x8c]                       ; 094A: 8B 86 74 FF
    sub ax,[bp-0x88]                       ; 094E: 2B 86 78 FF
    cwd                                    ; 0952: 99
    idiv cx                                ; 0953: F7 F9
    mov [cs:0x991],ax                      ; 0955: 2E A3 91 09
    mov ax,[bp-0x8e]                       ; 0959: 8B 86 72 FF
    sub ax,[bp-0x8a]                       ; 095D: 2B 86 76 FF
    cwd                                    ; 0961: 99
    idiv cx                                ; 0962: F7 F9
    mov [cs:0x995],ax                      ; 0964: 2E A3 95 09
    mov si,[bp-0x8a]                       ; 0968: 8B B6 76 FF
    mov dx,[bp-0x88]                       ; 096C: 8B 96 78 FF
    mov ax,[bp-0x4]                        ; 0970: 8B 46 FC
raster_pixel_loop:
    mov_r_rm16 bx, si                      ; 0973: 8B DE / mov bx,si
    xor_r_rm8 bl, bl                       ; 0975: 32 DB / xor bl,bl
    shr bx,byte 0x2                        ; 0977: C1 EB 02
    add_r_rm8 bl, dh                       ; 097A: 02 DE / add bl,dh
    mov bl,[fs:bx]                         ; 097C: 64 8A 1F
    or_r_rm8 bl, bl                        ; 097F: 0A DB / or bl,bl
    jz short 0x98c                         ; 0981: 74 09
    mov_r_rm8 bh, ah                       ; 0983: 8A FC / mov bh,ah
    mov bl,[bx+0x4274]                     ; 0985: 8A 9F 74 42
    mov [es:di],bl                         ; 0989: 26 88 1D
raster_next_pixel:
    add ax,0x1111                          ; 098C: 05 11 11
    add dx,0x1111                          ; 098F: 81 C2 11 11
    add si,0x1111                          ; 0993: 81 C6 11 11
    inc di                                 ; 0997: 47
    loop 0x973                             ; 0998: E2 D9
    mov [bp-0x4],ax                        ; 099A: 89 46 FC
    add word [bp-0x7a],byte +0x10          ; 099D: 83 46 86 10
    jmp 0x8ec                              ; 09A1: E9 48 FF
raster_next_scanline:
    mov di,0x24                            ; 09A4: BF 24 00
loc_09A7:
    mov eax,[bp+di-0x78]                   ; 09A7: 66 8B 43 88
    add [bp+di-0x3c],eax                   ; 09AB: 66 01 43 C4
    sub di,byte +0x4                       ; 09AF: 83 EF 04
    jns short 0x9a7                        ; 09B2: 79 F3
    inc word [bp-0x82]                     ; 09B4: FF 86 7E FF
    jmp 0x7dd                              ; 09B8: E9 22 FE
loc_09BB:
    leave                                  ; 09BB: C9
    ret 0x6                                ; 09BC: C2 06 00
edge_setup_for_scanline:
    imul dx,bx,byte +0x24                  ; 09BF: 6B D3 24
    mov_r_rm16 bx, si                      ; 09C2: 8B DE / mov bx,si
    mov si,[bp+0x8]                        ; 09C4: 8B 76 08
    add_r_rm16 si, dx                      ; 09C7: 03 F2 / add si,dx
    mov ax,[si+0xc]                        ; 09C9: 8B 44 0C
    sub ax,[bp-0x82]                       ; 09CC: 2B 86 7E FF
    movsx eax,ax                           ; 09D0: 66 0F BF C0
    mov [bp-0x96],eax                      ; 09D4: 66 89 86 6A FF
    mov cx,0x5                             ; 09D9: B9 05 00
    mov edx,[bx+0x10]                      ; 09DC: 66 8B 57 10
    mov [bp+di-0x3c],edx                   ; 09E0: 66 89 53 C4
    mov eax,[si+0x10]                      ; 09E4: 66 8B 44 10
    sub_r_rm32 eax, edx                    ; 09E8: 66 2B C2 / sub eax,edx
    cdq                                    ; 09EB: 66 99
    cmp word [bp-0x96],byte +0x0           ; 09ED: 83 BE 6A FF 00
    jz short 0x9fd                         ; 09F2: 74 09
    idiv dword [bp-0x96]                   ; 09F4: 66 F7 BE 6A FF
    mov [bp+di-0x78],eax                   ; 09F9: 66 89 43 88
loc_09FD:
    add di,byte +0x4                       ; 09FD: 83 C7 04
    add si,byte +0x4                       ; 0A00: 83 C6 04
    add bx,byte +0x4                       ; 0A03: 83 C3 04
    loop 0x9dc                             ; 0A06: E2 D4
    ret                                    ; 0A08: C3
; Prepare one quad: load transformed vertices, near-plane clip, project, call rasterizer.
prepare_and_clip_face:
    enter 0x172,0x0                        ; 0A09: C8 72 01 00
    mov si,0x103f                          ; 0A0D: BE 3F 10
    xor_r_rm16 di, di                      ; 0A10: 33 FF / xor di,di
    mov cx,0x4                             ; 0A12: B9 04 00
prepare_vertex_loop:
    push bx                                ; 0A15: 53
    mov bx,[bx]                            ; 0A16: 8B 1F
    push bx                                ; 0A18: 53
    imul bx,bx,byte +0xc                   ; 0A19: 6B DB 0C
    add bx,0xc454                          ; 0A1C: 81 C3 54 C4
    mov eax,[bx]                           ; 0A20: 66 8B 07
    mov [bp+di-0xbe],eax                   ; 0A23: 66 89 83 42 FF
    mov eax,[bx+0x4]                       ; 0A28: 66 8B 47 04
    mov [bp+di-0xba],eax                   ; 0A2C: 66 89 83 46 FF
    fld dword [bx+0x8]                     ; 0A31: D9 47 08
    fst dword [bp+di-0xb6]                 ; 0A34: D9 93 4A FF
    fistp word [bp-0x4]                    ; 0A38: DF 5E FC
    pop bx                                 ; 0A3B: 5B
    mov ax,[bp-0x4]                        ; 0A3C: 8B 46 FC
    add ax,0x200                           ; 0A3F: 05 00 02
    js near 0xb5e                          ; 0A42: 0F 88 18 01
    cmp ax,0x1ff                           ; 0A46: 3D FF 01
    jng short 0xa4e                        ; 0A49: 7E 03
    mov ax,0x1ff                           ; 0A4B: B8 FF 01
loc_0A4E:
    shl bx,byte 0x3                        ; 0A4E: C1 E3 03
    xor_r_rm32 edx, edx                    ; 0A51: 66 33 D2 / xor edx,edx
    shl ax,byte 0x7                        ; 0A54: C1 E0 07
    mul word [bx+0x1772]                   ; 0A57: F7 A7 72 17
    mov [bp+di-0x9e],edx                   ; 0A5B: 66 89 93 62 FF
    xor_r_rm8 ah, ah                       ; 0A60: 32 E4 / xor ah,ah
    mov al,[si+0x4]                        ; 0A62: 8A 44 04
    shl eax,byte 0x10                      ; 0A65: 66 C1 E0 10
    mov [bp+di-0xa6],eax                   ; 0A69: 66 89 83 5A FF
    lodsb                                  ; 0A6E: AC
    shl eax,byte 0x10                      ; 0A6F: 66 C1 E0 10
    mov [bp+di-0xaa],eax                   ; 0A73: 66 89 83 56 FF
    pop bx                                 ; 0A78: 5B
    inc bx                                 ; 0A79: 43
    inc bx                                 ; 0A7A: 43
    add di,byte +0x24                      ; 0A7B: 83 C7 24
    loop 0xa15                             ; 0A7E: E2 95
    mov ax,[bx]                            ; 0A80: 8B 07
    mov [bp-0x8],ax                        ; 0A82: 89 46 F8
    xor_r_rm16 bx, bx                      ; 0A85: 33 DB / xor bx,bx
    mov [bp-0x6],bx                        ; 0A87: 89 5E FA
    fld dword [bp-0x4a]                    ; 0A8A: D9 46 B6
    ftst                                   ; 0A8D: D9 E4
    fstsw ax                               ; 0A8F: 9B DF E0
    fstp st0                               ; 0A92: DD D8
    sahf                                   ; 0A94: 9E
    jnc short 0xa98                        ; 0A95: 73 01
    dec bx                                 ; 0A97: 4B
loc_0A98:
    mov [bp-0xa],bl                        ; 0A98: 88 5E F6
    xor_r_rm16 si, si                      ; 0A9B: 33 F6 / xor si,si
    xor_r_rm16 di, di                      ; 0A9D: 33 FF / xor di,di
clip_vertex_loop:
    fld dword [bp+si-0xb6]                 ; 0A9F: D9 82 4A FF
    ftst                                   ; 0AA3: D9 E4
    fstsw ax                               ; 0AA5: 9B DF E0
    fstp st0                               ; 0AA8: DD D8
    sahf                                   ; 0AAA: 9E
    jnc short 0xad8                        ; 0AAB: 73 2B
    cmp byte [bp-0xa],0xff                 ; 0AAD: 80 7E F6 FF
    jz short 0xab9                         ; 0AB1: 74 06
    call 0xb60                             ; 0AB3: E8 AA 00
    not byte [bp-0xa]                      ; 0AB6: F6 56 F6
copy_visible_vertex:
    push di                                ; 0AB9: 57
    push si                                ; 0ABA: 56
    lea di,[bp+di-0x172]                   ; 0ABB: 8D BB 8E FE
    lea si,[bp+si-0xbe]                    ; 0ABF: 8D B2 42 FF
    push ss                                ; 0AC3: 16
    pop es                                 ; 0AC4: 07
    push ds                                ; 0AC5: 1E
    push ss                                ; 0AC6: 16
    pop ds                                 ; 0AC7: 1F
    mov cx,0x12                            ; 0AC8: B9 12 00
    rep movsw                              ; 0ACB: F3 A5
    pop ds                                 ; 0ACD: 1F
    pop si                                 ; 0ACE: 5E
    pop di                                 ; 0ACF: 5F
    add di,byte +0x24                      ; 0AD0: 83 C7 24
    inc word [bp-0x6]                      ; 0AD3: FF 46 FA
    jmp short 0xae4                        ; 0AD6: EB 0C
clip_leaving_edge:
    cmp byte [bp-0xa],0xff                 ; 0AD8: 80 7E F6 FF
    jnz short 0xae4                        ; 0ADC: 75 06
    call 0xb60                             ; 0ADE: E8 7F 00
    not byte [bp-0xa]                      ; 0AE1: F6 56 F6
loc_0AE4:
    add si,byte +0x24                      ; 0AE4: 83 C6 24
    cmp si,0x90                            ; 0AE7: 81 FE 90 00
    jnz short 0xa9f                        ; 0AEB: 75 B2
    mov cx,[bp-0x6]                        ; 0AED: 8B 4E FA
    cmp cx,byte +0x2                       ; 0AF0: 83 F9 02
    jl short 0xb5e                         ; 0AF3: 7C 69
    nop                                    ; 0AF5: 90
    nop                                    ; 0AF6: 90
    xor_r_rm16 di, di                      ; 0AF7: 33 FF / xor di,di
project_visible_vertex_loop:
    fild word [0xdcf]                      ; 0AF9: DF 06 CF 0D
    fsub dword [bp+di-0x16a]               ; 0AFD: D8 A3 96 FE
    fidiv word [0xdd3]                     ; 0B01: DE 36 D3 0D
    fld dword [bp+di-0x16e]                ; 0B05: D9 83 92 FE
    fdiv st1                               ; 0B09: D8 F1
    fiadd word [0xdd1]                     ; 0B0B: DE 06 D1 0D
    fistp dword [bp+di-0x166]              ; 0B0F: DB 9B 9A FE
    fld dword [bp+di-0x172]                ; 0B13: D9 83 8E FE
    fmul dword [0xdcb]                     ; 0B17: D8 0E CB 0D
    fdiv st1                               ; 0B1B: D8 F1
    fiadd word [0xdd3]                     ; 0B1D: DE 06 D3 0D
    frndint                                ; 0B21: D9 FC
    fimul dword [0xdd7]                    ; 0B23: DA 0E D7 0D
    fistp dword [bp+di-0x162]              ; 0B27: DB 9B 9E FE
    fild dword [bp+di-0x15e]               ; 0B2B: DB 83 A2 FE
    fdiv st1                               ; 0B2F: D8 F1
    fistp dword [bp+di-0x15e]              ; 0B31: DB 9B A2 FE
    fild dword [bp+di-0x15a]               ; 0B35: DB 83 A6 FE
    fdiv st1                               ; 0B39: D8 F1
    fistp dword [bp+di-0x15a]              ; 0B3B: DB 9B A6 FE
    fild dword [0xdd7]                     ; 0B3F: DB 06 D7 0D
    fdiv st1                               ; 0B43: D8 F1
    fistp dword [bp+di-0x156]              ; 0B45: DB 9B AA FE
    fstp st0                               ; 0B49: DD D8
    add di,byte +0x24                      ; 0B4B: 83 C7 24
    loop 0xaf9                             ; 0B4E: E2 A9
    lea di,[bp-0x172]                      ; 0B50: 8D BE 8E FE
    push di                                ; 0B54: 57
    push word [bp-0x6]                     ; 0B55: FF 76 FA
    push word [bp-0x8]                     ; 0B58: FF 76 F8
    call 0x74e                             ; 0B5B: E8 F0 FB
loc_0B5E:
    leave                                  ; 0B5E: C9
    ret                                    ; 0B5F: C3
; Clip one polygon edge against near plane and interpolate attributes.
clip_edge_against_near:
    push si                                ; 0B60: 56
    push di                                ; 0B61: 57
    lea ax,[si-0x24]                       ; 0B62: 8D 44 DC
    cmp ax,strict word 0x0          ; 0B65: 3D 00 00
    jnl short 0xb6d                        ; 0B68: 7D 03
    mov ax,0x6c                            ; 0B6A: B8 6C 00
loc_0B6D:
    fld dword [bp+si-0xb6]                 ; 0B6D: D9 82 4A FF
    fld st0                                ; 0B71: D9 C0
    xchg ax,di                             ; 0B73: 97
    fsub dword [bp+di-0xb6]                ; 0B74: D8 A3 4A FF
    xchg ax,di                             ; 0B78: 97
    fdivp st1                              ; 0B79: DE F9
    mov bx,0x103a                          ; 0B7B: BB 3A 10
    mov cx,0x6                             ; 0B7E: B9 06 00
    xchg ax,di                             ; 0B81: 97
    fld dword [bp+di-0xbe]                 ; 0B82: D9 83 42 FF
    xchg ax,di                             ; 0B86: 97
    fsub dword [bp+si-0xbe]                ; 0B87: D8 A2 42 FF
    fmul st1                               ; 0B8B: D8 C9
    fadd dword [bp+si-0xbe]                ; 0B8D: D8 82 42 FF
    fstp dword [bp+di-0x172]               ; 0B91: D9 9B 8E FE
    mov dl,[bx]                            ; 0B95: 8A 17
    inc bx                                 ; 0B97: 43
    xor_r_rm8 dh, dh                       ; 0B98: 32 F6 / xor dh,dh
    add_r_rm16 di, dx                      ; 0B9A: 03 FA / add di,dx
    add_r_rm16 si, dx                      ; 0B9C: 03 F2 / add si,dx
    add_r_rm16 ax, dx                      ; 0B9E: 03 C2 / add ax,dx
    loop 0xb81                             ; 0BA0: E2 DF
    fstp st0                               ; 0BA2: DD D8
    pop di                                 ; 0BA4: 5F
    pop si                                 ; 0BA5: 5E
    inc word [bp-0x6]                      ; 0BA6: FF 46 FA
    add di,byte +0x24                      ; 0BA9: 83 C7 24
    ret                                    ; 0BAC: C3
rotate_pair_by_angle:
    fldpi                                  ; 0BAD: D9 EB
    fmulp st1                              ; 0BAF: DE C9
    fidiv dword [0xdd7]                    ; 0BB1: DA 36 D7 0D
    fsincos                                ; 0BB5: D9 FB
    fld st0                                ; 0BB7: D9 C0
    fmul dword [si]                        ; 0BB9: D8 0C
    fld st2                                ; 0BBB: D9 C2
    fmul dword [bx]                        ; 0BBD: D8 0F
    fsubp st1                              ; 0BBF: DE E9
    fxch st2                               ; 0BC1: D9 CA
    fmul dword [si]                        ; 0BC3: D8 0C
    fxch st1                               ; 0BC5: D9 C9
    fmul dword [bx]                        ; 0BC7: D8 0F
    faddp st1                              ; 0BC9: DE C1
    fstp dword [bx]                        ; 0BCB: D9 1F
    fstp dword [si]                        ; 0BCD: D9 1C
    ret                                    ; 0BCF: C3
rotate_matrix_euler:
    push bp                                ; 0BD0: 55
    mov_r_rm16 bp, sp                      ; 0BD1: 8B EC / mov bp,sp
    mov di,[bp+0x4]                        ; 0BD3: 8B 7E 04
    fild word [bp+0xa]                     ; 0BD6: DF 46 0A
    lea bx,[di+0x8]                        ; 0BD9: 8D 5D 08
    lea si,[di+0x4]                        ; 0BDC: 8D 75 04
    call 0xbad                             ; 0BDF: E8 CB FF
    fild word [bp+0x8]                     ; 0BE2: DF 46 08
    lea bx,[di]                            ; 0BE5: 8D 1D
    lea si,[di+0x8]                        ; 0BE7: 8D 75 08
    call 0xbad                             ; 0BEA: E8 C0 FF
    fild word [bp+0x6]                     ; 0BED: DF 46 06
    lea bx,[di+0x4]                        ; 0BF0: 8D 5D 04
    lea si,[di]                            ; 0BF3: 8D 35
    call 0xbad                             ; 0BF5: E8 B5 FF
    pop bp                                 ; 0BF8: 5D
    ret 0x8                                ; 0BF9: C2 08 00
build_camera_matrix:
    push bp                                ; 0BFC: 55
    mov_r_rm16 bp, sp                      ; 0BFD: 8B EC / mov bp,sp
    mov di,0x13d2                          ; 0BFF: BF D2 13
    mov ch,0x2                             ; 0C02: B5 02
loc_0C04:
    mov cl,0x2                             ; 0C04: B1 02
loc_0C06:
    fldz                                   ; 0C06: D9 EE
    cmp_r_rm8 ch, cl                       ; 0C08: 3A E9 / cmp ch,cl
    jnz short 0xc10                        ; 0C0A: 75 04
    fstp st0                               ; 0C0C: DD D8
    fld1                                   ; 0C0E: D9 E8
loc_0C10:
    fstp dword [di]                        ; 0C10: D9 1D
    add di,byte +0x4                       ; 0C12: 83 C7 04
    dec cl                                 ; 0C15: FE C9
    jns short 0xc06                        ; 0C17: 79 ED
    dec ch                                 ; 0C19: FE CD
    jns short 0xc04                        ; 0C1B: 79 E7
    xor_r_rm16 di, di                      ; 0C1D: 33 FF / xor di,di
loc_0C1F:
    push di                                ; 0C1F: 57
    push word [bp+0xa]                     ; 0C20: FF 76 0A
    push word [bp+0x8]                     ; 0C23: FF 76 08
    push word [bp+0x6]                     ; 0C26: FF 76 06
    add di,0x13d2                          ; 0C29: 81 C7 D2 13
    push di                                ; 0C2D: 57
    call 0xbd0                             ; 0C2E: E8 9F FF
    pop di                                 ; 0C31: 5F
    xor_r_rm16 bx, bx                      ; 0C32: 33 DB / xor bx,bx
loc_0C34:
    fld dword [di+0x13d2]                  ; 0C34: D9 85 D2 13
    fmul dword [bx+0x138a]                 ; 0C38: D8 8F 8A 13
    fld dword [di+0x13d6]                  ; 0C3C: D9 85 D6 13
    fmul dword [bx+0x1396]                 ; 0C40: D8 8F 96 13
    fld dword [di+0x13da]                  ; 0C44: D9 85 DA 13
    fmul dword [bx+0x13a2]                 ; 0C48: D8 8F A2 13
    faddp st1                              ; 0C4C: DE C1
    faddp st1                              ; 0C4E: DE C1
    fst dword [bx+di+0x138a]               ; 0C50: D9 91 8A 13
    fstp dword [bx+di+0x13ae]              ; 0C54: D9 99 AE 13
    add bx,byte +0x4                       ; 0C58: 83 C3 04
    cmp bl,0xc                             ; 0C5B: 80 FB 0C
    jnz short 0xc34                        ; 0C5E: 75 D4
    add di,byte +0xc                       ; 0C60: 83 C7 0C
    cmp di,byte +0x24                      ; 0C63: 83 FF 24
    jnz short 0xc1f                        ; 0C66: 75 B7
    mov si,0x13ae                          ; 0C68: BE AE 13
    mov cx,0x3                             ; 0C6B: B9 03 00
    fild word [bp+0x4]                     ; 0C6E: DF 46 04
    lea bx,[si+0xc]                        ; 0C71: 8D 5C 0C
    call 0xbad                             ; 0C74: E8 36 FF
    add si,byte +0x4                       ; 0C77: 83 C6 04
    loop 0xc6e                             ; 0C7A: E2 F2
    pop bp                                 ; 0C7C: 5D
    ret 0x8                                ; 0C7D: C2 08 00
; Decode compact cube/face scene description into vertex and quad arrays.
build_scene_geometry:
    enter 0x4,0x0                          ; 0C80: C8 04 00 00
    mov si,0x108c                          ; 0C84: BE 8C 10
    mov cx,0x4                             ; 0C87: B9 04 00
scene_stream_loop:
    push cx                                ; 0C8A: 51
    push si                                ; 0C8B: 56
    mov di,0xc274                          ; 0C8C: BF 74 C2
    mov bx,0xc2ec                          ; 0C8F: BB EC C2
    mov si,0x105f                          ; 0C92: BE 5F 10
    mov cl,0xf                             ; 0C95: B1 0F
scene_seed_point_loop:
    push cx                                ; 0C97: 51
    mov cl,0x3                             ; 0C98: B1 03
scene_seed_component_loop:
    lodsb                                  ; 0C9A: AC
    cbw                                    ; 0C9B: 98
    stosw                                  ; 0C9C: AB
    fild word [di-0x2]                     ; 0C9D: DF 45 FE
    fstp dword [bx]                        ; 0CA0: D9 1F
    add bx,byte +0x4                       ; 0CA2: 83 C3 04
    loop 0xc9a                             ; 0CA5: E2 F3
    pop cx                                 ; 0CA7: 59
    mov ax,0x7f00                          ; 0CA8: B8 00 7F
    stosw                                  ; 0CAB: AB
    loop 0xc97                             ; 0CAC: E2 E9
    pop si                                 ; 0CAE: 5E
scene_token_loop:
    lodsb                                  ; 0CAF: AC
    cmp al,0xff                            ; 0CB0: 3C FF
    jz near 0xdc3                          ; 0CB2: 0F 84 0D 01
    mov_r_rm8 bh, al                       ; 0CB6: 8A F8 / mov bh,al
    and bx,0x7000                          ; 0CB8: 81 E3 00 70
    add bh,0xf                             ; 0CBC: 80 C7 0F
    mov [bp-0x4],bx                        ; 0CBF: 89 5E FC
    and ax, strict word 0xf                ; 0CC2: 25 0F 00
    mov [bp-0x2],ax                        ; 0CC5: 89 46 FE
    xor_r_rm16 bx, bx                      ; 0CC8: 33 DB / xor bx,bx
scene_faces_loop:
    test bl,0x4                            ; 0CCA: F6 C3 04
    jz short 0xcd4                         ; 0CCD: 74 05
    lodsb                                  ; 0CCF: AC
    and al,0xf                             ; 0CD0: 24 0F
    jmp short 0xcd9                        ; 0CD2: EB 05
loc_0CD4:
    mov al,[si]                            ; 0CD4: 8A 04
    shr al,byte 0x4                        ; 0CD6: C0 E8 04
loc_0CD9:
    xor_r_rm8 ah, ah                       ; 0CD9: 32 E4 / xor ah,ah
    dec ax                                 ; 0CDB: 48
    js short 0xd2e                         ; 0CDC: 78 50
    imul di,[0x176a],byte +0xa             ; 0CDE: 6B 3E 6A 17 0A
    add di,0x23ec                          ; 0CE3: 81 C7 EC 23
    inc word [0x176a]                      ; 0CE7: FF 06 6A 17
    mov [di+0x8],ax                        ; 0CEB: 89 45 08
    push bx                                ; 0CEE: 53
    push si                                ; 0CEF: 56
    mov cl,0x4                             ; 0CF0: B1 04
scene_vertex_loop:
    movsx si,[bx+0x1047]                   ; 0CF2: 0F BE B7 47 10
    add si,0xc274                          ; 0CF7: 81 C6 74 C2
    push di                                ; 0CFB: 57
    mov di,0x176c                          ; 0CFC: BF 6C 17
    push cx                                ; 0CFF: 51
    mov cx,[0x1768]                        ; 0D00: 8B 0E 68 17
    xor_r_rm16 ax, ax                      ; 0D04: 33 C0 / xor ax,ax
    jcxz 0xd1e                             ; 0D06: E3 16
scene_find_vertex_loop:
    mov edx,[si]                           ; 0D08: 66 8B 14
    cmp edx,[di]                           ; 0D0B: 66 3B 15
    jnz short 0xd18                        ; 0D0E: 75 08
    mov dx,[si+0x4]                        ; 0D10: 8B 54 04
    cmp dx,[di+0x4]                        ; 0D13: 3B 55 04
    jz short 0xd26                         ; 0D16: 74 0E
loc_0D18:
    inc ax                                 ; 0D18: 40
    add di,byte +0x8                       ; 0D19: 83 C7 08
    loop 0xd08                             ; 0D1C: E2 EA
scene_store_new_vertex:
    movsd                                  ; 0D1E: 66 A5
    movsd                                  ; 0D20: 66 A5
    inc word [0x1768]                      ; 0D22: FF 06 68 17
scene_emit_vertex_index:
    pop cx                                 ; 0D26: 59
    pop di                                 ; 0D27: 5F
    stosw                                  ; 0D28: AB
    inc bx                                 ; 0D29: 43
    loop 0xcf2                             ; 0D2A: E2 C6
    pop si                                 ; 0D2C: 5E
    pop bx                                 ; 0D2D: 5B
loc_0D2E:
    add bx,byte +0x4                       ; 0D2E: 83 C3 04
    cmp bx,byte +0x18                      ; 0D31: 83 FB 18
    jnz short 0xcca                        ; 0D34: 75 94
    imul di,[bp-0x2],byte +0xc             ; 0D36: 6B 7E FE 0C
    mov cl,0x3                             ; 0D3A: B1 03
    mov bx,0xc34c                          ; 0D3C: BB 4C C3
accumulate_scene_position:
    fld dword [bx+0x48]                    ; 0D3F: D9 47 48
    fadd dword [bx+di]                     ; 0D42: D8 01
    fstp dword [bx+0x48]                   ; 0D44: D9 5F 48
    add bx,byte +0x4                       ; 0D47: 83 C3 04
    loop 0xd3f                             ; 0D4A: E2 F3
    cmp byte [si-0x4],0x0                  ; 0D4C: 80 7C FC 00
    jnl short 0xd77                        ; 0D50: 7D 25
    mov bx,0xc2ec                          ; 0D52: BB EC C2
    mov cl,0xe                             ; 0D55: B1 0E
scene_apply_rotation_loop:
    pusha                                  ; 0D57: 60
    mov cl,0x3                             ; 0D58: B1 03
    mov dl,[si]                            ; 0D5A: 8A 14
scene_rotation_axis_loop:
    shr dl,1                               ; 0D5C: D0 EA
    jnc short 0xd68                        ; 0D5E: 73 08
    mov ah,[si]                            ; 0D60: 8A 24
    and ax,0xf000                          ; 0D62: 25 00 F0
    push ax                                ; 0D65: 50
    jmp short 0xd6a                        ; 0D66: EB 02
loc_0D68:
    push byte +0x0                         ; 0D68: 6A 00
loc_0D6A:
    loop 0xd5c                             ; 0D6A: E2 F0
    push bx                                ; 0D6C: 53
    call 0xbd0                             ; 0D6D: E8 60 FE
    popa                                   ; 0D70: 61
    add bx,byte +0xc                       ; 0D71: 83 C3 0C
    loop 0xd57                             ; 0D74: E2 E1
    inc si                                 ; 0D76: 46
scene_emit_cube_vertices_setup:
    mov bx,[bp-0x2]                        ; 0D77: 8B 5E FE
    shl bx,byte 0x2                        ; 0D7A: C1 E3 02
    mov cl,0x4                             ; 0D7D: B1 04
scene_emit_cube_vertices_loop:
    pusha                                  ; 0D7F: 60
    movsx si,[bx+0x1047]                   ; 0D80: 0F BE B7 47 10
    mov_r_rm16 ax, si                      ; 0D85: 8B C6 / mov ax,si
    add si,0xc274                          ; 0D87: 81 C6 74 C2
    xor bl,0x7                             ; 0D8B: 80 F3 07
    movsx di,[bx+0x1047]                   ; 0D8E: 0F BE BF 47 10
    add di,0xc274                          ; 0D93: 81 C7 74 C2
    push si                                ; 0D97: 56
    movsd                                  ; 0D98: 66 A5
    movsd                                  ; 0D9A: 66 A5
    pop si                                 ; 0D9C: 5E
    mov_r_rm16 bx, ax                      ; 0D9D: 8B D8 / mov bx,ax
    shr bx,1                               ; 0D9F: D1 EB
    add_r_rm16 bx, ax                      ; 0DA1: 03 D8 / add bx,ax
    mov di,0xc2ec                          ; 0DA3: BF EC C2
    mov cl,0x3                             ; 0DA6: B1 03
scene_emit_component_loop:
    fld dword [bx+di]                      ; 0DA8: D9 01
    fadd dword [di+0xa8]                   ; 0DAA: D8 85 A8 00
    fistp word [si]                        ; 0DAE: DF 1C
    add di,byte +0x4                       ; 0DB0: 83 C7 04
    inc si                                 ; 0DB3: 46
    inc si                                 ; 0DB4: 46
    loop 0xda8                             ; 0DB5: E2 F1
    mov ax,[bp-0x4]                        ; 0DB7: 8B 46 FC
    mov [si],ax                            ; 0DBA: 89 04
    popa                                   ; 0DBC: 61
    inc bx                                 ; 0DBD: 43
    loop 0xd7f                             ; 0DBE: E2 BF
    jmp 0xcaf                              ; 0DC0: E9 EC FE
loc_0DC3:
    pop cx                                 ; 0DC3: 59
    dec cx                                 ; 0DC4: 49
    jnz near 0xc8a                         ; 0DC5: 0F 85 C1 FE
    leave                                  ; 0DC9: C9
    ret                                    ; 0DCA: C3
; Decoded data tables start here. Keep the include separate and readable.
data_start:
    %include "SNC_OMNI_DATA.INC"

%if ($ - $$) != 012AEh
    %error "unpacked COM size changed"
%endif
