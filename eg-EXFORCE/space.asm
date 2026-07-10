bits 16
org 100h

; EXFORCE / space shooter, 16-bit DOS .COM program.
;
; Major design points:
;   - Runs in VGA mode 13h: 320x200, 256 colors, visible VRAM at A000:0000.
;   - Uses a back buffer inside the .COM segment, then copies it to VRAM.
;   - Hooks keyboard IRQ1 / Int 9 and maintains a scan-code state array.
;   - Uses BIOS timer Int 1Ah for frame pacing and pseudo-random seeding.
;   - Uses PC speaker/PIT ports 43h/40h/61h for a short sound effect.
;   - Aircraft sprite is stored as compact RLE data and decompressed at startup.
;   - Text strings are XOR-encoded with AAh and printed through BIOS teletype.
;
; Rebuild check:
;   nasm -f bin space.asm -o space_rebuilt.com

SCREEN_W        equ 320
SCREEN_H        equ 200
GAME_H          equ 150
VRAM_SEG        equ 0A000h
BACKBUFFER_SIZE equ 320 * 150

KEY_ESC         equ 01h
KEY_CTRL        equ 1Dh
KEY_UP          equ 48h
KEY_LEFT        equ 4Bh
KEY_RIGHT       equ 4Dh
KEY_DOWN        equ 50h

; These words are overwritten by init_game with offsets inside CS.
back_buffer_ptr     equ 010Eh     ; 1100h, 48000 bytes
key_state_ptr       equ 0110h     ; CD80h, 128 bytes
object_pool_ptr     equ 0112h     ; CE00h, 32 objects * 16 bytes
star_pool_ptr       equ 0114h     ; D010h, 80 stars * 8 bytes
sprite_pixels_ptr   equ 0116h     ; CC80h, decompressed 16x16 aircraft bitmap
old_int9_vector     equ 0118h     ; original Int 9 vector, dword offset:segment
rand_seed           equ 011Ch

entry:
    call init_game
    call title_then_game
    call shutdown_game
    mov ax, 4C00h
    int 20h

runtime_slots_initial:
    ; Initial bytes are mostly placeholders; init_game overwrites 010Eh-011Fh.
    db 0Fh, 0Fh, 00h, 08h, 07h, 01h, 07h, 01h
    db 06h, 07h, 07h, 01h, 00h, 0Fh, 01h, 00h, 00h, 00h

encoded_credit_text:
    ; XOR AAh -> "Thank you for playing, by skywind3000@hotmail.com", CR/LF
    db 0FEh, 0C2h, 0CBh, 0C4h, 0C1h, 08Ah, 0D3h, 0C5h
    db 0DFh, 08Ah, 0CCh, 0C5h, 0D8h, 08Ah, 0DAh, 0C6h
    db 0CBh, 0D3h, 0C3h, 0C4h, 0CDh, 086h, 08Ah, 0C8h
    db 0D3h, 08Ah, 0D9h, 0C1h, 0D3h, 0DDh, 0C3h, 0C4h
    db 0CEh, 099h, 09Ah, 09Ah, 09Ah, 0EAh, 0C2h, 0C5h
    db 0DEh, 0C7h, 0CBh, 0C3h, 0C6h, 084h, 0C9h, 0C5h
    db 0C7h, 0A7h, 0A0h, 00h

encoded_title_text:
    ; XOR AAh -> "-= EXFORCE =-"
    db 087h, 097h, 08Ah, 0EFh, 0F2h, 0ECh, 0E5h
    db 0F8h, 0E9h, 0EFh, 08Ah, 097h, 087h, 00h

