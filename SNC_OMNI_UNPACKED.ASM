; Exact, analysis-oriented disassembly of the unpacked SNC_OMNI.COM runtime.
; Derived from SNC_OMNI.COM by reimplementing its own unpacker.
;
; Instructions are emitted as original db bytes so NASM cannot choose a
; different but equivalent encoding. Labels/comments are for analysis only.
; Build check: nasm -f bin SNC_OMNI_UNPACKED.ASM -o SNC_OMNI_unpacked_rebuilt.com

bits 16
org 0100h


; Unpacked runtime entry point.
intro_start:
    db 08Ch, 0C8h                         ; 0100: mov ax,cs
    db 08Eh, 0D8h                         ; 0102: mov ds,ax
    db 0BFh, 048h, 042h                   ; 0104: mov di,0x4248
    db 005h, 000h, 010h                   ; 0107: add ax,0x1000
    db 0ABh                               ; 010A: stosw
    db 005h, 000h, 010h                   ; 010B: add ax,0x1000
    db 0ABh                               ; 010E: stosw
    db 005h, 000h, 010h                   ; 010F: add ax,0x1000
    db 0B9h, 014h, 000h                   ; 0112: mov cx,0x14
    db 0ABh                               ; 0115: stosw
    db 0FEh, 0C4h                         ; 0116: inc ah
    db 0E2h, 0FBh                         ; 0118: loop 0x115
    db 0BFh, 0AEh, 013h                   ; 011A: mov di,0x13ae
    db 0B9h, 0DEh, 01Fh                   ; 011D: mov cx,0x1fde
    db 032h, 0C0h                         ; 0120: xor al,al
    db 0F3h, 0AAh                         ; 0122: rep stosb

; Try to reset MPU-401 and enter UART mode.
probe_mpu401:
    db 0BAh, 031h, 003h                   ; 0124: mov dx,0x331
    db 0B8h, 0FFh, 000h                   ; 0127: mov ax,0xff
    db 0EEh                               ; 012A: out dx,al
loc_012B:
    db 0FEh, 0CCh                         ; 012B: dec ah
    db 074h, 014h                         ; 012D: jz 0x143
    db 0ECh                               ; 012F: in al,dx
    db 0A8h, 080h                         ; 0130: test al,0x80
    db 075h, 0F7h                         ; 0132: jnz 0x12b
    db 04Ah                               ; 0134: dec dx
    db 0ECh                               ; 0135: in al,dx
    db 03Ch, 0FEh                         ; 0136: cmp al,0xfe
    db 075h, 009h                         ; 0138: jnz 0x143
    db 042h                               ; 013A: inc dx
loc_013B:
    db 0ECh                               ; 013B: in al,dx
    db 0A8h, 040h                         ; 013C: test al,0x40
    db 075h, 0FBh                         ; 013E: jnz 0x13b
    db 0B0h, 03Fh                         ; 0140: mov al,0x3f
    db 0EEh                               ; 0142: out dx,al

; Expand packed music streams into runtime channel buffers.
build_midi_channels:
    db 0BEh, 0E3h, 00Dh                   ; 0143: mov si,0xde3
    db 0BBh, 008h, 017h                   ; 0146: mov bx,0x1708
    db 0BFh, 096h, 033h                   ; 0149: mov di,0x3396
midi_channel_decode_loop:
    db 0ADh                               ; 014C: lodsw
    db 0FEh, 0C8h                         ; 014D: dec al
    db 078h, 01Ah                         ; 014F: js 0x16b
    db 088h, 047h, 002h                   ; 0151: mov [bx+0x2],al
    db 004h, 0C0h                         ; 0154: add al,0xc0
    db 0E8h, 07Ch, 005h                   ; 0156: call 0x6d5
    db 089h, 07Fh, 004h                   ; 0159: mov [bx+0x4],di
    db 0E8h, 0DCh, 004h                   ; 015C: call 0x63b
    db 032h, 0C0h                         ; 015F: xor al,al
    db 0AAh                               ; 0161: stosb
    db 083h, 0C3h, 006h                   ; 0162: add bx,byte +0x6
    db 0FFh, 006h, 006h, 014h             ; 0165: inc word [0x1406]
    db 0EBh, 0E1h                         ; 0169: jmp short 0x14c

; Build scene geometry, switch to VGA mode 13h, draw title text, build palette and textures.
init_video_and_palette:
    db 0E8h, 012h, 00Bh                   ; 016B: call 0xc80
    db 0B8h, 013h, 000h                   ; 016E: mov ax,0x13
    db 0CDh, 010h                         ; 0171: int 0x10
    db 086h, 0E0h                         ; 0173: xchg al,ah
    db 0BBh, 01Ch, 000h                   ; 0175: mov bx,0x1c
    db 0BDh, 064h, 013h                   ; 0178: mov bp,0x1364
    db 0B9h, 009h, 000h                   ; 017B: mov cx,0x9
    db 0BAh, 006h, 001h                   ; 017E: mov dx,0x106
    db 0CDh, 010h                         ; 0181: int 0x10
    db 003h, 0E9h                         ; 0183: add bp,cx
    db 0B1h, 011h                         ; 0185: mov cl,0x11
    db 0BAh, 001h, 00Ch                   ; 0187: mov dx,0xc01
    db 0CDh, 010h                         ; 018A: int 0x10
    db 01Eh                               ; 018C: push ds
    db 007h                               ; 018D: pop es
    db 0BBh, 003h, 000h                   ; 018E: mov bx,0x3
palette_component_loop:
    db 0BEh, 028h, 00Fh                   ; 0191: mov si,0xf28
    db 0BFh, 008h, 014h                   ; 0194: mov di,0x1408
    db 032h, 0F6h                         ; 0197: xor dh,dh
    db 0ACh                               ; 0199: lodsb
    db 00Fh, 0B6h, 0C8h                   ; 019A: movzx cx,al
palette_ramp_loop:
    db 051h                               ; 019D: push cx
    db 08Ah, 00Ch                         ; 019E: mov cl,[si]
    db 08Ah, 020h                         ; 01A0: mov ah,[bx+si]
    db 02Bh, 0C2h                         ; 01A2: sub ax,dx
    db 052h                               ; 01A4: push dx
    db 099h                               ; 01A5: cwd
    db 0F7h, 0F9h                         ; 01A6: idiv cx
    db 05Ah                               ; 01A8: pop dx
palette_interp_store:
    db 003h, 0D0h                         ; 01A9: add dx,ax
    db 026h, 088h, 071h, 0FFh             ; 01AB: mov [es:bx+di-0x1],dh
    db 083h, 0C7h, 003h                   ; 01AF: add di,byte +0x3
    db 0E2h, 0F5h                         ; 01B2: loop 0x1a9
    db 083h, 0C6h, 004h                   ; 01B4: add si,byte +0x4
    db 059h                               ; 01B7: pop cx
    db 0E2h, 0E3h                         ; 01B8: loop 0x19d
    db 04Bh                               ; 01BA: dec bx
    db 075h, 0D4h                         ; 01BB: jnz 0x191
    db 0BBh, 022h, 000h                   ; 01BD: mov bx,0x22
    db 068h, 020h, 003h                   ; 01C0: push word 0x320
    db 06Ah, 005h                         ; 01C3: push byte +0x5
    db 0E8h, 020h, 005h                   ; 01C5: call 0x6e8
    db 0BBh, 020h, 000h                   ; 01C8: mov bx,0x20
    db 06Ah, 070h                         ; 01CB: push byte +0x70
    db 06Ah, 00Fh                         ; 01CD: push byte +0xf
    db 0E8h, 016h, 005h                   ; 01CF: call 0x6e8
generate_texture18_vertical_noise:
    db 08Eh, 006h, 070h, 042h             ; 01D2: mov es,[0x4270]
    db 0B0h, 014h                         ; 01D6: mov al,0x14
    db 0E8h, 005h, 005h                   ; 01D8: call 0x6e0
    db 0BFh, 040h, 000h                   ; 01DB: mov di,0x40
    db 0B9h, 0C0h, 00Fh                   ; 01DE: mov cx,0xfc0
texture18_noise_loop:
    db 0BBh, 004h, 000h                   ; 01E1: mov bx,0x4
    db 0E8h, 0B2h, 004h                   ; 01E4: call 0x699
    db 026h, 002h, 045h, 0C0h             ; 01E7: add al,[es:di-0x40]
    db 026h, 002h, 045h, 0C1h             ; 01EB: add al,[es:di-0x3f]
    db 048h                               ; 01EF: dec ax
    db 0D1h, 0E8h                         ; 01F0: shr ax,1
    db 0AAh                               ; 01F2: stosb
    db 0E2h, 0ECh                         ; 01F3: loop 0x1e1
generate_texture19_scatter:
    db 08Eh, 006h, 072h, 042h             ; 01F5: mov es,[0x4272]
    db 0B0h, 003h                         ; 01F9: mov al,0x3
    db 0E8h, 0E2h, 004h                   ; 01FB: call 0x6e0
    db 0B9h, 000h, 010h                   ; 01FE: mov cx,0x1000
texture19_noise_loop:
    db 0BBh, 000h, 010h                   ; 0201: mov bx,0x1000
    db 0E8h, 092h, 004h                   ; 0204: call 0x699
    db 08Bh, 0F8h                         ; 0207: mov di,ax
    db 026h, 0FEh, 005h                   ; 0209: inc byte [es:di]
    db 0E2h, 0F3h                         ; 020C: loop 0x201
    db 01Eh                               ; 020E: push ds
    db 007h                               ; 020F: pop es

; Generate 30 random sparkle positions used by texture 1 and end field.
generate_sparkle_positions:
    db 0B9h, 01Eh, 000h                   ; 0210: mov cx,0x1e
    db 0BFh, 0EDh, 041h                   ; 0213: mov di,0x41ed
sparkle_position_loop:
    db 0BBh, 000h, 001h                   ; 0216: mov bx,0x100
    db 0E8h, 07Dh, 004h                   ; 0219: call 0x699
    db 0AAh                               ; 021C: stosb
    db 0BBh, 0C0h, 00Eh                   ; 021D: mov bx,0xec0
    db 081h, 0C3h, 080h, 000h             ; 0220: add bx,0x80
    db 0E8h, 072h, 004h                   ; 0224: call 0x699
    db 005h, 040h, 000h                   ; 0227: add ax,0x40
    db 0ABh                               ; 022A: stosw
    db 0E2h, 0E9h                         ; 022B: loop 0x216
generate_texture0:
    db 08Eh, 006h, 04Ch, 042h             ; 022D: mov es,[0x424c]
    db 033h, 0FFh                         ; 0231: xor di,di
    db 0B9h, 000h, 010h                   ; 0233: mov cx,0x1000
generate_texture0_loop:
    db 08Bh, 0C7h                         ; 0236: mov ax,di
    db 0A8h, 008h                         ; 0238: test al,0x8
    db 07Eh, 002h                         ; 023A: jng 0x23e
    db 0F6h, 0D0h                         ; 023C: not al
loc_023E:
    db 024h, 00Fh                         ; 023E: and al,0xf
    db 08Bh, 0D8h                         ; 0240: mov bx,ax
    db 08Bh, 0C7h                         ; 0242: mov ax,di
    db 0C1h, 0E8h, 006h                   ; 0244: shr ax,byte 0x6
    db 0A8h, 008h                         ; 0247: test al,0x8
    db 07Eh, 002h                         ; 0249: jng 0x24d
    db 0F6h, 0D0h                         ; 024B: not al
loc_024D:
    db 024h, 00Fh                         ; 024D: and al,0xf
    db 03Ah, 0C3h                         ; 024F: cmp al,bl
    db 07Eh, 002h                         ; 0251: jng 0x255
    db 08Bh, 0C3h                         ; 0253: mov ax,bx
loc_0255:
    db 004h, 0E0h                         ; 0255: add al,0xe0
    db 0AAh                               ; 0257: stosb
    db 0E2h, 0DCh                         ; 0258: loop 0x236
derive_textures_from_noise_sources:
    db 0BEh, 005h, 010h                   ; 025A: mov si,0x1005
    db 0B2h, 004h                         ; 025D: mov dl,0x4
derive_texture_loop:
    db 00Fh, 0B6h, 0DAh                   ; 025F: movzx bx,dl
    db 08Eh, 087h, 04Ch, 042h             ; 0262: mov es,[bx+0x424c]
    db 0ADh                               ; 0266: lodsw
    db 08Ah, 0D8h                         ; 0267: mov bl,al
    db 08Eh, 0A7h, 04Ch, 042h             ; 0269: mov fs,[bx+0x424c]
    db 033h, 0FFh                         ; 026D: xor di,di
    db 0B9h, 000h, 010h                   ; 026F: mov cx,0x1000
copy_texture_noise_loop:
    db 064h, 08Ah, 005h                   ; 0272: mov al,[fs:di]
    db 002h, 0C4h                         ; 0275: add al,ah
    db 0AAh                               ; 0277: stosb
    db 0E2h, 0F8h                         ; 0278: loop 0x272
    db 042h                               ; 027A: inc dx
    db 042h                               ; 027B: inc dx
    db 080h, 0FAh, 01Eh                   ; 027C: cmp dl,0x1e
    db 07Eh, 0DEh                         ; 027F: jng 0x25f
apply_texture_rect_recipes:
    db 0B9h, 01Ah, 000h                   ; 0281: mov cx,0x1a
    db 0BEh, 069h, 00Fh                   ; 0284: mov si,0xf69
