; Readable data include for SNC_OMNI_UNPACKED.ASM.
; Derived directly from SNC_OMNI.COM via the unpacked runtime image.
; Absolute offsets in comments assume this file is included at 0DCBh.
; Some compact streams are intentionally kept as bytes because their semantics
; are defined by small custom decoders in the code.

; 0DCBh: numeric constants used by projection/rasterization.
raster_scale_1p2:        dd 03F99999Ah ; float 1.2
near_clip_bias:          dw 0000Dh     ; used by prepare_and_clip_face
screen_center_x:         dw 00064h     ; 100
screen_center_y:         dw 000A0h     ; 160
projection_divisor:      dw 00700h
fixed_one_16_16:         dd 00010000h
rng_original_seed:       dd 008088405h
rng_state_multiplier:    dd 0000010FBh ; overwritten with current RNG state

; 0DE3h..0F27h: input to build_midi_channels/decode_rle_or_script
packed_music_and_channel_stream:
    db 002h, 050h, 0FBh, 0FEh, 032h, 004h, 045h, 002h, 03Eh, 002h, 045h, 002h, 051h, 002h, 03Eh, 002h ; .P..2.E.>.E.Q.>.
    db 045h, 002h, 04Fh, 002h, 03Eh, 002h, 045h, 002h, 051h, 002h, 03Eh, 002h, 045h, 002h, 04Fh, 002h ; E.O.>.E.Q.>.E.O.
    db 051h, 002h, 000h, 0FEh, 032h, 004h, 046h, 002h, 03Eh, 002h, 046h, 002h, 051h, 002h, 03Eh, 002h ; Q...2.F.>.F.Q.>.
    db 046h, 002h, 04Fh, 002h, 03Eh, 002h, 046h, 002h, 052h, 002h, 03Eh, 002h, 046h, 002h, 04Fh, 002h ; F.O.>.F.R.>.F.O.
    db 052h, 002h, 000h, 000h, 037h, 020h, 038h, 020h, 033h, 020h, 035h, 018h, 037h, 008h, 039h, 020h ; R...7 8 3 5.7.9 
    db 032h, 020h, 03Ch, 030h, 03Ah, 008h, 039h, 008h, 037h, 040h, 0FEh, 043h, 010h, 03Eh, 010h, 045h ; 2 <0:.9.7@.C.>.E
    db 010h, 046h, 010h, 000h, 0FEh, 046h, 010h, 045h, 010h, 03Eh, 010h, 041h, 010h, 000h, 000h, 004h ; .F...F.E.>.A....
    db 032h, 001h, 080h, 001h, 080h, 041h, 01Ch, 040h, 002h, 041h, 002h, 040h, 010h, 03Eh, 008h, 03Ch ; 2....A.@.A.@.>.<
    db 008h, 043h, 01Ch, 041h, 004h, 03Ch, 010h, 041h, 008h, 040h, 008h, 03Eh, 020h, 032h, 010h, 040h ; .C.A.<.A.@.> 2.@
    db 008h, 041h, 008h, 043h, 020h, 03Ch, 010h, 03Eh, 008h, 040h, 008h, 03Eh, 080h, 043h, 080h, 043h ; .A.C <.>.@.>.C.C
    db 010h, 040h, 010h, 042h, 010h, 040h, 008h, 042h, 008h, 048h, 030h, 046h, 010h, 043h, 020h, 037h ; .@.B.@.B.H0F.C 7
    db 020h, 0FEh, 01Fh, 020h, 037h, 020h, 000h, 0FEh, 01Ah, 020h, 032h, 020h, 000h, 000h, 005h, 059h ;  .. 7 ... 2 ...Y
    db 0FBh, 001h, 080h, 000h, 043h, 008h, 04Ah, 018h, 044h, 008h, 04Bh, 018h, 03Fh, 008h, 046h, 018h ; ....C.J.D.K.?.F.
    db 03Ch, 008h, 045h, 010h, 043h, 008h, 03Eh, 008h, 045h, 010h, 043h, 008h, 03Eh, 008h, 042h, 018h ; <.E.C.>.E.C.>.B.
    db 03Fh, 008h, 043h, 018h, 03Ch, 008h, 043h, 010h, 045h, 008h, 037h, 008h, 043h, 018h, 02Bh, 008h ; ?.C.<.C.E.7.C.+.
    db 032h, 018h, 0FEh, 01Fh, 001h, 026h, 03Fh, 000h, 0FEh, 01Ah, 001h, 021h, 03Fh, 000h, 000h, 00Ah ; 2....&?....!?...
    db 000h, 0F0h, 02Ah, 002h, 02Ah, 002h, 02Ah, 002h, 02Ah, 001h, 02Ah, 001h, 000h, 0F0h, 024h, 002h ; ..*.*.*.*.*...$.
    db 02Ah, 002h, 02Ah, 002h, 02Ah, 001h, 02Ah, 001h, 000h, 0E2h, 024h, 002h, 02Ah, 002h, 02Eh, 002h ; *.*.*.*...$.*...
    db 024h, 001h, 02Ah, 001h, 026h, 002h, 02Ah, 002h, 02Eh, 002h, 026h, 001h, 02Ah, 001h, 024h, 002h ; $.*.&.*...&.*.$.
    db 026h, 002h, 024h, 002h, 02Ah, 001h, 02Ah, 001h, 026h, 002h, 02Ah, 002h, 02Eh, 002h, 026h, 001h ; &.$.*.*.&.*...&.
    db 02Ah, 001h, 000h, 000h, 000h ; *....