init_game:
    ; Lay out runtime buffers after the COM image:
    ;   1100h  frame buffer
    ;   CC80h  decompressed aircraft sprite
    ;   CD80h  keyboard state table
    ;   CE00h  object pool
    ;   D010h  star pool
    pushad
    mov ax, 1100h
    mov [back_buffer_ptr], ax
    add ax, 0BB80h
    mov [sprite_pixels_ptr], ax
    add ax, 0100h
    mov [key_state_ptr], ax
    add ax, 0080h
    mov [object_pool_ptr], ax
    add ax, 0210h
    mov [star_pool_ptr], ax

    ; Clear keyboard state table.
    mov di, [key_state_ptr]
    cld
    mov cx, 0280h
    db 33h, 0C0h              ; xor ax, ax
    rep stosb

    ; Save old Int 9 vector from IVT[9] at 0000:0024.
    push ds
    db 33h, 0C0h              ; xor ax, ax
    mov ds, ax
    mov es, ax
    mov si, 0024h
    lodsd
    pop ds
    mov [old_int9_vector], eax

    ; Install our Int 9 handler.
    mov ax, cs
    shl eax, 10h
    mov ax, keyboard_isr
    mov di, 0024h
    cli
    stosd

    ; Program PIT channel 0. This also contributes to PC speaker timing.
    mov al, 34h
    out 43h, al
    mov ax, 0087h
    out 40h, al
    db 8Ah, 0C4h              ; mov al, ah
    out 40h, al
    sti

    db 66h, 33h, 0C0h         ; xor eax, eax
    push ds
    pop es

    ; VGA 320x200x256.
    mov ax, 0013h
    int 10h

    ; Decompress RLE aircraft sprite into sprite_pixels_ptr.
    ; Bytes < C0h are literals. Bytes >= C0h encode run length in low 6 bits,
    ; followed by one byte to repeat.
    mov si, aircraft_rle
    mov bx, 0
    mov di, [sprite_pixels_ptr]
.decode_sprite:
    lodsb
    cmp al, 0C0h
    jnc .run
    stosb
    inc bx
    jmp short .advance
.run:
    and al, 3Fh
    push ax
    lodsb
    pop cx
    rep stosb
    inc bx
    inc bx
.advance:
    cmp bl, 9Bh
    jc .decode_sprite

    ; Seed RNG from BIOS timer ticks.
    db 33h, 0C0h              ; xor ax, ax
    int 1Ah
    and dx, 7FFFh
    mov [rand_seed], dx
    popad
    ret

shutdown_game:
    ; Restore old keyboard interrupt vector, silence PIT channel, return to text
    ; mode, then print the credit text and wait for a key.
    db 33h, 0C0h              ; xor ax, ax
    mov es, ax
    mov eax, [old_int9_vector]
    mov di, 0024h
    cli
    stosd
    mov al, 34h
    out 43h, al
    db 33h, 0C0h              ; xor ax, ax
    out 40h, al
    out 40h, al
    sti
    db 66h, 33h, 0C0h         ; xor eax, eax
    mov ax, 0003h
    int 10h
    push ds
    pop es
    call show_credit_and_wait
    ret

keyboard_isr:
    ; IRQ1 handler. Read scan code from port 60h and set key_state[scan&7F]
    ; to 1 on key press, 0 on key release.
    pusha
    push ds
    push es
    mov ax, cs
    mov ds, ax
    mov es, ax
    db 33h, 0C0h              ; xor ax, ax
    in al, 60h
    db 8Bh, 0C8h              ; mov cx, ax
    and cx, 007Fh
    mov bx, [key_state_ptr]
    db 03h, 0D9h              ; add bx, cx
    and al, 80h
    not al
    shr ax, 7
    mov [bx], al

    ; Acknowledge keyboard controller and PIC.
    in al, 61h
    or al, 80h
    out 61h, al
    and al, 7Fh
    out 61h, al
    mov al, 20h
    out 20h, al
    pop es
    pop ds
    popa
    iret

unused_rets:
    ret
    ret

title_then_game:
    ; Print title at row 13, then run the game.
    pusha
    mov ah, 02h
    mov bh, 0
    mov dx, 000Dh
    int 10h
    mov bl, 3
    mov si, encoded_title_text
    call print_xor_text
    popa
    call main_game
    ret

show_credit_and_wait:
    mov si, encoded_credit_text
    call print_xor_text
    db 33h, 0C0h              ; xor ax, ax
    int 16h
    ret

present_frame:
    ; Copy the 320x150 back buffer to A000:1F40. The 25-pixel top/bottom
    ; margins keep the playfield centered vertically.
    pusha
    mov si, [back_buffer_ptr]
    mov di, 1F40h
    mov cx, 5DC0h
    cld
    mov ax, VRAM_SEG
    mov es, ax
    rep movsw
    push cs
    pop es
    popa
    ret