texture_rect_loop:
    db 051h                               ; 0287: push cx
    db 08Ah, 01Ch                         ; 0288: mov bl,[si]
    db 08Ah, 0D3h                         ; 028A: mov dl,bl
    db 0C0h, 0EAh, 004h                   ; 028C: shr dl,byte 0x4
    db 083h, 0E3h, 00Fh                   ; 028F: and bx,byte +0xf
    db 003h, 0DBh                         ; 0292: add bx,bx
    db 08Eh, 087h, 04Ch, 042h             ; 0294: mov es,[bx+0x424c]
    db 00Fh, 0B6h, 04Ch, 002h             ; 0298: movzx cx,[si+0x2]
texture_rect_y_loop:
    db 00Fh, 0B6h, 05Ch, 001h             ; 029C: movzx bx,[si+0x1]
texture_rect_x_loop:
    db 08Bh, 0F9h                         ; 02A0: mov di,cx
    db 0C1h, 0E7h, 006h                   ; 02A2: shl di,byte 0x6
    db 003h, 0FBh                         ; 02A5: add di,bx
    db 08Ah, 0C2h                         ; 02A7: mov al,dl
    db 0FEh, 0C8h                         ; 02A9: dec al
    db 074h, 013h                         ; 02AB: jz 0x2c0
    db 0FEh, 0C8h                         ; 02AD: dec al
    db 074h, 00Ch                         ; 02AF: jz 0x2bd
    db 08Bh, 0C3h                         ; 02B1: mov ax,bx
    db 003h, 0C1h                         ; 02B3: add ax,cx
    db 024h, 004h                         ; 02B5: and al,0x4
    db 074h, 002h                         ; 02B7: jz 0x2bb
    db 0B0h, 098h                         ; 02B9: mov al,0x98
loc_02BB:
    db 0EBh, 003h                         ; 02BB: jmp short 0x2c0
texture_rect_copy_old:
    db 026h, 08Ah, 005h                   ; 02BD: mov al,[es:di]
texture_rect_store:
    db 002h, 044h, 005h                   ; 02C0: add al,[si+0x5]
    db 026h, 088h, 005h                   ; 02C3: mov [es:di],al
    db 043h                               ; 02C6: inc bx
    db 03Ah, 05Ch, 003h                   ; 02C7: cmp bl,[si+0x3]
    db 07Eh, 0D4h                         ; 02CA: jng 0x2a0
    db 041h                               ; 02CC: inc cx
    db 03Ah, 04Ch, 004h                   ; 02CD: cmp cl,[si+0x4]
    db 07Eh, 0CAh                         ; 02D0: jng 0x29c
    db 083h, 0C6h, 006h                   ; 02D2: add si,byte +0x6
    db 059h                               ; 02D5: pop cx
    db 0E2h, 0AFh                         ; 02D6: loop 0x287
texture11_red_fade_dots:
    db 08Eh, 006h, 062h, 042h             ; 02D8: mov es,[0x4262]
    db 0BFh, 0FFh, 00Fh                   ; 02DC: mov di,0xfff
    db 0B9h, 014h, 000h                   ; 02DF: mov cx,0x14
    db 0B0h, 05Eh                         ; 02E2: mov al,0x5e
texture11_red_fade_row:
    db 051h                               ; 02E4: push cx
    db 0C1h, 0E1h, 003h                   ; 02E5: shl cx,byte 0x3
texture11_red_fade_dot:
    db 057h                               ; 02E8: push di
    db 050h                               ; 02E9: push ax
    db 0BBh, 040h, 000h                   ; 02EA: mov bx,0x40
    db 0E8h, 0A9h, 003h                   ; 02ED: call 0x699
    db 02Bh, 0F8h                         ; 02F0: sub di,ax
    db 058h                               ; 02F2: pop ax
    db 0AAh                               ; 02F3: stosb
    db 05Fh                               ; 02F4: pop di
    db 0E2h, 0F1h                         ; 02F5: loop 0x2e8
    db 059h                               ; 02F7: pop cx
    db 0FEh, 0C8h                         ; 02F8: dec al
    db 083h, 0EFh, 040h                   ; 02FA: sub di,byte +0x40
    db 0E2h, 0E5h                         ; 02FD: loop 0x2e4

; Build 128x256 lighting/fog/color lookup table at 4274h.
build_light_lookup_table:
    db 01Eh                               ; 02FF: push ds
    db 007h                               ; 0300: pop es
    db 0BFh, 074h, 042h                   ; 0301: mov di,0x4274
    db 032h, 0DBh                         ; 0304: xor bl,bl
loc_0306:
    db 0FEh, 0C3h                         ; 0306: inc bl
    db 033h, 0C9h                         ; 0308: xor cx,cx
loc_030A:
    db 08Ah, 0C1h                         ; 030A: mov al,cl
    db 024h, 01Fh                         ; 030C: and al,0x1f
    db 0F6h, 0E3h                         ; 030E: mul bl
    db 003h, 0C0h                         ; 0310: add ax,ax
    db 08Ah, 0C1h                         ; 0312: mov al,cl
    db 024h, 0E0h                         ; 0314: and al,0xe0
    db 002h, 0C4h                         ; 0316: add al,ah
    db 0AAh                               ; 0318: stosb
    db 0FEh, 0C1h                         ; 0319: inc cl
    db 080h, 0F9h, 0C0h                   ; 031B: cmp cl,0xc0
    db 075h, 0EAh                         ; 031E: jnz 0x30a
loc_0320:
    db 08Ah, 0C1h                         ; 0320: mov al,cl
    db 0AAh                               ; 0322: stosb
    db 0FEh, 0C1h                         ; 0323: inc cl
    db 075h, 0F9h                         ; 0325: jnz 0x320
    db 080h, 0FBh, 080h                   ; 0327: cmp bl,0x80
    db 075h, 0DAh                         ; 032A: jnz 0x306

; Save old IRQ vectors, install timer/keyboard handlers, seed backbuffer.
install_interrupts:
    db 089h, 026h, 08Ch, 033h             ; 032C: mov [0x338c],sp
    db 0B8h, 008h, 035h                   ; 0330: mov ax,0x3508
    db 0CDh, 021h                         ; 0333: int 0x21
    db 08Ch, 006h, 090h, 033h             ; 0335: mov [0x3390],es
    db 089h, 01Eh, 08Eh, 033h             ; 0339: mov [0x338e],bx
    db 0B8h, 008h, 025h                   ; 033D: mov ax,0x2508
    db 0BAh, 063h, 005h                   ; 0340: mov dx,0x563
    db 0CDh, 021h                         ; 0343: int 0x21
    db 0BBh, 051h, 00Dh                   ; 0345: mov bx,0xd51
    db 0E8h, 061h, 003h                   ; 0348: call 0x6ac
    db 0B8h, 009h, 035h                   ; 034B: mov ax,0x3509
    db 0CDh, 021h                         ; 034E: int 0x21
    db 08Ch, 006h, 094h, 033h             ; 0350: mov [0x3394],es
    db 089h, 01Eh, 092h, 033h             ; 0354: mov [0x3392],bx
    db 0B8h, 009h, 025h                   ; 0358: mov ax,0x2509
    db 0BAh, 002h, 006h                   ; 035B: mov dx,0x602
    db 0CDh, 021h                         ; 035E: int 0x21
    db 01Eh                               ; 0360: push ds
    db 08Eh, 006h, 04Ah, 042h             ; 0361: mov es,[0x424a]
    db 068h, 000h, 0A0h                   ; 0365: push word 0xa000
    db 01Fh                               ; 0368: pop ds
    db 0BEh, 040h, 006h                   ; 0369: mov si,0x640
    db 033h, 0FFh                         ; 036C: xor di,di
    db 0B9h, 000h, 07Dh                   ; 036E: mov cx,0x7d00
    db 0ACh                               ; 0371: lodsb
    db 0AAh                               ; 0372: stosb
    db 0AAh                               ; 0373: stosb
    db 0E2h, 0FBh                         ; 0374: loop 0x371
    db 01Fh                               ; 0376: pop ds

; Upload palette, consume timer ticks, animate, transform, sort, render, blit.
main_frame_loop:
    db 032h, 0C0h                         ; 0377: xor al,al
    db 0BAh, 0C8h, 003h                   ; 0379: mov dx,0x3c8
    db 0EEh                               ; 037C: out dx,al
    db 042h                               ; 037D: inc dx
    db 0BEh, 008h, 014h                   ; 037E: mov si,0x1408
    db 0B9h, 000h, 003h                   ; 0381: mov cx,0x300
    db 0F3h, 06Eh                         ; 0384: rep outsb
    db 08Bh, 00Eh, 004h, 014h             ; 0386: mov cx,[0x1404]
    db 0C7h, 006h, 004h, 014h, 000h, 000h ; 038A: mov word [0x1404],0x0
    db 00Bh, 0C9h                         ; 0390: or cx,cx
    db 00Fh, 084h, 087h, 000h             ; 0392: jz near 0x41d
process_ticks_loop:
    db 051h                               ; 0396: push cx
    db 0BEh, 0F6h, 013h                   ; 0397: mov si,0x13f6
    db 0FFh, 04Ch, 00Ah                   ; 039A: dec word [si+0xa]
    db 079h, 028h                         ; 039D: jns 0x3c7
    db 08Bh, 05Ch, 008h                   ; 039F: mov bx,[si+0x8]
    db 08Ah, 087h, 0E3h, 012h             ; 03A2: mov al,[bx+0x12e3]
    db 00Ah, 0C0h                         ; 03A6: or al,al
    db 00Fh, 084h, 07Ah, 001h             ; 03A8: jz near 0x526
    db 08Bh, 0D8h                         ; 03AC: mov bx,ax
    db 080h, 0E3h, 007h                   ; 03AE: and bl,0x7
    db 088h, 05Ch, 00Ch                   ; 03B1: mov [si+0xc],bl
    db 0FEh, 0CBh                         ; 03B4: dec bl
    db 075h, 004h                         ; 03B6: jnz 0x3bc
    db 0F7h, 01Eh, 060h, 013h             ; 03B8: neg word [0x1360]
loc_03BC:
    db 025h, 0F8h, 000h                   ; 03BC: and ax,0xf8
    db 003h, 0C0h                         ; 03BF: add ax,ax
    db 089h, 044h, 00Ah                   ; 03C1: mov [si+0xa],ax
    db 0FFh, 044h, 008h                   ; 03C4: inc word [si+0x8]
apply_scene_command:
    db 08Ah, 044h, 00Ch                   ; 03C7: mov al,[si+0xc]
    db 098h                               ; 03CA: cbw
    db 048h                               ; 03CB: dec ax
    db 075h, 007h                         ; 03CC: jnz 0x3d5
    db 08Bh, 01Eh, 060h, 013h             ; 03CE: mov bx,[0x1360]
    db 001h, 05Ch, 006h                   ; 03D2: add [si+0x6],bx
loc_03D5:
    db 0B9h, 003h, 000h                   ; 03D5: mov cx,0x3
    db 048h                               ; 03D8: dec ax
    db 075h, 002h                         ; 03D9: jnz 0x3dd
    db 0FFh, 004h                         ; 03DB: inc word [si]
loc_03DD:
    db 048h                               ; 03DD: dec ax
    db 075h, 002h                         ; 03DE: jnz 0x3e2
    db 0FFh, 00Ch                         ; 03E0: dec word [si]
loc_03E2:
    db 046h                               ; 03E2: inc si
    db 046h                               ; 03E3: inc si
    db 0E2h, 0F2h                         ; 03E4: loop 0x3d8
update_camera_position:
    db 0BEh, 0F8h, 013h                   ; 03E6: mov si,0x13f8
    db 0B1h, 003h                         ; 03E9: mov cl,0x3
    db 0ADh                               ; 03EB: lodsw
    db 0C1h, 0F8h, 002h                   ; 03EC: sar ax,byte 0x2
    db 050h                               ; 03EF: push ax
    db 0E2h, 0F9h                         ; 03F0: loop 0x3eb
    db 06Bh, 044h, 0FCh, 010h             ; 03F2: imul ax,[si-0x4],byte +0x10
    db 050h                               ; 03F6: push ax
    db 0E8h, 002h, 008h                   ; 03F7: call 0xbfc
    db 0B1h, 003h                         ; 03FA: mov cl,0x3
    db 033h, 0F6h                         ; 03FC: xor si,si
    db 0D9h, 084h, 0A2h, 013h             ; 03FE: fld dword [si+0x13a2]
    db 0DEh, 00Eh, 0F6h, 013h             ; 0402: fimul word [0x13f6]
    db 0DEh, 036h, 0D5h, 00Dh             ; 0406: fidiv word [0xdd5]
    db 0D8h, 084h, 07Eh, 013h             ; 040A: fadd dword [si+0x137e]
    db 0D9h, 09Ch, 07Eh, 013h             ; 040E: fstp dword [si+0x137e]
    db 083h, 0C6h, 004h                   ; 0412: add si,byte +0x4
    db 0E2h, 0E7h                         ; 0415: loop 0x3fe
    db 059h                               ; 0417: pop cx
    db 049h                               ; 0418: dec cx
    db 00Fh, 085h, 079h, 0FFh             ; 0419: jnz near 0x396