; 0F28h..0F68h: palette ramp control bytes consumed at 0191h
palette_control_points:
    db 010h, 01Fh, 03Fh, 03Fh, 03Fh, 001h, 000h, 000h, 000h, 01Fh, 028h, 020h, 03Fh, 001h, 000h, 000h ; ..???.....( ?...
    db 000h, 01Fh, 03Fh, 000h, 000h, 001h, 006h, 001h, 000h, 01Fh, 03Fh, 029h, 014h, 001h, 000h, 000h ; ..?.......?)....
    db 000h, 01Fh, 03Fh, 03Fh, 008h, 001h, 000h, 000h, 000h, 01Fh, 038h, 038h, 03Fh, 001h, 03Fh, 000h ; ..??......88?.?.
    db 000h, 010h, 03Fh, 03Fh, 000h, 010h, 03Fh, 000h, 000h, 001h, 016h, 005h, 000h, 007h, 03Fh, 038h ; ..??..?.......?8
    db 011h ; .

; 0F69h..1004h: 26 records of 6 bytes: texture/mode, x0, y0, x1, y1, color/addend
texture_rect_recipes:
    db 013h, 00Fh, 00Fh, 031h, 031h, 00Ah, 013h, 010h, 010h, 030h, 030h, 011h ; ...11....00.
    db 013h, 011h, 011h, 02Fh, 02Fh, 018h, 013h, 012h, 012h, 02Eh, 02Eh, 0BEh ; ...//.......
    db 013h, 015h, 015h, 02Bh, 02Bh, 01Eh, 025h, 000h, 000h, 03Eh, 01Eh, 003h ; ...++.%..>..
    db 025h, 003h, 003h, 03Eh, 01Eh, 007h, 025h, 003h, 003h, 03Bh, 01Bh, 0FCh ; %..>..%..;..
    db 025h, 000h, 020h, 03Eh, 03Eh, 003h, 025h, 003h, 023h, 03Eh, 03Eh, 007h ; %. >>.%.#>>.
    db 025h, 003h, 023h, 03Bh, 03Bh, 0FCh, 025h, 000h, 000h, 03Fh, 03Fh, 0FEh ; %.#;;.%..??.
    db 02Ch, 000h, 00Ah, 03Fh, 00Fh, 0F6h, 02Ch, 000h, 00Bh, 03Fh, 010h, 004h ; ,..?..,..?..
    db 02Ch, 000h, 02Fh, 03Fh, 034h, 0F6h, 02Ch, 000h, 030h, 03Fh, 035h, 004h ; ,./?4.,.0?5.
    db 02Eh, 013h, 018h, 02Ch, 027h, 005h, 02Eh, 014h, 019h, 02Ch, 027h, 0F4h ; ...,'....,'.
    db 02Eh, 014h, 019h, 02Bh, 026h, 007h, 03Eh, 014h, 019h, 02Bh, 026h, 006h ; ...+&.>..+&.
    db 02Fh, 000h, 018h, 03Fh, 01Eh, 006h, 02Fh, 000h, 019h, 03Fh, 01Fh, 0FAh ; /..?../..?..
    db 03Fh, 000h, 019h, 03Fh, 01Eh, 006h, 02Fh, 000h, 020h, 03Fh, 026h, 006h ; ?..?../. ?&.
    db 02Fh, 000h, 021h, 03Fh, 027h, 0FAh, 03Fh, 000h, 021h, 03Fh, 026h, 006h ; /.!?'.?.!?&.

