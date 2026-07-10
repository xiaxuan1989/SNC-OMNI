; Reconstructed source for original packed SNC_OMNI.COM.
; The first A1h bytes are the relocation stub and adaptive unpacker.
; The remaining bytes are emitted from SNC_OMNI_payload.bin.
; Build check: nasm -f bin SNC_OMNI.ASM -o SNC_OMNI_rebuilt.COM

bits 16
org 0100h


; Copy the 64 KiB COM segment up by 2000h paragraphs.
packed_entry:
    db 033h, 0F6h                         ; 0100: xor si,si
    db 0BFh, 000h, 020h                   ; 0102: mov di,0x2000
    db 0B5h, 010h                         ; 0105: mov ch,0x10
    db 0F3h, 0A5h                         ; 0107: rep movsw
    db 08Ch, 0C8h                         ; 0109: mov ax,cs
    db 005h, 000h, 002h                   ; 010B: add ax,0x200
    db 050h                               ; 010E: push ax
    db 068h, 013h, 001h                   ; 010F: push word 0x113
    db 0CBh                               ; 0112: retf

; Continue execution from the relocated copy.
relocated_unpacker_entry:
    db 00Eh                               ; 0113: push cs
    db 01Fh                               ; 0114: pop ds
    db 0BEh, 0A1h, 001h                   ; 0115: mov si,0x1a1
    db 0BFh, 000h, 001h                   ; 0118: mov di,0x100
    db 006h                               ; 011B: push es
    db 057h                               ; 011C: push di

; Initialize adaptive arithmetic model cumulative table at 1321h.
init_range_model:
    db 0B8h, 011h, 001h                   ; 011D: mov ax,0x111
    db 0BBh, 021h, 013h                   ; 0120: mov bx,0x1321
init_range_model_loop:
    db 089h, 007h                         ; 0123: mov [bx],ax
    db 04Bh                               ; 0125: dec bx
    db 04Bh                               ; 0126: dec bx
    db 048h                               ; 0127: dec ax
    db 079h, 0F9h                         ; 0128: jns 0x123
load_initial_code_value:
    db 0ADh                               ; 012A: lodsw
    db 086h, 0E0h                         ; 012B: xchg al,ah
    db 08Bh, 0C8h                         ; 012D: mov cx,ax
    db 0BDh, 0FFh, 0FFh                   ; 012F: mov bp,0xffff

; Decode one command symbol: literal, back-reference, or end marker.
unpack_symbol_loop:
    db 0E8h, 020h, 000h                   ; 0132: call 0x155
    db 03Dh, 000h, 001h                   ; 0135: cmp ax,0x100
    db 074h, 01Ah                         ; 0138: jz 0x154
    db 07Fh, 003h                         ; 013A: jg 0x13f
    db 0AAh                               ; 013C: stosb
    db 0EBh, 0F3h                         ; 013D: jmp short 0x132

; Symbol > 100h encodes a length plus a separately decoded distance.
copy_backref_command:
    db 02Dh, 0FFh, 000h                   ; 013F: sub ax,0xff
    db 050h                               ; 0142: push ax
    db 0E8h, 00Fh, 000h                   ; 0143: call 0x155
    db 05Ah                               ; 0146: pop dx
    db 0F7h, 0D8h                         ; 0147: neg ax
    db 08Bh, 0D8h                         ; 0149: mov bx,ax
copy_backref_loop:
    db 026h, 08Ah, 001h                   ; 014B: mov al,[es:bx+di]
    db 0AAh                               ; 014E: stosb
    db 04Ah                               ; 014F: dec dx
    db 075h, 0F9h                         ; 0150: jnz 0x14b
    db 0EBh, 0DEh                         ; 0152: jmp short 0x132

; RETF returns to ES:0100, the freshly unpacked program.
unpack_done:
    db 0CBh                               ; 0154: retf

; Adaptive arithmetic/range decoder, returns symbol in AX.
decode_range_symbol:
    db 057h                               ; 0155: push di
    db 0BBh, 021h, 013h                   ; 0156: mov bx,0x1321
    db 08Bh, 0C1h                         ; 0159: mov ax,cx
    db 040h                               ; 015B: inc ax
    db 0F7h, 027h                         ; 015C: mul word [bx]
    db 0F7h, 0F5h                         ; 015E: div bp
    db 08Bh, 0FBh                         ; 0160: mov di,bx
    db 0BAh, 011h, 001h                   ; 0162: mov dx,0x111
find_symbol_bucket_loop:
    db 04Fh                               ; 0165: dec di
    db 04Fh                               ; 0166: dec di
    db 04Ah                               ; 0167: dec dx
    db 039h, 005h                         ; 0168: cmp [di],ax
    db 07Fh, 0F9h                         ; 016A: jg 0x165
    db 052h                               ; 016C: push dx
    db 08Bh, 0C5h                         ; 016D: mov ax,bp
    db 0F7h, 025h                         ; 016F: mul word [di]
    db 0F7h, 037h                         ; 0171: div word [bx]
    db 02Bh, 0C8h                         ; 0173: sub cx,ax
    db 095h                               ; 0175: xchg ax,bp
    db 0F7h, 065h, 002h                   ; 0176: mul word [di+0x2]
    db 0F7h, 037h                         ; 0179: div word [bx]
    db 095h                               ; 017B: xchg ax,bp
    db 02Bh, 0E8h                         ; 017C: sub bp,ax

; Shift more bits from compressed stream while range high bit is clear.
renormalize_range_loop:
    db 0FEh, 00Eh, 0FEh, 010h             ; 017E: dec byte [0x10fe]
    db 079h, 006h                         ; 0182: jns 0x18a
    db 0C6h, 006h, 0FEh, 010h, 007h       ; 0184: mov byte [0x10fe],0x7
    db 046h                               ; 0189: inc si
consume_packed_bit:
    db 0D0h, 014h                         ; 018A: rcl byte [si],1
    db 0D1h, 0D1h                         ; 018C: rcl cx,1
    db 0D1h, 0E5h                         ; 018E: shl bp,1
    db 079h, 0ECh                         ; 0190: jns 0x17e
    db 05Ah                               ; 0192: pop dx
update_model_counts:
    db 0B8h, 011h, 001h                   ; 0193: mov ax,0x111
update_model_counts_loop:
    db 0FFh, 007h                         ; 0196: inc word [bx]
    db 04Bh                               ; 0198: dec bx
    db 04Bh                               ; 0199: dec bx
    db 048h                               ; 019A: dec ax
    db 03Bh, 0D0h                         ; 019B: cmp dx,ax
    db 075h, 0F7h                         ; 019D: jnz 0x196
    db 05Fh                               ; 019F: pop di
    db 0C3h                               ; 01A0: ret

compressed_payload:
    incbin "SNC_OMNI_payload.bin"

%if ($ - $$) != 00FFFh
    %error "packed COM size changed"
%endif