; Door/opening animation and once-only sparkle burst into source buffer.
animate_door_texture:
    db 0A1h, 062h, 013h                   ; 041D: mov ax,[0x1362]
    db 00Bh, 0C0h                         ; 0420: or ax,ax
    db 079h, 004h                         ; 0422: jns 0x428
    db 033h, 0C0h                         ; 0424: xor ax,ax
    db 0EBh, 02Fh                         ; 0426: jmp short 0x457
door_spark_once:
    db 080h, 03Eh, 003h, 014h, 000h       ; 0428: cmp byte [0x1403],0x0
    db 075h, 028h                         ; 042D: jnz 0x457
    db 0FEh, 006h, 003h, 014h             ; 042F: inc byte [0x1403]
    db 050h                               ; 0433: push ax
    db 08Eh, 006h, 04Ah, 042h             ; 0434: mov es,[0x424a]
    db 0B9h, 064h, 000h                   ; 0438: mov cx,0x64
    db 051h                               ; 043B: push cx
    db 0BBh, 0C0h, 0C1h                   ; 043C: mov bx,0xc1c0
    db 0E8h, 057h, 002h                   ; 043F: call 0x699
    db 005h, 000h, 019h                   ; 0442: add ax,0x1900
    db 08Bh, 0F8h                         ; 0445: mov di,ax
    db 080h, 0E4h, 007h                   ; 0447: and ah,0x7
    db 0BAh, 03Bh, 001h                   ; 044A: mov dx,0x13b
    db 0B9h, 002h, 000h                   ; 044D: mov cx,0x2
    db 0E8h, 0BEh, 001h                   ; 0450: call 0x611
    db 059h                               ; 0453: pop cx
    db 0E2h, 0E5h                         ; 0454: loop 0x43b
    db 058h                               ; 0456: pop ax
clamp_door_frame:
    db 03Dh, 018h, 000h                   ; 0457: cmp ax,0x18
    db 07Eh, 003h                         ; 045A: jng 0x45f
    db 0B8h, 018h, 000h                   ; 045C: mov ax,0x18
loc_045F:
    db 0C1h, 0E0h, 006h                   ; 045F: shl ax,byte 0x6
    db 01Eh                               ; 0462: push ds
    db 08Eh, 006h, 066h, 042h             ; 0463: mov es,[0x4266]
    db 08Eh, 01Eh, 06Ah, 042h             ; 0467: mov ds,[0x426a]
    db 08Bh, 0F0h                         ; 046B: mov si,ax
    db 033h, 0FFh                         ; 046D: xor di,di
    db 0B9h, 000h, 004h                   ; 046F: mov cx,0x400
    db 0F3h, 0A5h                         ; 0472: rep movsw
    db 0BEh, 000h, 008h                   ; 0474: mov si,0x800
    db 02Bh, 0F0h                         ; 0477: sub si,ax
    db 056h                               ; 0479: push si
    db 0B5h, 004h                         ; 047A: mov ch,0x4
    db 0F3h, 0A5h                         ; 047C: rep movsw
    db 05Fh                               ; 047E: pop di
    db 08Bh, 0C8h                         ; 047F: mov cx,ax
    db 033h, 0C0h                         ; 0481: xor ax,ax
    db 0F3h, 0ABh                         ; 0483: rep stosw
    db 01Fh                               ; 0485: pop ds
copy_backbuffer_to_texture_source:
    db 01Eh                               ; 0486: push ds
    db 08Eh, 006h, 048h, 042h             ; 0487: mov es,[0x4248]
    db 08Eh, 01Eh, 04Ah, 042h             ; 048B: mov ds,[0x424a]
    db 0E8h, 09Eh, 001h                   ; 048F: call 0x630
    db 01Fh                               ; 0492: pop ds
transform_vertices_and_render:
    db 08Bh, 00Eh, 068h, 017h             ; 0493: mov cx,[0x1768]
    db 0BEh, 06Ch, 017h                   ; 0497: mov si,0x176c
    db 0BFh, 054h, 0C4h                   ; 049A: mov di,0xc454
    db 0BBh, 0AEh, 013h                   ; 049D: mov bx,0x13ae
    db 0BAh, 003h, 000h                   ; 04A0: mov dx,0x3
loc_04A3:
    db 0DFh, 004h                         ; 04A3: fild word [si]
    db 0D8h, 026h, 07Eh, 013h             ; 04A5: fsub dword [0x137e]
    db 0D8h, 00Fh                         ; 04A9: fmul dword [bx]
    db 0DFh, 044h, 002h                   ; 04AB: fild word [si+0x2]
    db 0D8h, 026h, 082h, 013h             ; 04AE: fsub dword [0x1382]
    db 0D8h, 04Fh, 004h                   ; 04B2: fmul dword [bx+0x4]
    db 0DFh, 044h, 004h                   ; 04B5: fild word [si+0x4]
    db 0D8h, 026h, 086h, 013h             ; 04B8: fsub dword [0x1386]
    db 0D8h, 04Fh, 008h                   ; 04BC: fmul dword [bx+0x8]
    db 0DEh, 0C1h                         ; 04BF: faddp st1
    db 0DEh, 0C1h                         ; 04C1: faddp st1
    db 0D9h, 01Dh                         ; 04C3: fstp dword [di]
    db 083h, 0C7h, 004h                   ; 04C5: add di,byte +0x4
    db 083h, 0C3h, 00Ch                   ; 04C8: add bx,byte +0xc
    db 04Ah                               ; 04CB: dec dx
    db 075h, 0D5h                         ; 04CC: jnz 0x4a3
    db 083h, 0C6h, 008h                   ; 04CE: add si,byte +0x8
    db 0E2h, 0CAh                         ; 04D1: loop 0x49d

; Compute face depth keys and sort face records for painter-style rendering.
sort_faces_by_depth:
    db 01Eh                               ; 04D3: push ds
    db 007h                               ; 04D4: pop es
    db 0BFh, 014h, 0D7h                   ; 04D5: mov di,0xd714
    db 057h                               ; 04D8: push di
    db 0BEh, 0ECh, 023h                   ; 04D9: mov si,0x23ec
    db 08Bh, 0C6h                         ; 04DC: mov ax,si
    db 08Bh, 00Eh, 06Ah, 017h             ; 04DE: mov cx,[0x176a]
face_depth_loop:
    db 0D9h, 0EEh                         ; 04E2: fldz
    db 051h                               ; 04E4: push cx
    db 0B9h, 004h, 000h                   ; 04E5: mov cx,0x4
face_depth_vertex_loop:
    db 06Bh, 01Ch, 00Ch                   ; 04E8: imul bx,[si],byte +0xc
    db 046h                               ; 04EB: inc si
    db 046h                               ; 04EC: inc si
    db 0D8h, 0A7h, 05Ch, 0C4h             ; 04ED: fsub dword [bx-0x3ba4]
    db 0E2h, 0F5h                         ; 04F1: loop 0x4e8
    db 059h                               ; 04F3: pop cx
    db 0DFh, 01Dh                         ; 04F4: fistp word [di]
    db 047h                               ; 04F6: inc di
    db 047h                               ; 04F7: inc di
    db 0ABh                               ; 04F8: stosw
    db 005h, 00Ah, 000h                   ; 04F9: add ax,0xa
    db 046h                               ; 04FC: inc si
    db 046h                               ; 04FD: inc si
    db 0E2h, 0E2h                         ; 04FE: loop 0x4e2
render_sorted_faces:
    db 057h                               ; 0500: push di
    db 0E8h, 056h, 001h                   ; 0501: call 0x65a
    db 08Bh, 00Eh, 06Ah, 017h             ; 0504: mov cx,[0x176a]
    db 0BEh, 014h, 0D7h                   ; 0508: mov si,0xd714
render_face_loop:
    db 0ADh                               ; 050B: lodsw
    db 0ADh                               ; 050C: lodsw
    db 08Bh, 0D8h                         ; 050D: mov bx,ax
    db 060h                               ; 050F: pusha
    db 0E8h, 0F6h, 004h                   ; 0510: call 0xa09
    db 061h                               ; 0513: popa
    db 0E2h, 0F5h                         ; 0514: loop 0x50b
    db 01Eh                               ; 0516: push ds
    db 068h, 000h, 0A0h                   ; 0517: push word 0xa000
    db 007h                               ; 051A: pop es
    db 08Eh, 01Eh, 048h, 042h             ; 051B: mov ds,[0x4248]
    db 0E8h, 00Eh, 001h                   ; 051F: call 0x630
    db 01Fh                               ; 0522: pop ds
    db 0E9h, 051h, 0FEh                   ; 0523: jmp 0x377

; Restore interrupts, video mode, MIDI notes, and return to DOS.
shutdown_and_exit:
    db 00Eh                               ; 0526: push cs
    db 01Fh                               ; 0527: pop ds
    db 08Bh, 026h, 08Ch, 033h             ; 0528: mov sp,[0x338c]
    db 0B9h, 00Fh, 000h                   ; 052C: mov cx,0xf
    db 08Bh, 0C1h                         ; 052F: mov ax,cx
    db 004h, 0B0h                         ; 0531: add al,0xb0
    db 0E8h, 083h, 001h                   ; 0533: call 0x6b9
    db 0B0h, 07Bh                         ; 0536: mov al,0x7b
    db 0E8h, 07Eh, 001h                   ; 0538: call 0x6b9
    db 032h, 0C0h                         ; 053B: xor al,al
    db 0E8h, 079h, 001h                   ; 053D: call 0x6b9
    db 0E2h, 0EDh                         ; 0540: loop 0x52f
    db 01Eh                               ; 0542: push ds
    db 0B8h, 009h, 025h                   ; 0543: mov ax,0x2509
    db 0C5h, 016h, 092h, 033h             ; 0546: lds dx,[0x3392]
    db 0CDh, 021h                         ; 054A: int 0x21
    db 01Fh                               ; 054C: pop ds
    db 01Eh                               ; 054D: push ds
    db 033h, 0DBh                         ; 054E: xor bx,bx
    db 0E8h, 059h, 001h                   ; 0550: call 0x6ac
    db 0B8h, 008h, 025h                   ; 0553: mov ax,0x2508
    db 0C5h, 016h, 08Eh, 033h             ; 0556: lds dx,[0x338e]
    db 0CDh, 021h                         ; 055A: int 0x21
    db 01Fh                               ; 055C: pop ds
    db 0B8h, 003h, 000h                   ; 055D: mov ax,0x3
    db 0CDh, 010h                         ; 0560: int 0x10
    db 0C3h                               ; 0562: ret

; IRQ0 timer: drive MIDI sequencer, animation counters, texture sparkle updates.
irq0_timer_handler:
    db 060h                               ; 0563: pusha
    db 01Eh                               ; 0564: push ds
    db 006h                               ; 0565: push es
    db 00Eh                               ; 0566: push cs
    db 01Fh                               ; 0567: pop ds
    db 08Bh, 00Eh, 006h, 014h             ; 0568: mov cx,[0x1406]
    db 0BEh, 008h, 017h                   ; 056C: mov si,0x1708
irq0_midi_channel_loop:
    db 0FFh, 00Ch                         ; 056F: dec word [si]
    db 07Fh, 02Ch                         ; 0571: jg 0x59f
    db 08Bh, 044h, 002h                   ; 0573: mov ax,[si+0x2]
    db 004h, 080h                         ; 0576: add al,0x80
    db 0E8h, 051h, 001h                   ; 0578: call 0x6cc
    db 08Bh, 05Ch, 004h                   ; 057B: mov bx,[si+0x4]
    db 0B4h, 07Fh                         ; 057E: mov ah,0x7f
    db 080h, 03Fh, 000h                   ; 0580: cmp byte [bx],0x0
    db 074h, 014h                         ; 0583: jz 0x599
    db 08Ah, 027h                         ; 0585: mov ah,[bx]
    db 088h, 064h, 003h                   ; 0587: mov [si+0x3],ah
    db 08Ah, 044h, 002h                   ; 058A: mov al,[si+0x2]
    db 004h, 090h                         ; 058D: add al,0x90
    db 0E8h, 03Ah, 001h                   ; 058F: call 0x6cc
    db 08Ah, 047h, 001h                   ; 0592: mov al,[bx+0x1]
    db 0B3h, 01Dh                         ; 0595: mov bl,0x1d
    db 0F6h, 0E3h                         ; 0597: mul bl
irq0_channel_done:
    db 089h, 004h                         ; 0599: mov [si],ax
    db 083h, 044h, 004h, 002h             ; 059B: add word [si+0x4],byte +0x2
loc_059F:
    db 083h, 0C6h, 006h                   ; 059F: add si,byte +0x6
    db 0E2h, 0CBh                         ; 05A2: loop 0x56f
irq0_update_animation_counters:
    db 0FFh, 006h, 004h, 014h             ; 05A4: inc word [0x1404]
    db 0FEh, 006h, 047h, 042h             ; 05A8: inc byte [0x4247]
    db 080h, 026h, 047h, 042h, 007h       ; 05AC: and byte [0x4247],0x7
    db 075h, 047h                         ; 05B1: jnz 0x5fa
irq0_update_texture1_sparkles:
    db 01Eh                               ; 05B3: push ds
    db 007h                               ; 05B4: pop es
    db 0BFh, 048h, 016h                   ; 05B5: mov di,0x1648
    db 08Bh, 0F7h                         ; 05B8: mov si,di
    db 0ADh                               ; 05BA: lodsw
    db 046h                               ; 05BB: inc si
    db 0B9h, 05Dh, 000h                   ; 05BC: mov cx,0x5d
    db 0F3h, 0A4h                         ; 05BF: rep movsb
    db 0ABh                               ; 05C1: stosw
    db 08Eh, 006h, 04Eh, 042h             ; 05C2: mov es,[0x424e]
    db 0E8h, 015h, 001h                   ; 05C6: call 0x6de
    db 0B1h, 01Eh                         ; 05C9: mov cl,0x1e
    db 0BBh, 0EDh, 041h                   ; 05CB: mov bx,0x41ed