; 1005h..101Eh: 13 source/offset words used to derive textures 2..15
texture_noise_source_map:
    db 022h, 0C0h, 026h, 001h, 026h, 001h, 026h, 000h, 020h, 000h, 020h, 020h, 020h, 040h, 022h, 060h ; ".&.&.&. .   @"`
    db 024h, 000h, 022h, 060h, 024h, 000h, 024h, 000h, 024h, 000h ; $."`$.$.$.

; 101Fh..1020h: two bytes immediately before the 5x5 sprite table
sprite_table_prefix:
    db 024h, 000h ; $.

; 1021h..1039h: 5x5 brightness sprite reused for stars/sparkles.
sparkle_5x5_sprite:
    db 000h, 000h, 003h, 000h, 000h
    db 000h, 002h, 005h, 002h, 000h
    db 003h, 005h, 007h, 005h, 003h
    db 000h, 002h, 005h, 002h, 000h
    db 000h, 000h, 003h, 000h, 000h

; 103Ah..103Fh: offsets used by clip_edge_against_near; byte 103Fh also
; starts the following projection/UV seed table, so the labels intentionally overlap semantically.
clip_interpolation_offsets:
    db 004h, 004h, 00Ch, 004h, 008h ; .....
projection_uv_seed:
    db 000h, 000h, 03Fh, 03Fh, 03Fh, 000h, 000h, 03Fh ; ..???..?