clear_backbuffer:
    pusha
    mov di, [back_buffer_ptr]
    mov cx, 5DC0h
    push cs
    pop es
    db 33h, 0C0h              ; xor ax, ax
    cld
    rep stosw
    popa
    ret

plot_pixel:
    ; Args: push color, y, x. Draw into the back buffer if inside 320x150.
    enter 0, 0
    pusha
    mov cx, [bp+4]            ; x
    mov dx, [bp+6]            ; y
    mov al, [bp+8]            ; color
    cmp cx, SCREEN_W
    jnc .done
    cmp dx, GAME_H
    jnc .done
    mov di, [back_buffer_ptr]
    db 8Bh, 0DAh              ; mov bx, dx
    shl dx, 8
    shl bx, 6
    db 03h, 0DAh              ; add bx, dx ; y * 320
    db 03h, 0D9h              ; add bx, cx
    db 03h, 0FBh              ; add di, bx
    mov [di], al
.done:
    popa
    leave
    ret

draw_aircraft:
    ; Args: push flip_vertical, y, x.
    ; Draws a 16x16 sprite from decompressed sprite_pixels_ptr. The third arg
    ; selects whether rows are drawn normal or vertically flipped.
    enter 2, 0
    pusha
    mov bx, [sprite_pixels_ptr]
    mov dx, 0
    sub word [bp+4], 8
    sub word [bp+6], 8
    mov word [bp-2], 15
.pixel_row:
    mov cx, 0
.pixel:
    db 33h, 0C0h              ; xor ax, ax
    mov al, [bx]
    inc bx
    cmp al, 0
    jz .skip
    push ax
    mov ax, [bp+6]
    cmp word [bp+8], 0
    jz .normal_y
    db 03h, 0C2h              ; add ax, dx
    jmp short .got_y
.normal_y:
    add ax, [bp-2]
.got_y:
    push ax
    mov ax, [bp+4]
    db 03h, 0C1h              ; add ax, cx
    push ax
    call plot_pixel
    add sp, 6
.skip:
    inc cx
    cmp cx, 16
    jc .pixel
    dec word [bp-2]
    inc dx
    cmp dx, 16
    jc .pixel_row
    mov cx, [bp+4]
    mov dx, [bp+6]
    popa
    leave
    ret

random_mod:
    ; Args: push divisor. Return AX = pseudo-random value % divisor.
    enter 0, 0
    push dx
    mov eax, [rand_seed]
    imul eax, eax, 015A4E35h
    inc eax
    mov [rand_seed], eax
    shr eax, 10h
    and eax, 00007FFFh
    cwd
    idiv word [bp+4]
    db 8Bh, 0C2h              ; mov ax, dx
    pop dx
    leave
    ret

find_free_object_slot:
    ; Scan 32 object records, 16 bytes each. Return AX = free slot index.
    enter 0, 0
    mov bx, [object_pool_ptr]
    mov cx, 20h
    mov ax, 0
.scan:
    cmp word [bx], 0
    jz .done
    add bx, 10h
    inc ax
    dec cx
    jnz .scan
.done:
    leave
    ret

print_xor_text:
    ; BIOS teletype print. String bytes are decoded with XOR AAh.
    cld
.next:
    lodsb
    cmp al, 0
    jz .done
    mov ah, 0Eh
    xor al, 0AAh
    pusha
    int 10h
    popa
    jmp short .next
.done:
    ret