irq0_sparkle_loop:
    db 0FEh, 00Fh                         ; 05CE: dec byte [bx]
    db 08Ah, 027h                         ; 05D0: mov ah,[bx]
    db 080h, 0E4h, 03Fh                   ; 05D2: and ah,0x3f
    db 080h, 0FCh, 01Fh                   ; 05D5: cmp ah,0x1f
    db 076h, 005h                         ; 05D8: jna 0x5df
    db 0F6h, 0D4h                         ; 05DA: not ah
    db 080h, 0E4h, 01Fh                   ; 05DC: and ah,0x1f
loc_05DF:
    db 0D0h, 0ECh                         ; 05DF: shr ah,1
    db 08Bh, 07Fh, 001h                   ; 05E1: mov di,[bx+0x1]
    db 051h                               ; 05E4: push cx
    db 053h                               ; 05E5: push bx
    db 0BAh, 03Bh, 000h                   ; 05E6: mov dx,0x3b
    db 0B9h, 000h, 0E0h                   ; 05E9: mov cx,0xe000
    db 0E8h, 022h, 000h                   ; 05EC: call 0x611
    db 05Bh                               ; 05EF: pop bx
    db 059h                               ; 05F0: pop cx
    db 083h, 0C3h, 003h                   ; 05F1: add bx,byte +0x3
    db 0E2h, 0D8h                         ; 05F4: loop 0x5ce
    db 0FFh, 006h, 062h, 013h             ; 05F6: inc word [0x1362]
irq0_ack:
    db 0B0h, 020h                         ; 05FA: mov al,0x20
    db 0E6h, 020h                         ; 05FC: out 0x20,al
    db 007h                               ; 05FE: pop es
    db 01Fh                               ; 05FF: pop ds
    db 061h                               ; 0600: popa
    db 0CFh                               ; 0601: iret

; IRQ1 keyboard handler: Esc exits by jumping into shutdown.
irq1_keyboard_handler:
    db 050h                               ; 0602: push ax
    db 0B0h, 020h                         ; 0603: mov al,0x20
    db 0E6h, 020h                         ; 0605: out 0x20,al
    db 0E4h, 060h                         ; 0607: in al,0x60
    db 0FEh, 0C8h                         ; 0609: dec al
    db 058h                               ; 060B: pop ax
    db 00Fh, 084h, 016h, 0FFh             ; 060C: jz near 0x526
    db 0CFh                               ; 0610: iret

; Draw reusable 5x5 brightness sprite, used for sparkles/stars.
draw_5x5_sprite:
    db 0BEh, 021h, 010h                   ; 0611: mov si,0x1021
    db 0B3h, 005h                         ; 0614: mov bl,0x5
draw_5x5_row:
    db 0B7h, 005h                         ; 0616: mov bh,0x5
draw_5x5_pixel_loop:
    db 0ACh                               ; 0618: lodsb
    db 02Ah, 0C4h                         ; 0619: sub al,ah
    db 07Eh, 007h                         ; 061B: jng 0x624
    db 002h, 0C5h                         ; 061D: add al,ch
    db 0D2h, 0E0h                         ; 061F: shl al,cl
    db 026h, 088h, 005h                   ; 0621: mov [es:di],al
draw_5x5_next_pixel:
    db 047h                               ; 0624: inc di
    db 0FEh, 0CFh                         ; 0625: dec bh
    db 075h, 0EFh                         ; 0627: jnz 0x618
    db 003h, 0FAh                         ; 0629: add di,dx
    db 0FEh, 0CBh                         ; 062B: dec bl
    db 075h, 0E7h                         ; 062D: jnz 0x616
    db 0C3h                               ; 062F: ret
copy_64000_bytes:
    db 033h, 0FFh                         ; 0630: xor di,di
    db 033h, 0F6h                         ; 0632: xor si,si
    db 0B9h, 080h, 03Eh                   ; 0634: mov cx,0x3e80
    db 0F3h, 066h, 0A5h                   ; 0637: rep movsd
    db 0C3h                               ; 063A: ret

; Small recursive stream expander used for MIDI/asset data.
decode_rle_or_script:
    db 08Ah, 00Ch                         ; 063B: mov cl,[si]
    db 00Ah, 0C9h                         ; 063D: or cl,cl
    db 074h, 015h                         ; 063F: jz 0x656
    db 079h, 010h                         ; 0641: jns 0x653
decode_nested_repeat:
    db 051h                               ; 0643: push cx
    db 056h                               ; 0644: push si
    db 046h                               ; 0645: inc si
    db 0E8h, 0F2h, 0FFh                   ; 0646: call 0x63b
    db 05Eh                               ; 0649: pop si
    db 059h                               ; 064A: pop cx
    db 0FEh, 0C1h                         ; 064B: inc cl
    db 075h, 0F4h                         ; 064D: jnz 0x643
    db 08Bh, 0F0h                         ; 064F: mov si,ax
    db 0EBh, 0E8h                         ; 0651: jmp short 0x63b
decode_copy_word:
    db 0A5h                               ; 0653: movsw
    db 0EBh, 0E5h                         ; 0654: jmp short 0x63b
decode_end_block:
    db 046h                               ; 0656: inc si
    db 08Bh, 0C6h                         ; 0657: mov ax,si
    db 0C3h                               ; 0659: ret

; In-place quicksort of 4-byte face records by depth key.
quicksort_faces:
    db 058h                               ; 065A: pop ax
    db 059h                               ; 065B: pop cx
    db 05Bh                               ; 065C: pop bx
    db 050h                               ; 065D: push ax
    db 03Bh, 0CBh                         ; 065E: cmp cx,bx
    db 07Eh, 036h                         ; 0660: jng 0x698
    db 08Bh, 0F3h                         ; 0662: mov si,bx
    db 08Bh, 0F9h                         ; 0664: mov di,cx
    db 08Bh, 014h                         ; 0666: mov dx,[si]
qsort_scan_left:
    db 039h, 014h                         ; 0668: cmp [si],dx
    db 07Eh, 005h                         ; 066A: jng 0x671
    db 083h, 0C6h, 004h                   ; 066C: add si,byte +0x4
    db 0EBh, 0F7h                         ; 066F: jmp short 0x668
qsort_scan_right:
    db 039h, 015h                         ; 0671: cmp [di],dx
    db 07Dh, 005h                         ; 0673: jnl 0x67a
    db 083h, 0EFh, 004h                   ; 0675: sub di,byte +0x4
    db 0EBh, 0F7h                         ; 0678: jmp short 0x671
qsort_maybe_swap:
    db 03Bh, 0F7h                         ; 067A: cmp si,di
    db 07Fh, 00Ch                         ; 067C: jg 0x68a
    db 066h, 0ADh                         ; 067E: lodsd
    db 066h, 087h, 005h                   ; 0680: xchg [di],eax
    db 066h, 089h, 044h, 0FCh             ; 0683: mov [si-0x4],eax
    db 083h, 0EFh, 004h                   ; 0687: sub di,byte +0x4
qsort_partition_done:
    db 03Bh, 0F7h                         ; 068A: cmp si,di
    db 07Eh, 0DAh                         ; 068C: jng 0x668
    db 056h                               ; 068E: push si
    db 051h                               ; 068F: push cx
    db 053h                               ; 0690: push bx
    db 057h                               ; 0691: push di
    db 0E8h, 0C5h, 0FFh                   ; 0692: call 0x65a
    db 0E8h, 0C2h, 0FFh                   ; 0695: call 0x65a
loc_0698:
    db 0C3h                               ; 0698: ret

; LCG random generator, returns AX in range 0..BX-1.
random_bounded:
    db 0BEh, 0DBh, 00Dh                   ; 0699: mov si,0xddb
    db 066h, 0ADh                         ; 069C: lodsd
    db 066h, 0F7h, 024h                   ; 069E: mul dword [si]
    db 066h, 040h                         ; 06A1: inc eax
    db 066h, 089h, 004h                   ; 06A3: mov [si],eax
    db 0ADh                               ; 06A6: lodsw
    db 0ADh                               ; 06A7: lodsw
    db 0F7h, 0E3h                         ; 06A8: mul bx
    db 092h                               ; 06AA: xchg ax,dx
    db 0C3h                               ; 06AB: ret
program_pit:
    db 0B0h, 036h                         ; 06AC: mov al,0x36
    db 0E6h, 043h                         ; 06AE: out 0x43,al
    db 08Ah, 0C3h                         ; 06B0: mov al,bl
    db 0E6h, 040h                         ; 06B2: out 0x40,al
    db 08Ah, 0C7h                         ; 06B4: mov al,bh
    db 0E6h, 040h                         ; 06B6: out 0x40,al
    db 0C3h                               ; 06B8: ret
mpu_send_byte:
    db 0BAh, 031h, 003h                   ; 06B9: mov dx,0x331
    db 050h                               ; 06BC: push ax
    db 033h, 0C0h                         ; 06BD: xor ax,ax
loc_06BF:
    db 0FEh, 0CCh                         ; 06BF: dec ah
    db 074h, 005h                         ; 06C1: jz 0x6c8
    db 0ECh                               ; 06C3: in al,dx
    db 0A8h, 040h                         ; 06C4: test al,0x40
    db 075h, 0F7h                         ; 06C6: jnz 0x6bf
loc_06C8:
    db 058h                               ; 06C8: pop ax
    db 04Ah                               ; 06C9: dec dx
    db 0EEh                               ; 06CA: out dx,al
    db 0C3h                               ; 06CB: ret
midi_note_off:
    db 0E8h, 006h, 000h                   ; 06CC: call 0x6d5
    db 0B0h, 07Fh                         ; 06CF: mov al,0x7f
    db 0E8h, 0E5h, 0FFh                   ; 06D1: call 0x6b9
    db 0C3h                               ; 06D4: ret
midi_send_word:
    db 0E8h, 0E1h, 0FFh                   ; 06D5: call 0x6b9
    db 08Ah, 0C4h                         ; 06D8: mov al,ah
    db 0E8h, 0DCh, 0FFh                   ; 06DA: call 0x6b9
    db 0C3h                               ; 06DD: ret
clear_texture_zero_ax:
    db 033h, 0C0h                         ; 06DE: xor ax,ax
clear_texture:
    db 033h, 0FFh                         ; 06E0: xor di,di
    db 0B9h, 000h, 010h                   ; 06E2: mov cx,0x1000
    db 0F3h, 0AAh                         ; 06E5: rep stosb
    db 0C3h                               ; 06E7: ret

; Generate circle/noise texture into ES:0000. Args: radius, iteration count.
generate_circle_noise_texture:
    db 055h                               ; 06E8: push bp
    db 08Bh, 0ECh                         ; 06E9: mov bp,sp
    db 08Eh, 087h, 04Ch, 042h             ; 06EB: mov es,[bx+0x424c]
    db 0E8h, 0ECh, 0FFh                   ; 06EF: call 0x6de
    db 0BEh, 0ADh, 041h                   ; 06F2: mov si,0x41ad
    db 08Bh, 056h, 004h                   ; 06F5: mov dx,[bp+0x4]
    db 08Ah, 0C2h                         ; 06F8: mov al,dl
    db 0F6h, 0EAh                         ; 06FA: imul dl
    db 08Bh, 0F8h                         ; 06FC: mov di,ax
    db 08Bh, 0CAh                         ; 06FE: mov cx,dx
    db 003h, 0C9h                         ; 0700: add cx,cx
circle_width_loop:
    db 08Ah, 0C2h                         ; 0702: mov al,dl
    db 0F6h, 0EAh                         ; 0704: imul dl
    db 0F7h, 0D8h                         ; 0706: neg ax
    db 003h, 0C7h                         ; 0708: add ax,di
    db 089h, 004h                         ; 070A: mov [si],ax
    db 0DFh, 004h                         ; 070C: fild word [si]
    db 0D9h, 0FAh                         ; 070E: fsqrt
    db 0DFh, 01Ch                         ; 0710: fistp word [si]
    db 046h                               ; 0712: inc si
    db 046h                               ; 0713: inc si
    db 04Ah                               ; 0714: dec dx
    db 0E2h, 0EBh                         ; 0715: loop 0x702
    db 08Bh, 04Eh, 006h                   ; 0717: mov cx,[bp+0x6]
circle_noise_iteration_loop:
    db 051h                               ; 071A: push cx
    db 0BBh, 000h, 010h                   ; 071B: mov bx,0x1000
    db 0E8h, 078h, 0FFh                   ; 071E: call 0x699
    db 08Bh, 0F8h                         ; 0721: mov di,ax
    db 0BEh, 0ADh, 041h                   ; 0723: mov si,0x41ad
    db 08Bh, 04Eh, 004h                   ; 0726: mov cx,[bp+0x4]
    db 003h, 0C9h                         ; 0729: add cx,cx
circle_noise_row_loop:
    db 051h                               ; 072B: push cx
    db 0ADh                               ; 072C: lodsw
    db 08Bh, 0C8h                         ; 072D: mov cx,ax
    db 003h, 0C9h                         ; 072F: add cx,cx
    db 074h, 00Eh                         ; 0731: jz 0x741
    db 057h                               ; 0733: push di
    db 02Bh, 0F8h                         ; 0734: sub di,ax
