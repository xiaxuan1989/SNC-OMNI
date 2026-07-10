; Reconstructed source for original packed SNC_OMNI.COM.
; The first A1h bytes are the relocation stub and adaptive unpacker.
; The remaining bytes are emitted from SNC_OMNI_payload.bin.
; Build check: nasm -f bin SNC_OMNI.ASM -o SNC_OMNI_rebuilt.COM

bits 16
org 0100h


; Copy the 64 KiB COM segment up by 2000h paragraphs.
packed_entry:
    db 033h, 0F6h                        ; 0100: xor si,si
    mov di,0x2000                        ; 0102: BF 00 20
    mov ch,0x10                          ; 0105: B5 10
    rep movsw                            ; 0107: F3 A5
    mov ax,cs                            ; 0109: 8C C8
    add ax,0x200                         ; 010B: 05 00 02
    push ax                              ; 010E: 50
    push word 0x113                      ; 010F: 68 13 01
    retf                                 ; 0112: CB
; Continue execution from the relocated copy.
relocated_unpacker_entry:
    push cs                              ; 0113: 0E
    pop ds                               ; 0114: 1F
    mov si,0x1a1                         ; 0115: BE A1 01
    mov di,0x100                         ; 0118: BF 00 01
    push es                              ; 011B: 06
    push di                              ; 011C: 57
; Initialize adaptive arithmetic model cumulative table at 1321h.
init_range_model:
    mov ax,0x111                         ; 011D: B8 11 01
    mov bx,0x1321                        ; 0120: BB 21 13
init_range_model_loop:
    mov [bx],ax                          ; 0123: 89 07
    dec bx                               ; 0125: 4B
    dec bx                               ; 0126: 4B
    dec ax                               ; 0127: 48
    jns short 0x123                     ; 0128: 79 F9
load_initial_code_value:
    lodsw                                ; 012A: AD
    xchg al,ah                           ; 012B: 86 E0
    db 08Bh, 0C8h                         ; 012D: mov cx,ax
    mov bp,0xffff                        ; 012F: BD FF FF
; Decode one command symbol: literal, back-reference, or end marker.
unpack_symbol_loop:
    call 0x155                           ; 0132: E8 20 00
    cmp ax,0x100                         ; 0135: 3D 00 01
    jz short 0x154                      ; 0138: 74 1A
    jg short 0x13f                      ; 013A: 7F 03
    stosb                                ; 013C: AA
    jmp short 0x132                      ; 013D: EB F3
; Symbol > 100h encodes a length plus a separately decoded distance.
copy_backref_command:
    sub ax,0xff                          ; 013F: 2D FF 00
    push ax                              ; 0142: 50
    call 0x155                           ; 0143: E8 0F 00
    pop dx                               ; 0146: 5A
    neg ax                               ; 0147: F7 D8
    db 08Bh, 0D8h                         ; 0149: mov bx,ax
copy_backref_loop:
    mov al,[es:bx+di]                    ; 014B: 26 8A 01
    stosb                                ; 014E: AA
    dec dx                               ; 014F: 4A
    jnz short 0x14b                     ; 0150: 75 F9
    jmp short 0x132                      ; 0152: EB DE
; RETF returns to ES:0100, the freshly unpacked program.
unpack_done:
    retf                                 ; 0154: CB
; Adaptive arithmetic/range decoder, returns symbol in AX.
decode_range_symbol:
    push di                              ; 0155: 57
    mov bx,0x1321                        ; 0156: BB 21 13
    db 08Bh, 0C1h                         ; 0159: mov ax,cx
    inc ax                               ; 015B: 40
    mul word [bx]                        ; 015C: F7 27
    div bp                               ; 015E: F7 F5
    db 08Bh, 0FBh                         ; 0160: mov di,bx
    mov dx,0x111                         ; 0162: BA 11 01
find_symbol_bucket_loop:
    dec di                               ; 0165: 4F
    dec di                               ; 0166: 4F
    dec dx                               ; 0167: 4A
    cmp [di],ax                          ; 0168: 39 05
    jg short 0x165                      ; 016A: 7F F9
    push dx                              ; 016C: 52
    db 08Bh, 0C5h                         ; 016D: mov ax,bp
    mul word [di]                        ; 016F: F7 25
    div word [bx]                        ; 0171: F7 37
    db 02Bh, 0C8h                         ; 0173: sub cx,ax
    xchg ax,bp                           ; 0175: 95
    mul word [di+0x2]                    ; 0176: F7 65 02
    div word [bx]                        ; 0179: F7 37
    xchg ax,bp                           ; 017B: 95
    db 02Bh, 0E8h                         ; 017C: sub bp,ax

; Shift more bits from compressed stream while range high bit is clear.
renormalize_range_loop:
    dec byte [0x10fe]                    ; 017E: FE 0E FE 10
    jns short 0x18a                     ; 0182: 79 06
    mov byte [0x10fe],0x7                ; 0184: C6 06 FE 10 07
    inc si                               ; 0189: 46
consume_packed_bit:
    rcl byte [si],1                      ; 018A: D0 14
    rcl cx,1                             ; 018C: D1 D1
    shl bp,1                             ; 018E: D1 E5
    jns short 0x17e                     ; 0190: 79 EC
    pop dx                               ; 0192: 5A
update_model_counts:
    mov ax,0x111                         ; 0193: B8 11 01
update_model_counts_loop:
    inc word [bx]                        ; 0196: FF 07
    dec bx                               ; 0198: 4B
    dec bx                               ; 0199: 4B
    dec ax                               ; 019A: 48
    db 03Bh, 0D0h                         ; 019B: cmp dx,ax
    jnz short 0x196                     ; 019D: 75 F7
    pop di                               ; 019F: 5F
    ret                                  ; 01A0: C3
compressed_payload:
    incbin "SNC_OMNI_payload.bin"

%if ($ - $$) != 00FFFh
    %error "packed COM size changed"
%endif