aircraft_rle:
    ; RLE-compressed 16x16 aircraft bitmap. Decompressed size is 256 bytes.
    db 0C3h, 00h, 1Dh, 19h, 0C4h, 00h, 19h, 1Dh
    db 0C1h, 0C4h, 0C7h, 00h, 0C2h, 19h, 0C4h, 00h
    db 19h, 00h, 0C1h, 0C4h, 0C4h, 00h, 0C2h, 70h
    db 00h, 19h, 0C1h, 0C4h, 0C2h, 28h, 1Dh, 0C2h
    db 70h, 28h, 70h, 00h, 0C3h, 70h, 0C2h, 28h
    db 0C2h, 70h, 0C2h, 28h, 0C2h, 19h, 70h, 0C2h
    db 28h, 0C6h, 70h, 28h, 70h, 19h, 0C2h, 28h
    db 0C3h, 70h, 0C2h, 28h, 19h, 28h, 0C2h, 70h
    db 0C2h, 00h, 0C2h, 70h, 19h, 0C3h, 28h, 70h
    db 0C3h, 28h, 19h, 28h, 70h, 0C4h, 00h, 70h
    db 19h, 28h, 70h, 28h, 0C3h, 70h, 28h, 19h
    db 70h, 0C6h, 00h, 1Dh, 70h, 00h, 28h, 00h
    db 70h, 00h, 70h, 1Dh, 0C7h, 00h, 1Dh, 70h
    db 00h, 28h, 36h, 70h, 00h, 70h, 1Dh, 0C7h
    db 00h, 1Dh, 0C2h, 00h, 28h, 36h, 70h, 0C2h
    db 00h, 1Dh, 0C9h, 00h, 28h, 70h, 19h, 0C2h
    db 70h, 0CBh, 00h, 28h, 70h, 19h, 0C2h, 70h
    db 0CBh, 00h, 28h, 0C4h, 70h, 0CCh, 00h, 28h
    db 0C2h, 70h, 0CDh, 00h, 28h, 19h, 0CFh, 00h
    db 70h, 0C8h, 00h

main_game:
    ; Local stack layout, relative to BP:
    ;   -02 plot_pixel pointer        -04 draw_aircraft pointer
    ;   -06 random_mod pointer        -08 find_free_slot pointer
    ;   -0A star_pool                 -0C object_pool
    ;   -0E object scan pointer       -0F alive flag
    ;   -10 ctrl fire latch           -11 active bullet count
    ;   -14 key_state                 -18 last frame tick
    ;   -1E player x                  -20 player y
    ;   -2E frame counter             -32 score / killed enemies
    enter 32h, 0
    push si
    push di
    mov word [bp-2], plot_pixel
    mov word [bp-4], draw_aircraft
    mov word [bp-6], random_mod
    mov word [bp-8], find_free_object_slot
    mov byte [bp-0Fh], 1
    mov byte [bp-10h], 0
    mov byte [bp-11h], 0
    mov dword [bp-18h], 0
    mov word [bp-1Eh], 160
    mov word [bp-20h], 120
    mov word [bp-2Eh], 0
    mov word [bp-32h], 0
    mov ax, [key_state_ptr]
    mov [bp-14h], ax
    mov ax, [star_pool_ptr]
    mov [bp-0Ah], ax
    mov ax, [object_pool_ptr]
    mov [bp-0Ch], ax

    ; Initialize 80 falling stars.
    mov word [bp-22h], 0
    mov si, [bp-0Ah]
    jmp short .init_stars_test
.init_star:
    push word SCREEN_W
    call [bp-6]
    pop cx
    mov [si], ax              ; x
    push word 200
    call [bp-6]
    pop cx
    db 05h, 0CEh, 0FFh        ; add ax, -50
    mov [si+2], ax            ; y
    cmp word [bp-22h], 35h
    jnl .fast_star
    mov word [si+4], 1        ; speed
    mov word [si+6], 17h      ; color
    jmp short .next_star
.fast_star:
    mov word [si+4], 2
    mov word [si+6], 1Ch
.next_star:
    inc word [bp-22h]
    add si, 8
.init_stars_test:
    cmp word [bp-22h], 50h
    jl .init_star
    jmp .frame_test

.frame:
    ; Wait until about 12 BIOS ticks elapsed.
    mov eax, [bp-18h]
    mov [bp-1Ch], eax
    jmp short .have_tick
.read_tick:
    pushad
    db 33h, 0C0h              ; xor ax, ax
    int 1Ah
    db 8Bh, 0C1h              ; mov ax, cx
    shl eax, 10h
    db 8Bh, 0C2h              ; mov ax, dx
    mov [bp-1Ch], eax
    popad