circle_noise_span_loop:
    db 081h, 0E7h, 0FFh, 00Fh             ; 0736: and di,0xfff
    db 026h, 0FEh, 005h                   ; 073A: inc byte [es:di]
    db 047h                               ; 073D: inc di
    db 0E2h, 0F6h                         ; 073E: loop 0x736
    db 05Fh                               ; 0740: pop di
loc_0741:
    db 083h, 0C7h, 040h                   ; 0741: add di,byte +0x40
    db 059h                               ; 0744: pop cx
    db 0E2h, 0E4h                         ; 0745: loop 0x72b
    db 059h                               ; 0747: pop cx
    db 0E2h, 0D0h                         ; 0748: loop 0x71a
    db 05Dh                               ; 074A: pop bp
    db 0C2h, 004h, 000h                   ; 074B: ret 0x4

; Core soft rasterizer: clipping/bounds, perspective-correct texture setup, scanline draw.
draw_polygon_scanlines:
    db 0C8h, 096h, 000h, 000h             ; 074E: enter 0x96,0x0
    db 0B8h, 001h, 080h                   ; 0752: mov ax,0x8001
    db 08Bh, 0D8h                         ; 0755: mov bx,ax
    db 08Bh, 0F0h                         ; 0757: mov si,ax
    db 0F7h, 0D8h                         ; 0759: neg ax
    db 08Bh, 0D0h                         ; 075B: mov dx,ax
    db 08Bh, 07Eh, 008h                   ; 075D: mov di,[bp+0x8]
    db 033h, 0C9h                         ; 0760: xor cx,cx
raster_bounds_loop:
    db 03Bh, 045h, 012h                   ; 0762: cmp ax,[di+0x12]
    db 07Eh, 003h                         ; 0765: jng 0x76a
    db 08Bh, 045h, 012h                   ; 0767: mov ax,[di+0x12]
loc_076A:
    db 03Bh, 05Dh, 012h                   ; 076A: cmp bx,[di+0x12]
    db 07Dh, 003h                         ; 076D: jnl 0x772
    db 08Bh, 05Dh, 012h                   ; 076F: mov bx,[di+0x12]
loc_0772:
    db 03Bh, 055h, 00Ch                   ; 0772: cmp dx,[di+0xc]
    db 07Eh, 00Bh                         ; 0775: jng 0x782
    db 08Bh, 055h, 00Ch                   ; 0777: mov dx,[di+0xc]
    db 089h, 08Eh, 07Ch, 0FFh             ; 077A: mov [bp-0x84],cx
    db 089h, 08Eh, 07Ah, 0FFh             ; 077E: mov [bp-0x86],cx
loc_0782:
    db 03Bh, 075h, 00Ch                   ; 0782: cmp si,[di+0xc]
    db 07Dh, 003h                         ; 0785: jnl 0x78a
    db 08Bh, 075h, 00Ch                   ; 0787: mov si,[di+0xc]
loc_078A:
    db 083h, 0C7h, 024h                   ; 078A: add di,byte +0x24
    db 041h                               ; 078D: inc cx
    db 03Bh, 04Eh, 006h                   ; 078E: cmp cx,[bp+0x6]
    db 075h, 0CFh                         ; 0791: jnz 0x762
    db 083h, 0FBh, 000h                   ; 0793: cmp bx,byte +0x0
    db 00Fh, 08Ch, 021h, 002h             ; 0796: jl near 0x9bb
    db 03Dh, 040h, 001h                   ; 079A: cmp ax,0x140
    db 00Fh, 08Fh, 01Ah, 002h             ; 079D: jg near 0x9bb
    db 083h, 0FEh, 015h                   ; 07A1: cmp si,byte +0x15
    db 00Fh, 08Ch, 013h, 002h             ; 07A4: jl near 0x9bb
    db 081h, 0FAh, 0B3h, 000h             ; 07A8: cmp dx,0xb3
    db 00Fh, 08Fh, 00Bh, 002h             ; 07AC: jg near 0x9bb
    db 089h, 056h, 082h                   ; 07B0: mov [bp-0x7e],dx
    db 089h, 076h, 080h                   ; 07B3: mov [bp-0x80],si
    db 081h, 07Eh, 080h, 0B3h, 000h       ; 07B6: cmp word [bp-0x80],0xb3
    db 07Eh, 005h                         ; 07BB: jng 0x7c2
    db 0C7h, 046h, 080h, 0B3h, 000h       ; 07BD: mov word [bp-0x80],0xb3
loc_07C2:
    db 08Bh, 046h, 082h                   ; 07C2: mov ax,[bp-0x7e]
    db 03Bh, 046h, 080h                   ; 07C5: cmp ax,[bp-0x80]
    db 00Fh, 084h, 0EFh, 001h             ; 07C8: jz near 0x9bb
    db 089h, 086h, 07Eh, 0FFh             ; 07CC: mov [bp-0x82],ax
    db 08Bh, 05Eh, 004h                   ; 07D0: mov bx,[bp+0x4]
    db 003h, 0DBh                         ; 07D3: add bx,bx
    db 08Eh, 006h, 048h, 042h             ; 07D5: mov es,[0x4248]
    db 08Eh, 0A7h, 04Ch, 042h             ; 07D9: mov fs,[bx+0x424c]
raster_y_loop:
    db 08Bh, 086h, 07Eh, 0FFh             ; 07DD: mov ax,[bp-0x82]
    db 03Bh, 046h, 080h                   ; 07E1: cmp ax,[bp-0x80]
    db 00Fh, 08Fh, 0D3h, 001h             ; 07E4: jg near 0x9bb
raster_left_edge_advance:
    db 08Bh, 086h, 07Eh, 0FFh             ; 07E8: mov ax,[bp-0x82]
    db 03Bh, 046h, 080h                   ; 07EC: cmp ax,[bp-0x80]
    db 07Dh, 025h                         ; 07EF: jnl 0x816
    db 08Bh, 076h, 008h                   ; 07F1: mov si,[bp+0x8]
    db 06Bh, 09Eh, 07Ch, 0FFh, 024h       ; 07F4: imul bx,[bp-0x84],byte +0x24
    db 003h, 0F3h                         ; 07F9: add si,bx
    db 03Bh, 044h, 00Ch                   ; 07FB: cmp ax,[si+0xc]
    db 075h, 016h                         ; 07FE: jnz 0x816
    db 08Bh, 09Eh, 07Ch, 0FFh             ; 0800: mov bx,[bp-0x84]
    db 04Bh                               ; 0804: dec bx
    db 07Dh, 004h                         ; 0805: jnl 0x80b
    db 08Bh, 05Eh, 006h                   ; 0807: mov bx,[bp+0x6]
    db 04Bh                               ; 080A: dec bx
loc_080B:
    db 089h, 09Eh, 07Ch, 0FFh             ; 080B: mov [bp-0x84],bx
    db 033h, 0FFh                         ; 080F: xor di,di
    db 0E8h, 0ABh, 001h                   ; 0811: call 0x9bf
    db 0EBh, 0D2h                         ; 0814: jmp short 0x7e8
raster_right_edge_advance:
    db 08Bh, 086h, 07Eh, 0FFh             ; 0816: mov ax,[bp-0x82]
    db 03Bh, 046h, 080h                   ; 081A: cmp ax,[bp-0x80]
    db 07Dh, 027h                         ; 081D: jnl 0x846
    db 08Bh, 076h, 008h                   ; 081F: mov si,[bp+0x8]
    db 06Bh, 09Eh, 07Ah, 0FFh, 024h       ; 0822: imul bx,[bp-0x86],byte +0x24
    db 003h, 0F3h                         ; 0827: add si,bx
    db 03Bh, 044h, 00Ch                   ; 0829: cmp ax,[si+0xc]
    db 075h, 018h                         ; 082C: jnz 0x846
    db 08Bh, 09Eh, 07Ah, 0FFh             ; 082E: mov bx,[bp-0x86]
    db 043h                               ; 0832: inc bx
    db 03Bh, 05Eh, 006h                   ; 0833: cmp bx,[bp+0x6]
    db 07Ch, 002h                         ; 0836: jl 0x83a
    db 033h, 0DBh                         ; 0838: xor bx,bx
loc_083A:
    db 089h, 09Eh, 07Ah, 0FFh             ; 083A: mov [bp-0x86],bx
    db 0BFh, 014h, 000h                   ; 083E: mov di,0x14
    db 0E8h, 07Bh, 001h                   ; 0841: call 0x9bf
    db 0EBh, 0D0h                         ; 0844: jmp short 0x816
raster_draw_scanline:
    db 083h, 0BEh, 07Eh, 0FFh, 015h       ; 0846: cmp word [bp-0x82],byte +0x15
    db 00Fh, 08Ch, 055h, 001h             ; 084B: jl near 0x9a4
    db 066h, 033h, 0DBh                   ; 084F: xor ebx,ebx
    db 066h, 033h, 0C9h                   ; 0852: xor ecx,ecx
    db 08Bh, 05Eh, 0C6h                   ; 0855: mov bx,[bp-0x3a]
    db 089h, 05Eh, 086h                   ; 0858: mov [bp-0x7a],bx
    db 08Bh, 04Eh, 0DAh                   ; 085B: mov cx,[bp-0x26]
    db 089h, 04Eh, 084h                   ; 085E: mov [bp-0x7c],cx
    db 02Bh, 0CBh                         ; 0861: sub cx,bx
    db 00Fh, 084h, 03Dh, 001h             ; 0863: jz near 0x9a4
    db 083h, 07Eh, 084h, 000h             ; 0867: cmp word [bp-0x7c],byte +0x0
    db 00Fh, 08Eh, 035h, 001h             ; 086B: jng near 0x9a4
    db 081h, 07Eh, 086h, 040h, 001h       ; 086F: cmp word [bp-0x7a],0x140
    db 00Fh, 08Fh, 02Ch, 001h             ; 0874: jg near 0x9a4
    db 0F7h, 0DBh                         ; 0878: neg bx
    db 079h, 004h                         ; 087A: jns 0x880
    db 033h, 0DBh                         ; 087C: xor bx,bx
    db 0EBh, 005h                         ; 087E: jmp short 0x885
loc_0880:
    db 0C7h, 046h, 086h, 000h, 000h       ; 0880: mov word [bp-0x7a],0x0
loc_0885:
    db 0BFh, 010h, 000h                   ; 0885: mov di,0x10
raster_clip_left_interpolate_loop:
    db 066h, 08Bh, 043h, 0D8h             ; 0888: mov eax,[bp+di-0x28]
    db 066h, 02Bh, 043h, 0C4h             ; 088C: sub eax,[bp+di-0x3c]
    db 066h, 099h                         ; 0890: cdq
    db 0E3h, 007h                         ; 0892: jcxz 0x89b
    db 066h, 0F7h, 0F9h                   ; 0894: idiv ecx
    db 066h, 089h, 043h, 0B0h             ; 0897: mov [bp+di-0x50],eax
loc_089B:
    db 066h, 08Bh, 043h, 0B0h             ; 089B: mov eax,[bp+di-0x50]
    db 066h, 0F7h, 0EBh                   ; 089F: imul ebx
    db 066h, 003h, 043h, 0C4h             ; 08A2: add eax,[bp+di-0x3c]
    db 066h, 089h, 043h, 0ECh             ; 08A6: mov [bp+di-0x14],eax
    db 083h, 0EFh, 004h                   ; 08AA: sub di,byte +0x4
    db 075h, 0D9h                         ; 08AD: jnz 0x888
    db 08Bh, 046h, 0C0h                   ; 08AF: mov ax,[bp-0x40]
    db 02Eh, 0A3h, 08Dh, 009h             ; 08B2: mov [cs:0x98d],ax
    db 081h, 07Eh, 084h, 040h, 001h       ; 08B6: cmp word [bp-0x7c],0x140
    db 07Eh, 005h                         ; 08BB: jng 0x8c2
    db 0C7h, 046h, 084h, 040h, 001h       ; 08BD: mov word [bp-0x7c],0x140
loc_08C2:
    db 069h, 0BEh, 07Eh, 0FFh, 040h, 001h ; 08C2: imul di,[bp-0x82],word 0x140
    db 003h, 07Eh, 086h                   ; 08C8: add di,[bp-0x7a]
    db 0BBh, 000h, 001h                   ; 08CB: mov bx,0x100
    db 066h, 08Bh, 046h, 0F0h             ; 08CE: mov eax,[bp-0x10]
    db 066h, 0F7h, 0EBh                   ; 08D2: imul ebx
    db 066h, 0F7h, 07Eh, 0F8h             ; 08D5: idiv dword [bp-0x8]
    db 089h, 086h, 074h, 0FFh             ; 08D9: mov [bp-0x8c],ax
    db 066h, 08Bh, 046h, 0F4h             ; 08DD: mov eax,[bp-0xc]
    db 066h, 0F7h, 0EBh                   ; 08E1: imul ebx
    db 066h, 0F7h, 07Eh, 0F8h             ; 08E4: idiv dword [bp-0x8]
    db 089h, 086h, 072h, 0FFh             ; 08E8: mov [bp-0x8e],ax