; 1047h..105Eh: six cube faces x four signed corner indices
cube_face_corner_lookup:
    db 008h, 028h, 030h, 010h, 018h, 038h, 020h, 000h, 010h, 030h, 038h, 018h ; .(0..8 ..08.
    db 000h, 020h, 028h, 008h, 038h, 030h, 028h, 020h, 000h, 008h, 010h, 018h ; . (.80( ....

; 105Fh..108Bh: 15 XYZ byte triples expanded into float/word cube corner tables
cube_corner_coord_table:
    db 0E0h, 0E0h, 0E0h, 020h, 0E0h, 0E0h, 020h, 020h, 0E0h, 0E0h, 020h, 0E0h, 0E0h, 0E0h, 020h ; ... ..  .. ... 
    db 020h, 0E0h, 020h, 020h, 020h, 020h, 0E0h, 020h, 020h, 040h, 000h, 000h, 0C0h, 000h, 000h ;  .    .  @.....
    db 000h, 040h, 000h, 000h, 0C0h, 000h, 000h, 000h, 040h, 000h, 000h, 0C0h, 000h, 000h, 000h ; .@......@......

; 108Ch..12E2h: four compact scene streams decoded by build_scene_geometry
scene_description_streams:
    db 071h, 070h, 000h, 006h, 072h, 000h, 000h, 006h, 071h, 000h, 070h, 006h, 073h, 007h, 070h, 006h ; qp..r...q.p.s.p.
    db 073h, 007h, 000h, 006h, 070h, 007h, 007h, 006h, 074h, 000h, 007h, 006h, 070h, 000h, 007h, 040h ; s...p...t...p..@
    db 072h, 070h, 007h, 050h, 072h, 070h, 000h, 050h, 071h, 070h, 070h, 050h, 073h, 000h, 070h, 040h ; rp.Prp.PqppPs.p@
    db 071h, 000h, 000h, 040h, 072h, 000h, 000h, 050h, 071h, 000h, 070h, 050h, 073h, 007h, 070h, 046h ; q..@r..Pq.pPs.pF
    db 073h, 000h, 000h, 046h, 070h, 007h, 007h, 046h, 072h, 000h, 007h, 050h, 071h, 000h, 000h, 000h ; s..Fp..Fr..Pq...
    db 071h, 000h, 000h, 000h, 071h, 000h, 0BBh, 056h, 070h, 00Fh, 0BBh, 046h, 0FFh, 033h, 000h, 000h ; q...q..Vp..F.3..
    db 000h, 0F0h, 000h, 007h, 006h, 0E4h, 0B0h, 000h, 0BBh, 046h, 0E4h, 090h, 000h, 0BBh, 056h, 0E4h ; .........F....V.
    db 090h, 000h, 0BBh, 056h, 0E4h, 030h, 000h, 0BBh, 056h, 0F0h, 000h, 0BBh, 056h, 011h, 0F0h, 000h ; ...V.0..V...V...
    db 0BBh, 046h, 011h, 0B0h, 000h, 0BBh, 056h, 011h, 090h, 000h, 0BBh, 056h, 011h, 0B0h, 000h, 0BBh ; .F....V....V....
    db 056h, 011h, 0F0h, 000h, 0BBh, 056h, 011h, 0F0h, 000h, 0BBh, 046h, 011h, 0B0h, 000h, 0BBh, 056h ; V....V....F....V
    db 011h, 030h, 000h, 0BBh, 056h, 010h, 000h, 0BBh, 056h, 034h, 000h, 000h, 000h, 032h, 005h, 000h ; .0..V...V4...2..
    db 080h, 035h, 005h, 080h, 080h, 035h, 005h, 080h, 000h, 033h, 005h, 080h, 008h, 033h, 005h, 000h ; .5...5...3...3..
    db 008h, 074h, 005h, 008h, 008h, 074h, 005h, 000h, 000h, 073h, 005h, 008h, 080h, 075h, 000h, 000h ; .t...t...s...u..
    db 000h, 075h, 005h, 008h, 088h, 070h, 000h, 000h, 000h, 074h, 064h, 008h, 008h, 074h, 060h, 008h ; .u...p...td..t`.
    db 000h, 072h, 064h, 008h, 080h, 005h, 060h, 000h, 080h, 005h, 060h, 000h, 000h, 002h, 060h, 000h ; .rd...`...`...`.
    db 008h, 034h, 060h, 000h, 008h, 034h, 060h, 000h, 000h, 032h, 060h, 000h, 080h, 035h, 060h, 000h ; .4`..4`..2`..5`.
    db 080h, 035h, 060h, 000h, 000h, 032h, 060h, 000h, 008h, 034h, 035h, 000h, 008h, 014h, 065h, 000h ; .5`..2`..45...e.
    db 000h, 032h, 035h, 000h, 080h, 035h, 035h, 000h, 080h, 015h, 065h, 000h, 000h, 032h, 035h, 000h ; .25..55...e..25.
    db 008h, 034h, 035h, 080h, 008h, 014h, 065h, 000h, 000h, 032h, 035h, 080h, 080h, 075h, 000h, 000h ; .45...e..25..u..
    db 000h, 052h, 065h, 0E0h, 077h, 032h, 064h, 00Eh, 077h, 012h, 065h, 000h, 077h, 000h, 065h, 000h ; .Re.w2d.w.e.w.e.
    db 077h, 0FFh, 032h, 000h, 000h, 000h, 0F0h, 000h, 000h, 000h, 014h, 0B0h, 000h, 000h, 000h, 014h ; w.2.............
    db 030h, 000h, 000h, 000h, 0F0h, 000h, 000h, 000h, 0F4h, 0F0h, 000h, 0DDh, 056h, 0F4h, 030h, 000h ; 0...........V.0.
    db 0DDh, 046h, 030h, 000h, 0DDh, 056h, 030h, 000h, 0DDh, 056h, 032h, 000h, 000h, 050h, 030h, 00Ah ; .F0..V0..V2..P0.
    db 0A0h, 050h, 033h, 000h, 0A0h, 050h, 030h, 000h, 000h, 050h, 032h, 070h, 000h, 050h, 030h, 000h ; .P3..P0..P2p.P0.
    db 0A0h, 050h, 033h, 0A0h, 0A7h, 050h, 033h, 000h, 000h, 000h, 031h, 0A0h, 07Ah, 050h, 031h, 000h ; .P3..P3...1.zP1.
    db 00Ah, 050h, 031h, 000h, 00Ah, 050h, 032h, 00Ah, 00Ah, 050h, 035h, 000h, 000h, 000h, 072h, 00Ah ; .P1..P2..P5...r.
    db 000h, 000h, 070h, 00Ah, 0A0h, 000h, 073h, 000h, 0A0h, 000h, 070h, 000h, 000h, 000h, 072h, 000h ; ..p...s...p...r.
    db 000h, 000h, 070h, 000h, 0A0h, 000h, 073h, 0A0h, 0A0h, 000h, 073h, 0A0h, 000h, 099h, 071h, 0A0h ; ..p...s...s...q.
    db 00Ah, 000h, 071h, 000h, 00Ah, 000h, 071h, 000h, 00Ah, 000h, 075h, 00Ah, 00Ah, 000h, 070h, 00Ch ; ..q...q...u...p.
    db 00Ch, 003h, 070h, 000h, 00Ch, 003h, 070h, 000h, 00Ch, 003h, 072h, 0C0h, 07Ch, 003h, 072h, 000h ; ..p...p...r.|.r.
    db 000h, 000h, 071h, 0C0h, 0C7h, 003h, 073h, 000h, 0C0h, 003h, 071h, 070h, 000h, 003h, 072h, 000h ; ..q...s...qp..r.
    db 000h, 003h, 071h, 000h, 0C0h, 003h, 073h, 00Ch, 0C0h, 003h, 071h, 000h, 000h, 003h, 031h, 00Ch ; ..q...s...q...1.
    db 0CCh, 0A3h, 0FFh, 032h, 000h, 000h, 000h, 0F0h, 000h, 070h, 006h, 014h, 0B0h, 000h, 0DDh, 046h ; ...2.....p.....F
    db 014h, 030h, 000h, 0DDh, 056h, 0B2h, 000h, 00Dh, 056h, 0C4h, 032h, 0DDh, 000h, 056h, 032h, 0DDh ; .0..V...V.2..V2.
    db 000h, 056h, 032h, 0DDh, 000h, 056h, 070h, 000h, 0F0h, 056h, 070h, 000h, 0BBh, 056h, 032h, 0B0h ; .V2..Vp..Vp..V2.
    db 00Bh, 046h, 072h, 0BBh, 000h, 056h, 071h, 0B0h, 0B0h, 056h, 071h, 002h, 011h, 056h, 071h, 022h ; .Fr..Vq..Vq..Vq"
    db 011h, 056h, 031h, 020h, 011h, 056h, 073h, 00Bh, 0B0h, 056h, 073h, 0BBh, 000h, 056h, 030h, 00Bh ; .V1 .Vs..Vs..V0.
    db 00Bh, 046h, 030h, 000h, 0BBh, 056h, 0FFh ; .F0..V.

; 12E3h..1363h: per-tick motion command stream consumed at 03A2h
camera_motion_script:
    db 0A1h, 0F8h, 0F8h, 098h, 0A1h, 0A6h, 0F0h, 0A7h, 0B3h, 037h, 010h, 036h, 050h, 084h, 085h, 085h ; .........7.6P...
    db 084h, 0F0h, 0F0h, 0B2h, 0A7h, 0A6h, 0A6h, 0A7h, 0F3h, 026h, 070h, 027h, 080h, 044h, 045h, 077h ; .........&p'.DEw
    db 076h, 0A6h, 0B0h, 061h, 061h, 052h, 0A7h, 077h, 030h, 076h, 080h, 0A2h, 001h, 041h, 041h, 001h ; v..aaR.w0v...AA.
    db 0F5h, 030h, 0F4h, 0B3h, 0A4h, 0F8h, 0A5h, 0D0h, 047h, 046h, 0F0h, 0A6h, 080h, 0A7h, 070h, 0A7h ; .0......GF....p.
    db 010h, 0A6h, 08Eh, 0F0h, 050h, 08Fh, 0B2h, 0F8h, 0A3h, 080h, 08Eh, 0F0h, 050h, 08Fh, 0B7h, 010h ; ....P.......P...
    db 0B6h, 0F0h, 080h, 0A6h, 0A7h, 0F0h, 087h, 0F0h, 070h, 086h, 036h, 0F0h, 0F0h, 090h, 037h, 083h ; ........p.6...7.
    db 02Ch, 0F0h, 0F0h, 0F0h, 030h, 02Dh, 082h, 030h, 0B5h, 0B4h, 0F2h, 0A6h, 030h, 0A7h, 083h, 083h ; ,...0-.0....0...
    db 0A6h, 0F0h, 058h, 0A7h, 077h, 076h, 0F0h, 0F0h, 0F0h, 0F0h, 0F8h, 0F8h, 000h, 001h, 000h, 066h ; ..X.wv.........f
    db 0EFh ; .

; 1364h: title text drawn by BIOS int 10h AH=13h before the demo starts.
title_text:
    db 'OMNISCENT'
subtitle_text:
    db '(C) 1997 SANCTION'

; 137Eh: the first zero byte also terminates the display string above.
; These values are manipulated as floats/denormal-float-like dwords by the camera code.
camera_pos:
    dd 0C3A50000h
    dd 000000000h
    dd 042800000h
camera_basis_seed:
    dd 000000000h ; 138Ah
    dd 0BF800000h ; 138Eh
    dd 000000000h ; 1392h
    dd 000000000h ; 1396h
    dd 000000000h ; 139Ah
    dd 0BF800000h ; 139Eh
    dd 03F800000h ; 13A2h
    dd 000000000h ; 13A6h
    dd 000000000h ; 13AAh