.have_tick:
    mov eax, [bp-1Ch]
    sub eax, [bp-18h]
    cmp eax, 12
    jc .read_tick
    mov eax, [bp-1Ch]
    mov [bp-18h], eax

    mov ax, clear_backbuffer
    call ax

    ; Update and draw stars.
    mov word [bp-22h], 50h
    mov si, [bp-0Ah]
    jmp short .stars_test
.star_loop:
    mov al, [si+6]
    push ax
    push word [si+2]
    push word [si]
    call [bp-2]
    add sp, 6
    mov ax, [si+4]
    add [si+2], ax
    cmp word [si+2], GAME_H
    jng .star_visible
    push word SCREEN_W
    call [bp-6]
    pop cx
    mov [si], ax
    push byte 60
    call [bp-6]
    pop cx
    neg ax
    mov [si+2], ax
.star_visible:
    dec word [bp-22h]
    add si, 8
.stars_test:
    cmp word [bp-22h], 0
    jnz .star_loop

    ; Keyboard movement, using the Int9-maintained state table.
    mov bx, [bp-14h]
    cmp byte [bx+KEY_LEFT], 0
    jz .no_left
    sub word [bp-1Eh], 2
    cmp word [bp-1Eh], 0
    jnl .no_left
    mov word [bp-1Eh], 0
.no_left:
    mov bx, [bp-14h]
    cmp byte [bx+KEY_RIGHT], 0
    jz .no_right
    add word [bp-1Eh], 2
    cmp word [bp-1Eh], SCREEN_W
    jng .no_right
    mov word [bp-1Eh], SCREEN_W
.no_right:
    mov bx, [bp-14h]
    cmp byte [bx+KEY_UP], 0
    jz .no_up
    sub word [bp-20h], 3
    cmp word [bp-20h], 0
    jnl .no_up
    mov word [bp-20h], 0
.no_up:
    mov bx, [bp-14h]
    cmp byte [bx+KEY_DOWN], 0
    jz .no_down
    add word [bp-20h], 2
    cmp word [bp-20h], GAME_H
    jng .no_down
    mov word [bp-20h], GAME_H
.no_down:
    mov bx, [bp-14h]
    cmp byte [bx+KEY_ESC], 0
    jz .not_escape
    jmp .game_over
.not_escape:

    ; CTRL fires, with a latch so holding CTRL does not spawn every frame.
    mov bx, [bp-14h]
    cmp byte [bx+KEY_CTRL], 0
    jz .ctrl_up
    cmp byte [bp-10h], 0
    jnz .process_objects
    mov byte [bp-10h], 1
    call [bp-8]
    shl ax, 4
    mov di, [bp-0Ch]
    db 03h, 0F8h              ; add di, ax
    cmp byte [bp-11h], 2
    jnl .process_objects
    inc byte [bp-11h]
    mov word [di], 2          ; object type 2 = player laser
    mov ax, [bp-1Eh]
    mov [di+8], ax
    mov ax, [bp-20h]
    db 05h, 0F7h, 0FFh        ; add ax, -9
    mov [di+0Ah], ax
    jmp short .process_objects
.ctrl_up:
    mov byte [bp-10h], 0

.process_objects:
    ; Object record: +0 type, +2 active/phase, +4 timer/scratch,
    ; +8 x, +A y. Type 1 = enemy, type 2 = laser.
    mov word [bp-22h], 0
    mov di, [bp-0Ch]
    jmp .objects_test

.object_loop:
    mov ax, [di+8]
    mov [bp-2Ah], ax          ; obj_x
    mov ax, [di+0Ah]
    mov [bp-2Ch], ax          ; obj_y
    mov ax, [di]
    mov [bp-30h], ax          ; obj_type
    db 3Dh, 01h, 00h          ; cmp ax, 1
    jz .enemy
    db 3Dh, 02h, 00h          ; cmp ax, 2
    jnz .not_laser
    jmp .laser
.not_laser:
    jmp .store_object

.enemy:
    ; Enemy collision with player.
    cmp word [di+2], 0
    jz .enemy_inactive_anim
    mov ax, [bp-2Ah]
    sub ax, [bp-1Eh]
    mov [bp-26h], ax
    cmp word [bp-26h], 0
    jnl .enemy_dx_abs
    neg ax
    mov [bp-26h], ax