raster_span_chunk_loop:
    db 08Bh, 04Eh, 084h                   ; 08EC: mov cx,[bp-0x7c]
    db 02Bh, 04Eh, 086h                   ; 08EF: sub cx,[bp-0x7a]
    db 00Fh, 08Eh, 0AEh, 000h             ; 08F2: jng near 0x9a4
    db 083h, 0F9h, 010h                   ; 08F6: cmp cx,byte +0x10
    db 07Eh, 003h                         ; 08F9: jng 0x8fe
    db 0B9h, 010h, 000h                   ; 08FB: mov cx,0x10
loc_08FE:
    db 066h, 08Bh, 086h, 072h, 0FFh       ; 08FE: mov eax,[bp-0x8e]
    db 066h, 089h, 086h, 076h, 0FFh       ; 0903: mov [bp-0x8a],eax
    db 066h, 08Bh, 046h, 0B4h             ; 0908: mov eax,[bp-0x4c]
    db 066h, 0F7h, 0E9h                   ; 090C: imul ecx
    db 066h, 001h, 046h, 0F0h             ; 090F: add [bp-0x10],eax
    db 066h, 08Bh, 046h, 0B8h             ; 0913: mov eax,[bp-0x48]
    db 066h, 0F7h, 0E9h                   ; 0917: imul ecx
    db 066h, 001h, 046h, 0F4h             ; 091A: add [bp-0xc],eax
    db 066h, 08Bh, 046h, 0BCh             ; 091E: mov eax,[bp-0x44]
    db 066h, 0F7h, 0E9h                   ; 0922: imul ecx
    db 066h, 001h, 046h, 0F8h             ; 0925: add [bp-0x8],eax
    db 0BBh, 000h, 001h                   ; 0929: mov bx,0x100
    db 066h, 08Bh, 046h, 0F0h             ; 092C: mov eax,[bp-0x10]
    db 066h, 0F7h, 0EBh                   ; 0930: imul ebx
    db 066h, 0F7h, 07Eh, 0F8h             ; 0933: idiv dword [bp-0x8]
    db 089h, 086h, 074h, 0FFh             ; 0937: mov [bp-0x8c],ax
    db 066h, 08Bh, 046h, 0F4h             ; 093B: mov eax,[bp-0xc]
    db 066h, 0F7h, 0EBh                   ; 093F: imul ebx
    db 066h, 0F7h, 07Eh, 0F8h             ; 0942: idiv dword [bp-0x8]
    db 089h, 086h, 072h, 0FFh             ; 0946: mov [bp-0x8e],ax
    db 08Bh, 086h, 074h, 0FFh             ; 094A: mov ax,[bp-0x8c]
    db 02Bh, 086h, 078h, 0FFh             ; 094E: sub ax,[bp-0x88]
    db 099h                               ; 0952: cwd
    db 0F7h, 0F9h                         ; 0953: idiv cx
    db 02Eh, 0A3h, 091h, 009h             ; 0955: mov [cs:0x991],ax
    db 08Bh, 086h, 072h, 0FFh             ; 0959: mov ax,[bp-0x8e]
    db 02Bh, 086h, 076h, 0FFh             ; 095D: sub ax,[bp-0x8a]
    db 099h                               ; 0961: cwd
    db 0F7h, 0F9h                         ; 0962: idiv cx
    db 02Eh, 0A3h, 095h, 009h             ; 0964: mov [cs:0x995],ax
    db 08Bh, 0B6h, 076h, 0FFh             ; 0968: mov si,[bp-0x8a]
    db 08Bh, 096h, 078h, 0FFh             ; 096C: mov dx,[bp-0x88]
    db 08Bh, 046h, 0FCh                   ; 0970: mov ax,[bp-0x4]
raster_pixel_loop:
    db 08Bh, 0DEh                         ; 0973: mov bx,si
    db 032h, 0DBh                         ; 0975: xor bl,bl
    db 0C1h, 0EBh, 002h                   ; 0977: shr bx,byte 0x2
    db 002h, 0DEh                         ; 097A: add bl,dh
    db 064h, 08Ah, 01Fh                   ; 097C: mov bl,[fs:bx]
    db 00Ah, 0DBh                         ; 097F: or bl,bl
    db 074h, 009h                         ; 0981: jz 0x98c
    db 08Ah, 0FCh                         ; 0983: mov bh,ah
    db 08Ah, 09Fh, 074h, 042h             ; 0985: mov bl,[bx+0x4274]
    db 026h, 088h, 01Dh                   ; 0989: mov [es:di],bl
raster_next_pixel:
    db 005h, 011h, 011h                   ; 098C: add ax,0x1111
    db 081h, 0C2h, 011h, 011h             ; 098F: add dx,0x1111
    db 081h, 0C6h, 011h, 011h             ; 0993: add si,0x1111
    db 047h                               ; 0997: inc di
    db 0E2h, 0D9h                         ; 0998: loop 0x973
    db 089h, 046h, 0FCh                   ; 099A: mov [bp-0x4],ax
    db 083h, 046h, 086h, 010h             ; 099D: add word [bp-0x7a],byte +0x10
    db 0E9h, 048h, 0FFh                   ; 09A1: jmp 0x8ec
raster_next_scanline:
    db 0BFh, 024h, 000h                   ; 09A4: mov di,0x24
loc_09A7:
    db 066h, 08Bh, 043h, 088h             ; 09A7: mov eax,[bp+di-0x78]
    db 066h, 001h, 043h, 0C4h             ; 09AB: add [bp+di-0x3c],eax
    db 083h, 0EFh, 004h                   ; 09AF: sub di,byte +0x4
    db 079h, 0F3h                         ; 09B2: jns 0x9a7
    db 0FFh, 086h, 07Eh, 0FFh             ; 09B4: inc word [bp-0x82]
    db 0E9h, 022h, 0FEh                   ; 09B8: jmp 0x7dd
loc_09BB:
    db 0C9h                               ; 09BB: leave
    db 0C2h, 006h, 000h                   ; 09BC: ret 0x6
edge_setup_for_scanline:
    db 06Bh, 0D3h, 024h                   ; 09BF: imul dx,bx,byte +0x24
    db 08Bh, 0DEh                         ; 09C2: mov bx,si
    db 08Bh, 076h, 008h                   ; 09C4: mov si,[bp+0x8]
    db 003h, 0F2h                         ; 09C7: add si,dx
    db 08Bh, 044h, 00Ch                   ; 09C9: mov ax,[si+0xc]
    db 02Bh, 086h, 07Eh, 0FFh             ; 09CC: sub ax,[bp-0x82]
    db 066h, 00Fh, 0BFh, 0C0h             ; 09D0: movsx eax,ax
    db 066h, 089h, 086h, 06Ah, 0FFh       ; 09D4: mov [bp-0x96],eax
    db 0B9h, 005h, 000h                   ; 09D9: mov cx,0x5
    db 066h, 08Bh, 057h, 010h             ; 09DC: mov edx,[bx+0x10]
    db 066h, 089h, 053h, 0C4h             ; 09E0: mov [bp+di-0x3c],edx
    db 066h, 08Bh, 044h, 010h             ; 09E4: mov eax,[si+0x10]
    db 066h, 02Bh, 0C2h                   ; 09E8: sub eax,edx
    db 066h, 099h                         ; 09EB: cdq
    db 083h, 0BEh, 06Ah, 0FFh, 000h       ; 09ED: cmp word [bp-0x96],byte +0x0
    db 074h, 009h                         ; 09F2: jz 0x9fd
    db 066h, 0F7h, 0BEh, 06Ah, 0FFh       ; 09F4: idiv dword [bp-0x96]
    db 066h, 089h, 043h, 088h             ; 09F9: mov [bp+di-0x78],eax
loc_09FD:
    db 083h, 0C7h, 004h                   ; 09FD: add di,byte +0x4
    db 083h, 0C6h, 004h                   ; 0A00: add si,byte +0x4
    db 083h, 0C3h, 004h                   ; 0A03: add bx,byte +0x4
    db 0E2h, 0D4h                         ; 0A06: loop 0x9dc
    db 0C3h                               ; 0A08: ret

; Prepare one quad: load transformed vertices, near-plane clip, project, call rasterizer.
prepare_and_clip_face:
    db 0C8h, 072h, 001h, 000h             ; 0A09: enter 0x172,0x0
    db 0BEh, 03Fh, 010h                   ; 0A0D: mov si,0x103f
    db 033h, 0FFh                         ; 0A10: xor di,di
    db 0B9h, 004h, 000h                   ; 0A12: mov cx,0x4
prepare_vertex_loop:
    db 053h                               ; 0A15: push bx
    db 08Bh, 01Fh                         ; 0A16: mov bx,[bx]
    db 053h                               ; 0A18: push bx
    db 06Bh, 0DBh, 00Ch                   ; 0A19: imul bx,bx,byte +0xc
    db 081h, 0C3h, 054h, 0C4h             ; 0A1C: add bx,0xc454
    db 066h, 08Bh, 007h                   ; 0A20: mov eax,[bx]
    db 066h, 089h, 083h, 042h, 0FFh       ; 0A23: mov [bp+di-0xbe],eax
    db 066h, 08Bh, 047h, 004h             ; 0A28: mov eax,[bx+0x4]
    db 066h, 089h, 083h, 046h, 0FFh       ; 0A2C: mov [bp+di-0xba],eax
    db 0D9h, 047h, 008h                   ; 0A31: fld dword [bx+0x8]
    db 0D9h, 093h, 04Ah, 0FFh             ; 0A34: fst dword [bp+di-0xb6]
    db 0DFh, 05Eh, 0FCh                   ; 0A38: fistp word [bp-0x4]
    db 05Bh                               ; 0A3B: pop bx
    db 08Bh, 046h, 0FCh                   ; 0A3C: mov ax,[bp-0x4]
    db 005h, 000h, 002h                   ; 0A3F: add ax,0x200
    db 00Fh, 088h, 018h, 001h             ; 0A42: js near 0xb5e
    db 03Dh, 0FFh, 001h                   ; 0A46: cmp ax,0x1ff
    db 07Eh, 003h                         ; 0A49: jng 0xa4e
    db 0B8h, 0FFh, 001h                   ; 0A4B: mov ax,0x1ff
loc_0A4E:
    db 0C1h, 0E3h, 003h                   ; 0A4E: shl bx,byte 0x3
    db 066h, 033h, 0D2h                   ; 0A51: xor edx,edx
    db 0C1h, 0E0h, 007h                   ; 0A54: shl ax,byte 0x7
    db 0F7h, 0A7h, 072h, 017h             ; 0A57: mul word [bx+0x1772]
    db 066h, 089h, 093h, 062h, 0FFh       ; 0A5B: mov [bp+di-0x9e],edx
    db 032h, 0E4h                         ; 0A60: xor ah,ah
    db 08Ah, 044h, 004h                   ; 0A62: mov al,[si+0x4]
    db 066h, 0C1h, 0E0h, 010h             ; 0A65: shl eax,byte 0x10
    db 066h, 089h, 083h, 05Ah, 0FFh       ; 0A69: mov [bp+di-0xa6],eax
    db 0ACh                               ; 0A6E: lodsb
    db 066h, 0C1h, 0E0h, 010h             ; 0A6F: shl eax,byte 0x10
    db 066h, 089h, 083h, 056h, 0FFh       ; 0A73: mov [bp+di-0xaa],eax
    db 05Bh                               ; 0A78: pop bx
    db 043h                               ; 0A79: inc bx
    db 043h                               ; 0A7A: inc bx
    db 083h, 0C7h, 024h                   ; 0A7B: add di,byte +0x24
    db 0E2h, 095h                         ; 0A7E: loop 0xa15
    db 08Bh, 007h                         ; 0A80: mov ax,[bx]
    db 089h, 046h, 0F8h                   ; 0A82: mov [bp-0x8],ax
    db 033h, 0DBh                         ; 0A85: xor bx,bx
    db 089h, 05Eh, 0FAh                   ; 0A87: mov [bp-0x6],bx
    db 0D9h, 046h, 0B6h                   ; 0A8A: fld dword [bp-0x4a]
    db 0D9h, 0E4h                         ; 0A8D: ftst
    db 09Bh, 0DFh, 0E0h                   ; 0A8F: fstsw ax
    db 0DDh, 0D8h                         ; 0A92: fstp st0
    db 09Eh                               ; 0A94: sahf
    db 073h, 001h                         ; 0A95: jnc 0xa98
    db 04Bh                               ; 0A97: dec bx
loc_0A98:
    db 088h, 05Eh, 0F6h                   ; 0A98: mov [bp-0xa],bl
    db 033h, 0F6h                         ; 0A9B: xor si,si
    db 033h, 0FFh                         ; 0A9D: xor di,di
clip_vertex_loop:
    db 0D9h, 082h, 04Ah, 0FFh             ; 0A9F: fld dword [bp+si-0xb6]
    db 0D9h, 0E4h                         ; 0AA3: ftst
    db 09Bh, 0DFh, 0E0h                   ; 0AA5: fstsw ax
    db 0DDh, 0D8h                         ; 0AA8: fstp st0
    db 09Eh                               ; 0AAA: sahf
    db 073h, 02Bh                         ; 0AAB: jnc 0xad8
    db 080h, 07Eh, 0F6h, 0FFh             ; 0AAD: cmp byte [bp-0xa],0xff
    db 074h, 006h                         ; 0AB1: jz 0xab9
    db 0E8h, 0AAh, 000h                   ; 0AB3: call 0xb60
    db 0F6h, 056h, 0F6h                   ; 0AB6: not byte [bp-0xa]
copy_visible_vertex:
    db 057h                               ; 0AB9: push di
    db 056h                               ; 0ABA: push si
    db 08Dh, 0BBh, 08Eh, 0FEh             ; 0ABB: lea di,[bp+di-0x172]
    db 08Dh, 0B2h, 042h, 0FFh             ; 0ABF: lea si,[bp+si-0xbe]
    db 016h                               ; 0AC3: push ss
    db 007h                               ; 0AC4: pop es
    db 01Eh                               ; 0AC5: push ds
    db 016h                               ; 0AC6: push ss
    db 01Fh                               ; 0AC7: pop ds
    db 0B9h, 012h, 000h                   ; 0AC8: mov cx,0x12
    db 0F3h, 0A5h                         ; 0ACB: rep movsw
    db 01Fh                               ; 0ACD: pop ds
    db 05Eh                               ; 0ACE: pop si
    db 05Fh                               ; 0ACF: pop di
    db 083h, 0C7h, 024h                   ; 0AD0: add di,byte +0x24
    db 0FFh, 046h, 0FAh                   ; 0AD3: inc word [bp-0x6]
    db 0EBh, 00Ch                         ; 0AD6: jmp short 0xae4
clip_leaving_edge:
    db 080h, 07Eh, 0F6h, 0FFh             ; 0AD8: cmp byte [bp-0xa],0xff
    db 075h, 006h                         ; 0ADC: jnz 0xae4
    db 0E8h, 07Fh, 000h                   ; 0ADE: call 0xb60
    db 0F6h, 056h, 0F6h                   ; 0AE1: not byte [bp-0xa]
loc_0AE4:
    db 083h, 0C6h, 024h                   ; 0AE4: add si,byte +0x24
    db 081h, 0FEh, 090h, 000h             ; 0AE7: cmp si,0x90
    db 075h, 0B2h                         ; 0AEB: jnz 0xa9f
    db 08Bh, 04Eh, 0FAh                   ; 0AED: mov cx,[bp-0x6]
    db 083h, 0F9h, 002h                   ; 0AF0: cmp cx,byte +0x2
    db 07Ch, 069h                         ; 0AF3: jl 0xb5e
    db 090h                               ; 0AF5: nop
    db 090h                               ; 0AF6: nop
    db 033h, 0FFh                         ; 0AF7: xor di,di
project_visible_vertex_loop:
    db 0DFh, 006h, 0CFh, 00Dh             ; 0AF9: fild word [0xdcf]
    db 0D8h, 0A3h, 096h, 0FEh             ; 0AFD: fsub dword [bp+di-0x16a]
    db 0DEh, 036h, 0D3h, 00Dh             ; 0B01: fidiv word [0xdd3]
    db 0D9h, 083h, 092h, 0FEh             ; 0B05: fld dword [bp+di-0x16e]
    db 0D8h, 0F1h                         ; 0B09: fdiv st1
    db 0DEh, 006h, 0D1h, 00Dh             ; 0B0B: fiadd word [0xdd1]
    db 0DBh, 09Bh, 09Ah, 0FEh             ; 0B0F: fistp dword [bp+di-0x166]
    db 0D9h, 083h, 08Eh, 0FEh             ; 0B13: fld dword [bp+di-0x172]
    db 0D8h, 00Eh, 0CBh, 00Dh             ; 0B17: fmul dword [0xdcb]
    db 0D8h, 0F1h                         ; 0B1B: fdiv st1
    db 0DEh, 006h, 0D3h, 00Dh             ; 0B1D: fiadd word [0xdd3]
    db 0D9h, 0FCh                         ; 0B21: frndint
    db 0DAh, 00Eh, 0D7h, 00Dh             ; 0B23: fimul dword [0xdd7]
    db 0DBh, 09Bh, 09Eh, 0FEh             ; 0B27: fistp dword [bp+di-0x162]
    db 0DBh, 083h, 0A2h, 0FEh             ; 0B2B: fild dword [bp+di-0x15e]
    db 0D8h, 0F1h                         ; 0B2F: fdiv st1
    db 0DBh, 09Bh, 0A2h, 0FEh             ; 0B31: fistp dword [bp+di-0x15e]
    db 0DBh, 083h, 0A6h, 0FEh             ; 0B35: fild dword [bp+di-0x15a]
    db 0D8h, 0F1h                         ; 0B39: fdiv st1
    db 0DBh, 09Bh, 0A6h, 0FEh             ; 0B3B: fistp dword [bp+di-0x15a]
    db 0DBh, 006h, 0D7h, 00Dh             ; 0B3F: fild dword [0xdd7]
    db 0D8h, 0F1h                         ; 0B43: fdiv st1
    db 0DBh, 09Bh, 0AAh, 0FEh             ; 0B45: fistp dword [bp+di-0x156]
    db 0DDh, 0D8h                         ; 0B49: fstp st0
    db 083h, 0C7h, 024h                   ; 0B4B: add di,byte +0x24
    db 0E2h, 0A9h                         ; 0B4E: loop 0xaf9
    db 08Dh, 0BEh, 08Eh, 0FEh             ; 0B50: lea di,[bp-0x172]
    db 057h                               ; 0B54: push di
    db 0FFh, 076h, 0FAh                   ; 0B55: push word [bp-0x6]
    db 0FFh, 076h, 0F8h                   ; 0B58: push word [bp-0x8]
    db 0E8h, 0F0h, 0FBh                   ; 0B5B: call 0x74e
loc_0B5E:
    db 0C9h                               ; 0B5E: leave
    db 0C3h                               ; 0B5F: ret

; Clip one polygon edge against near plane and interpolate attributes.
clip_edge_against_near:
    db 056h                               ; 0B60: push si
    db 057h                               ; 0B61: push di
    db 08Dh, 044h, 0DCh                   ; 0B62: lea ax,[si-0x24]
    db 03Dh, 000h, 000h                   ; 0B65: cmp ax,0x0
    db 07Dh, 003h                         ; 0B68: jnl 0xb6d
    db 0B8h, 06Ch, 000h                   ; 0B6A: mov ax,0x6c
loc_0B6D:
    db 0D9h, 082h, 04Ah, 0FFh             ; 0B6D: fld dword [bp+si-0xb6]
    db 0D9h, 0C0h                         ; 0B71: fld st0
    db 097h                               ; 0B73: xchg ax,di
    db 0D8h, 0A3h, 04Ah, 0FFh             ; 0B74: fsub dword [bp+di-0xb6]
    db 097h                               ; 0B78: xchg ax,di
    db 0DEh, 0F9h                         ; 0B79: fdivp st1
    db 0BBh, 03Ah, 010h                   ; 0B7B: mov bx,0x103a
    db 0B9h, 006h, 000h                   ; 0B7E: mov cx,0x6
    db 097h                               ; 0B81: xchg ax,di
    db 0D9h, 083h, 042h, 0FFh             ; 0B82: fld dword [bp+di-0xbe]
    db 097h                               ; 0B86: xchg ax,di
    db 0D8h, 0A2h, 042h, 0FFh             ; 0B87: fsub dword [bp+si-0xbe]
    db 0D8h, 0C9h                         ; 0B8B: fmul st1
    db 0D8h, 082h, 042h, 0FFh             ; 0B8D: fadd dword [bp+si-0xbe]
    db 0D9h, 09Bh, 08Eh, 0FEh             ; 0B91: fstp dword [bp+di-0x172]
    db 08Ah, 017h                         ; 0B95: mov dl,[bx]
    db 043h                               ; 0B97: inc bx
    db 032h, 0F6h                         ; 0B98: xor dh,dh
    db 003h, 0FAh                         ; 0B9A: add di,dx
    db 003h, 0F2h                         ; 0B9C: add si,dx
    db 003h, 0C2h                         ; 0B9E: add ax,dx
    db 0E2h, 0DFh                         ; 0BA0: loop 0xb81
    db 0DDh, 0D8h                         ; 0BA2: fstp st0
    db 05Fh                               ; 0BA4: pop di
    db 05Eh                               ; 0BA5: pop si
    db 0FFh, 046h, 0FAh                   ; 0BA6: inc word [bp-0x6]
    db 083h, 0C7h, 024h                   ; 0BA9: add di,byte +0x24
    db 0C3h                               ; 0BAC: ret
rotate_pair_by_angle:
    db 0D9h, 0EBh                         ; 0BAD: fldpi
    db 0DEh, 0C9h                         ; 0BAF: fmulp st1
    db 0DAh, 036h, 0D7h, 00Dh             ; 0BB1: fidiv dword [0xdd7]
    db 0D9h, 0FBh                         ; 0BB5: fsincos
    db 0D9h, 0C0h                         ; 0BB7: fld st0
    db 0D8h, 00Ch                         ; 0BB9: fmul dword [si]
    db 0D9h, 0C2h                         ; 0BBB: fld st2
    db 0D8h, 00Fh                         ; 0BBD: fmul dword [bx]
    db 0DEh, 0E9h                         ; 0BBF: fsubp st1
    db 0D9h, 0CAh                         ; 0BC1: fxch st2
    db 0D8h, 00Ch                         ; 0BC3: fmul dword [si]
    db 0D9h, 0C9h                         ; 0BC5: fxch st1
    db 0D8h, 00Fh                         ; 0BC7: fmul dword [bx]
    db 0DEh, 0C1h                         ; 0BC9: faddp st1
    db 0D9h, 01Fh                         ; 0BCB: fstp dword [bx]
    db 0D9h, 01Ch                         ; 0BCD: fstp dword [si]
    db 0C3h                               ; 0BCF: ret
rotate_matrix_euler:
    db 055h                               ; 0BD0: push bp
    db 08Bh, 0ECh                         ; 0BD1: mov bp,sp
    db 08Bh, 07Eh, 004h                   ; 0BD3: mov di,[bp+0x4]
    db 0DFh, 046h, 00Ah                   ; 0BD6: fild word [bp+0xa]
    db 08Dh, 05Dh, 008h                   ; 0BD9: lea bx,[di+0x8]
    db 08Dh, 075h, 004h                   ; 0BDC: lea si,[di+0x4]
    db 0E8h, 0CBh, 0FFh                   ; 0BDF: call 0xbad
    db 0DFh, 046h, 008h                   ; 0BE2: fild word [bp+0x8]
    db 08Dh, 01Dh                         ; 0BE5: lea bx,[di]
    db 08Dh, 075h, 008h                   ; 0BE7: lea si,[di+0x8]
    db 0E8h, 0C0h, 0FFh                   ; 0BEA: call 0xbad
    db 0DFh, 046h, 006h                   ; 0BED: fild word [bp+0x6]
    db 08Dh, 05Dh, 004h                   ; 0BF0: lea bx,[di+0x4]
    db 08Dh, 035h                         ; 0BF3: lea si,[di]
    db 0E8h, 0B5h, 0FFh                   ; 0BF5: call 0xbad
    db 05Dh                               ; 0BF8: pop bp
    db 0C2h, 008h, 000h                   ; 0BF9: ret 0x8
build_camera_matrix:
    db 055h                               ; 0BFC: push bp
    db 08Bh, 0ECh                         ; 0BFD: mov bp,sp
    db 0BFh, 0D2h, 013h                   ; 0BFF: mov di,0x13d2
    db 0B5h, 002h                         ; 0C02: mov ch,0x2
loc_0C04:
    db 0B1h, 002h                         ; 0C04: mov cl,0x2
loc_0C06:
    db 0D9h, 0EEh                         ; 0C06: fldz
    db 03Ah, 0E9h                         ; 0C08: cmp ch,cl
    db 075h, 004h                         ; 0C0A: jnz 0xc10
    db 0DDh, 0D8h                         ; 0C0C: fstp st0
    db 0D9h, 0E8h                         ; 0C0E: fld1
loc_0C10:
    db 0D9h, 01Dh                         ; 0C10: fstp dword [di]
    db 083h, 0C7h, 004h                   ; 0C12: add di,byte +0x4
    db 0FEh, 0C9h                         ; 0C15: dec cl
    db 079h, 0EDh                         ; 0C17: jns 0xc06
    db 0FEh, 0CDh                         ; 0C19: dec ch
    db 079h, 0E7h                         ; 0C1B: jns 0xc04
    db 033h, 0FFh                         ; 0C1D: xor di,di
loc_0C1F:
    db 057h                               ; 0C1F: push di
    db 0FFh, 076h, 00Ah                   ; 0C20: push word [bp+0xa]
    db 0FFh, 076h, 008h                   ; 0C23: push word [bp+0x8]
    db 0FFh, 076h, 006h                   ; 0C26: push word [bp+0x6]
    db 081h, 0C7h, 0D2h, 013h             ; 0C29: add di,0x13d2
    db 057h                               ; 0C2D: push di
    db 0E8h, 09Fh, 0FFh                   ; 0C2E: call 0xbd0
    db 05Fh                               ; 0C31: pop di
    db 033h, 0DBh                         ; 0C32: xor bx,bx