.enemy_dx_abs:
    mov ax, [bp-2Ch]
    sub ax, [bp-20h]
    mov [bp-28h], ax
    cmp word [bp-28h], 0
    jnl .enemy_dy_abs
    neg ax
    mov [bp-28h], ax
.enemy_dy_abs:
    cmp word [bp-26h], 13
    jnl .enemy_move
    cmp word [bp-28h], 13
    jnl .enemy_move
    mov byte [bp-0Fh], 0

.enemy_move:
    push byte 2
    call [bp-6]
    pop cx
    inc ax
    add [bp-2Ch], ax
    cmp word [bp-2Ch], 160
    jng .enemy_maybe_track
    mov word [bp-30h], 0
.enemy_maybe_track:
    push byte 8
    call [bp-6]
    pop cx
    db 0Bh, 0C0h              ; or ax, ax
    jnz .draw_enemy
    mov ax, [bp-2Ah]
    cmp ax, [bp-1Eh]
    jng .enemy_right
    mov ax, -1
    jmp short .enemy_apply_x
.enemy_right:
    mov ax, 1
.enemy_apply_x:
    add [bp-2Ah], ax
    jmp short .draw_enemy

.enemy_inactive_anim:
    inc word [di+4]
    mov ax, [di+4]
    db 3Dh, 28h, 00h          ; cmp ax, 40
    jng .draw_enemy
    mov word [bp-30h], 0

.draw_enemy:
    ; Flicker inactive enemies during explosion phase.
    mov ax, [di+2]
    mov dx, [di+4]
    and dx, 1
    db 0Bh, 0C2h              ; or ax, dx
    jnz .enemy_visible
    jmp .store_object
.enemy_visible:
    push byte 1
    push word [bp-2Ch]
    push word [bp-2Ah]
    call [bp-4]
    add sp, 6
    jmp .store_object

.laser:
    ; Draw laser as two vertical 9-pixel strips and move upward.
    mov ax, [bp-2Ch]
    db 05h, 0FBh, 0FFh        ; add ax, -5
    mov [bp-24h], ax
    jmp short .laser_test
.laser_pixel:
    push byte 9
    push word [bp-24h]
    mov ax, [bp-2Ah]
    db 05h, 0FBh, 0FFh        ; add ax, -5
    push ax
    call [bp-2]
    add sp, 6
    push byte 9
    push word [bp-24h]
    mov ax, [bp-2Ah]
    db 05h, 03h, 00h          ; add ax, 3
    push ax
    call [bp-2]
    add sp, 6
    inc word [bp-24h]
.laser_test:
    mov ax, [bp-2Ch]
    db 05h, 05h, 00h          ; add ax, 5
    cmp ax, [bp-24h]
    jg .laser_pixel
    sub word [bp-2Ch], 4
    cmp word [bp-2Ch], -20
    jnl .check_laser_hits
    mov word [bp-30h], 0
    dec byte [bp-11h]

.check_laser_hits:
    ; Compare this laser against enemy objects.
    mov word [bp-24h], 0
    mov ax, [bp-0Ch]
    mov [bp-0Eh], ax
    jmp short .hit_test_loop_check
.hit_test_loop:
    mov bx, [bp-0Eh]
    cmp word [bx], 1
    jnz .next_hit
    cmp word [bx+2], 1
    jnz .next_hit
    cmp word [bp-30h], 0
    jz .next_hit
    mov ax, [bp-2Ah]
    sub ax, [bx+8]
    mov [bp-26h], ax
    cmp word [bp-26h], 0
    jnl .hit_dx_abs
    neg ax
    mov [bp-26h], ax
.hit_dx_abs:
    mov bx, [bp-0Eh]
    mov ax, [bp-2Ch]
    sub ax, [bx+0Ah]
    mov [bp-28h], ax
    cmp word [bp-28h], 0
    jnl .hit_dy_abs
    neg ax
    mov [bp-28h], ax
.hit_dy_abs:
    cmp word [bp-26h], 15
    jnl .next_hit
    cmp word [bp-28h], 15
    jnl .next_hit
    mov bx, [bp-0Eh]
    mov word [bx+2], 0       ; enemy begins explosion/flicker phase
    mov word [bp-30h], 0     ; remove laser
    dec byte [bp-11h]
    inc word [bp-32h]        ; score/kills
.next_hit:
    inc word [bp-24h]
    add word [bp-0Eh], 16
.hit_test_loop_check:
    cmp word [bp-24h], 32
    jl .hit_test_loop

.store_object:
    mov ax, [bp-2Ah]
    mov [di+8], ax
    mov ax, [bp-2Ch]
    mov [di+0Ah], ax
    mov ax, [bp-30h]
    mov [di], ax
    inc word [bp-22h]
    add di, 16
.objects_test:
    cmp word [bp-22h], 32
    jnl .spawn_enemy
    jmp .object_loop

.spawn_enemy:
    ; Roughly 1/20 chance per frame to spawn a new enemy.
    push byte 20
    call [bp-6]
    pop cx
    db 0Bh, 0C0h              ; or ax, ax
    jnz .draw_progress
    call [bp-8]
    shl ax, 4
    mov dx, [bp-0Ch]
    db 03h, 0D0h              ; add dx, ax
    mov [bp-0Eh], dx
    mov bx, [bp-0Eh]
    mov word [bx], 1
    mov word [bx+2], 1
    mov word [bx+4], 0
    push word SCREEN_W
    call [bp-6]
    pop cx
    mov bx, [bp-0Eh]
    mov [bx+8], ax
    push byte 10
    call [bp-6]
    pop cx
    db 05h, 0ECh, 0FFh        ; add ax, -20
    mov bx, [bp-0Eh]
    mov [bx+0Ah], ax

.draw_progress:
    ; Draw a right-edge vertical progress/difficulty meter based on kills.
    mov ax, GAME_H
    sub ax, [bp-32h]
    mov [bp-2Ch], ax
    cmp word [bp-2Ch], 0
    jnl .progress_ok
    mov word [bp-2Ch], 0
.progress_ok:
    mov ax, [bp-2Ch]
    mov [bp-22h], ax
    jmp short .progress_test
.progress_pixel:
    push byte 4
    push word [bp-22h]
    push word 319
    call [bp-2]
    add sp, 6
    inc word [bp-22h]
.progress_test:
    cmp word [bp-22h], GAME_H
    jl .progress_pixel

    ; First 140 frames blink the player. After that, draw every frame.
    cmp word [bp-2Eh], 140
    jnl .draw_player_solid
    mov byte [bp-0Fh], 1
    mov ax, [bp-2Eh]
    db 25h, 01h, 00h          ; and ax, 1
    mov [bp-26h], ax
    jmp short .player_blink_ready
.draw_player_solid:
    mov word [bp-26h], 1
.player_blink_ready:
    cmp word [bp-26h], 0
    jz .present
    push byte 0
    push word [bp-20h]
    push word [bp-1Eh]
    call [bp-4]
    add sp, 6

.present:
    mov ax, present_frame
    call ax
    inc word [bp-2Eh]

.frame_test:
    cmp byte [bp-0Fh], 0
    jz .game_over
    jmp .frame

.game_over:
    ; If alive flag is already false, pause before returning to shutdown.
    cmp byte [bp-0Fh], 0
    jnz .return
    mov eax, [bp-18h]
    mov [bp-1Ch], eax
    jmp short .game_over_have_tick
.game_over_read_tick:
    pushad
    db 33h, 0C0h              ; xor ax, ax
    int 1Ah
    db 8Bh, 0C1h              ; mov ax, cx
    shl eax, 10h
    db 8Bh, 0C2h              ; mov ax, dx
    mov [bp-1Ch], eax
    popad
.game_over_have_tick:
    mov eax, [bp-1Ch]
    sub eax, [bp-18h]
    cmp eax, 720
    jc .game_over_read_tick
.return:
    pop di
    pop si
    leave
    ret

trailing_bytes:
    ; Unreached bytes in the original COM image.
    db 0FFh, 53h, 4Bh, 59h, 57h, 49h, 4Eh, 44h, 30h, 35h