loc_0C34:
    db 0D9h, 085h, 0D2h, 013h             ; 0C34: fld dword [di+0x13d2]
    db 0D8h, 08Fh, 08Ah, 013h             ; 0C38: fmul dword [bx+0x138a]
    db 0D9h, 085h, 0D6h, 013h             ; 0C3C: fld dword [di+0x13d6]
    db 0D8h, 08Fh, 096h, 013h             ; 0C40: fmul dword [bx+0x1396]
    db 0D9h, 085h, 0DAh, 013h             ; 0C44: fld dword [di+0x13da]
    db 0D8h, 08Fh, 0A2h, 013h             ; 0C48: fmul dword [bx+0x13a2]
    db 0DEh, 0C1h                         ; 0C4C: faddp st1
    db 0DEh, 0C1h                         ; 0C4E: faddp st1
    db 0D9h, 091h, 08Ah, 013h             ; 0C50: fst dword [bx+di+0x138a]
    db 0D9h, 099h, 0AEh, 013h             ; 0C54: fstp dword [bx+di+0x13ae]
    db 083h, 0C3h, 004h                   ; 0C58: add bx,byte +0x4
    db 080h, 0FBh, 00Ch                   ; 0C5B: cmp bl,0xc
    db 075h, 0D4h                         ; 0C5E: jnz 0xc34
    db 083h, 0C7h, 00Ch                   ; 0C60: add di,byte +0xc
    db 083h, 0FFh, 024h                   ; 0C63: cmp di,byte +0x24
    db 075h, 0B7h                         ; 0C66: jnz 0xc1f
    db 0BEh, 0AEh, 013h                   ; 0C68: mov si,0x13ae
    db 0B9h, 003h, 000h                   ; 0C6B: mov cx,0x3
    db 0DFh, 046h, 004h                   ; 0C6E: fild word [bp+0x4]
    db 08Dh, 05Ch, 00Ch                   ; 0C71: lea bx,[si+0xc]
    db 0E8h, 036h, 0FFh                   ; 0C74: call 0xbad
    db 083h, 0C6h, 004h                   ; 0C77: add si,byte +0x4
    db 0E2h, 0F2h                         ; 0C7A: loop 0xc6e
    db 05Dh                               ; 0C7C: pop bp
    db 0C2h, 008h, 000h                   ; 0C7D: ret 0x8

; Decode compact cube/face scene description into vertex and quad arrays.
build_scene_geometry:
    db 0C8h, 004h, 000h, 000h             ; 0C80: enter 0x4,0x0
    db 0BEh, 08Ch, 010h                   ; 0C84: mov si,0x108c
    db 0B9h, 004h, 000h                   ; 0C87: mov cx,0x4
scene_stream_loop:
    db 051h                               ; 0C8A: push cx
    db 056h                               ; 0C8B: push si
    db 0BFh, 074h, 0C2h                   ; 0C8C: mov di,0xc274
    db 0BBh, 0ECh, 0C2h                   ; 0C8F: mov bx,0xc2ec
    db 0BEh, 05Fh, 010h                   ; 0C92: mov si,0x105f
    db 0B1h, 00Fh                         ; 0C95: mov cl,0xf
scene_seed_point_loop:
    db 051h                               ; 0C97: push cx
    db 0B1h, 003h                         ; 0C98: mov cl,0x3
scene_seed_component_loop:
    db 0ACh                               ; 0C9A: lodsb
    db 098h                               ; 0C9B: cbw
    db 0ABh                               ; 0C9C: stosw
    db 0DFh, 045h, 0FEh                   ; 0C9D: fild word [di-0x2]
    db 0D9h, 01Fh                         ; 0CA0: fstp dword [bx]
    db 083h, 0C3h, 004h                   ; 0CA2: add bx,byte +0x4
    db 0E2h, 0F3h                         ; 0CA5: loop 0xc9a
    db 059h                               ; 0CA7: pop cx
    db 0B8h, 000h, 07Fh                   ; 0CA8: mov ax,0x7f00
    db 0ABh                               ; 0CAB: stosw
    db 0E2h, 0E9h                         ; 0CAC: loop 0xc97
    db 05Eh                               ; 0CAE: pop si
scene_token_loop:
    db 0ACh                               ; 0CAF: lodsb
    db 03Ch, 0FFh                         ; 0CB0: cmp al,0xff
    db 00Fh, 084h, 00Dh, 001h             ; 0CB2: jz near 0xdc3
    db 08Ah, 0F8h                         ; 0CB6: mov bh,al
    db 081h, 0E3h, 000h, 070h             ; 0CB8: and bx,0x7000
    db 080h, 0C7h, 00Fh                   ; 0CBC: add bh,0xf
    db 089h, 05Eh, 0FCh                   ; 0CBF: mov [bp-0x4],bx
    db 025h, 00Fh, 000h                   ; 0CC2: and ax,0xf
    db 089h, 046h, 0FEh                   ; 0CC5: mov [bp-0x2],ax
    db 033h, 0DBh                         ; 0CC8: xor bx,bx
scene_faces_loop:
    db 0F6h, 0C3h, 004h                   ; 0CCA: test bl,0x4
    db 074h, 005h                         ; 0CCD: jz 0xcd4
    db 0ACh                               ; 0CCF: lodsb
    db 024h, 00Fh                         ; 0CD0: and al,0xf
    db 0EBh, 005h                         ; 0CD2: jmp short 0xcd9
loc_0CD4:
    db 08Ah, 004h                         ; 0CD4: mov al,[si]
    db 0C0h, 0E8h, 004h                   ; 0CD6: shr al,byte 0x4
loc_0CD9:
    db 032h, 0E4h                         ; 0CD9: xor ah,ah
    db 048h                               ; 0CDB: dec ax
    db 078h, 050h                         ; 0CDC: js 0xd2e
    db 06Bh, 03Eh, 06Ah, 017h, 00Ah       ; 0CDE: imul di,[0x176a],byte +0xa
    db 081h, 0C7h, 0ECh, 023h             ; 0CE3: add di,0x23ec
    db 0FFh, 006h, 06Ah, 017h             ; 0CE7: inc word [0x176a]
    db 089h, 045h, 008h                   ; 0CEB: mov [di+0x8],ax
    db 053h                               ; 0CEE: push bx
    db 056h                               ; 0CEF: push si
    db 0B1h, 004h                         ; 0CF0: mov cl,0x4
scene_vertex_loop:
    db 00Fh, 0BEh, 0B7h, 047h, 010h       ; 0CF2: movsx si,[bx+0x1047]
    db 081h, 0C6h, 074h, 0C2h             ; 0CF7: add si,0xc274
    db 057h                               ; 0CFB: push di
    db 0BFh, 06Ch, 017h                   ; 0CFC: mov di,0x176c
    db 051h                               ; 0CFF: push cx
    db 08Bh, 00Eh, 068h, 017h             ; 0D00: mov cx,[0x1768]
    db 033h, 0C0h                         ; 0D04: xor ax,ax
    db 0E3h, 016h                         ; 0D06: jcxz 0xd1e
scene_find_vertex_loop:
    db 066h, 08Bh, 014h                   ; 0D08: mov edx,[si]
    db 066h, 03Bh, 015h                   ; 0D0B: cmp edx,[di]
    db 075h, 008h                         ; 0D0E: jnz 0xd18
    db 08Bh, 054h, 004h                   ; 0D10: mov dx,[si+0x4]
    db 03Bh, 055h, 004h                   ; 0D13: cmp dx,[di+0x4]
    db 074h, 00Eh                         ; 0D16: jz 0xd26
loc_0D18:
    db 040h                               ; 0D18: inc ax
    db 083h, 0C7h, 008h                   ; 0D19: add di,byte +0x8
    db 0E2h, 0EAh                         ; 0D1C: loop 0xd08
scene_store_new_vertex:
    db 066h, 0A5h                         ; 0D1E: movsd
    db 066h, 0A5h                         ; 0D20: movsd
    db 0FFh, 006h, 068h, 017h             ; 0D22: inc word [0x1768]
scene_emit_vertex_index:
    db 059h                               ; 0D26: pop cx
    db 05Fh                               ; 0D27: pop di
    db 0ABh                               ; 0D28: stosw
    db 043h                               ; 0D29: inc bx
    db 0E2h, 0C6h                         ; 0D2A: loop 0xcf2
    db 05Eh                               ; 0D2C: pop si
    db 05Bh                               ; 0D2D: pop bx
loc_0D2E:
    db 083h, 0C3h, 004h                   ; 0D2E: add bx,byte +0x4
    db 083h, 0FBh, 018h                   ; 0D31: cmp bx,byte +0x18
    db 075h, 094h                         ; 0D34: jnz 0xcca
    db 06Bh, 07Eh, 0FEh, 00Ch             ; 0D36: imul di,[bp-0x2],byte +0xc
    db 0B1h, 003h                         ; 0D3A: mov cl,0x3
    db 0BBh, 04Ch, 0C3h                   ; 0D3C: mov bx,0xc34c
accumulate_scene_position:
    db 0D9h, 047h, 048h                   ; 0D3F: fld dword [bx+0x48]
    db 0D8h, 001h                         ; 0D42: fadd dword [bx+di]
    db 0D9h, 05Fh, 048h                   ; 0D44: fstp dword [bx+0x48]
    db 083h, 0C3h, 004h                   ; 0D47: add bx,byte +0x4
    db 0E2h, 0F3h                         ; 0D4A: loop 0xd3f
    db 080h, 07Ch, 0FCh, 000h             ; 0D4C: cmp byte [si-0x4],0x0
    db 07Dh, 025h                         ; 0D50: jnl 0xd77
    db 0BBh, 0ECh, 0C2h                   ; 0D52: mov bx,0xc2ec
    db 0B1h, 00Eh                         ; 0D55: mov cl,0xe
scene_apply_rotation_loop:
    db 060h                               ; 0D57: pusha
    db 0B1h, 003h                         ; 0D58: mov cl,0x3
    db 08Ah, 014h                         ; 0D5A: mov dl,[si]
scene_rotation_axis_loop:
    db 0D0h, 0EAh                         ; 0D5C: shr dl,1
    db 073h, 008h                         ; 0D5E: jnc 0xd68
    db 08Ah, 024h                         ; 0D60: mov ah,[si]
    db 025h, 000h, 0F0h                   ; 0D62: and ax,0xf000
    db 050h                               ; 0D65: push ax
    db 0EBh, 002h                         ; 0D66: jmp short 0xd6a
loc_0D68:
    db 06Ah, 000h                         ; 0D68: push byte +0x0
loc_0D6A:
    db 0E2h, 0F0h                         ; 0D6A: loop 0xd5c
    db 053h                               ; 0D6C: push bx
    db 0E8h, 060h, 0FEh                   ; 0D6D: call 0xbd0
    db 061h                               ; 0D70: popa
    db 083h, 0C3h, 00Ch                   ; 0D71: add bx,byte +0xc
    db 0E2h, 0E1h                         ; 0D74: loop 0xd57
    db 046h                               ; 0D76: inc si
scene_emit_cube_vertices_setup:
    db 08Bh, 05Eh, 0FEh                   ; 0D77: mov bx,[bp-0x2]
    db 0C1h, 0E3h, 002h                   ; 0D7A: shl bx,byte 0x2
    db 0B1h, 004h                         ; 0D7D: mov cl,0x4
scene_emit_cube_vertices_loop:
    db 060h                               ; 0D7F: pusha
    db 00Fh, 0BEh, 0B7h, 047h, 010h       ; 0D80: movsx si,[bx+0x1047]
    db 08Bh, 0C6h                         ; 0D85: mov ax,si
    db 081h, 0C6h, 074h, 0C2h             ; 0D87: add si,0xc274
    db 080h, 0F3h, 007h                   ; 0D8B: xor bl,0x7
    db 00Fh, 0BEh, 0BFh, 047h, 010h       ; 0D8E: movsx di,[bx+0x1047]
    db 081h, 0C7h, 074h, 0C2h             ; 0D93: add di,0xc274
    db 056h                               ; 0D97: push si
    db 066h, 0A5h                         ; 0D98: movsd
    db 066h, 0A5h                         ; 0D9A: movsd
    db 05Eh                               ; 0D9C: pop si
    db 08Bh, 0D8h                         ; 0D9D: mov bx,ax
    db 0D1h, 0EBh                         ; 0D9F: shr bx,1
    db 003h, 0D8h                         ; 0DA1: add bx,ax
    db 0BFh, 0ECh, 0C2h                   ; 0DA3: mov di,0xc2ec
    db 0B1h, 003h                         ; 0DA6: mov cl,0x3
scene_emit_component_loop:
    db 0D9h, 001h                         ; 0DA8: fld dword [bx+di]
    db 0D8h, 085h, 0A8h, 000h             ; 0DAA: fadd dword [di+0xa8]
    db 0DFh, 01Ch                         ; 0DAE: fistp word [si]
    db 083h, 0C7h, 004h                   ; 0DB0: add di,byte +0x4
    db 046h                               ; 0DB3: inc si
    db 046h                               ; 0DB4: inc si
    db 0E2h, 0F1h                         ; 0DB5: loop 0xda8
    db 08Bh, 046h, 0FCh                   ; 0DB7: mov ax,[bp-0x4]
    db 089h, 004h                         ; 0DBA: mov [si],ax
    db 061h                               ; 0DBC: popa
    db 043h                               ; 0DBD: inc bx
    db 0E2h, 0BFh                         ; 0DBE: loop 0xd7f
    db 0E9h, 0ECh, 0FEh                   ; 0DC0: jmp 0xcaf
loc_0DC3:
    db 059h                               ; 0DC3: pop cx
    db 049h                               ; 0DC4: dec cx
    db 00Fh, 085h, 0C1h, 0FEh             ; 0DC5: jnz near 0xc8a
    db 0C9h                               ; 0DC9: leave
    db 0C3h                               ; 0DCA: ret

; Decoded data tables start here. Keep the include separate and readable.
data_start:
    %include "SNC_OMNI_DATA.INC"

%if ($ - $$) != 012AEh
    %error "unpacked COM size changed"
%endif
