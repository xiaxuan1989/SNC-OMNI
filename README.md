# SNC-OMNI

Reverse-engineering notes and rebuildable assembly for `SNC_OMNI.COM`, a 4095-byte DOS COM intro.

The original binary is packed. The repository keeps both sides of it:

- `SNC_OMNI.COM` - original packed COM.
- `SNC_OMNI.ASM` - readable source for the packed entry, relocation stub, unpacker, and compressed payload include.
- `SNC_OMNI_payload.bin` - compressed payload bytes from the original COM.
- `SNC_OMNI_unpacked.com` - unpacked runtime image produced by the original unpacker logic.
- `SNC_OMNI_UNPACKED.ASM` - analysis-oriented source for the unpacked program.
- `SNC_OMNI_DATA.INC` - recovered data area included by the unpacked source at `data_start`.
- `decode_omni_streams.py` - helper script for decoding data streams, textures, and scene preview assets.

The assembly is written to be rebuildable byte-for-byte. Most instructions are normal NASM source. A few register-to-register forms use small macros to force the same opcode direction bit as the original binary, because NASM may otherwise choose an equivalent but different encoding.

## Build checks

Requires NASM.

```sh
nasm -f bin SNC_OMNI.ASM -o SNC_OMNI_rebuilt.COM
cmp -s SNC_OMNI.COM SNC_OMNI_rebuilt.COM

nasm -f bin SNC_OMNI_UNPACKED.ASM -o SNC_OMNI_unpacked_rebuilt.com
cmp -s SNC_OMNI_unpacked.com SNC_OMNI_unpacked_rebuilt.com
```

Both `cmp` commands should exit with status `0`.

## Analysis entry points

Useful labels in `SNC_OMNI_UNPACKED.ASM`:

- `intro_start`
- `init_video_and_palette`
- `install_interrupts`
- `main_frame_loop`
- `irq0_timer_handler`
- `irq1_keyboard_handler`
- `draw_polygon_scanlines`
- `prepare_and_clip_face`
- `build_scene_geometry`
- `shutdown_and_exit`
- `data_start`

`decode_omni_streams.py` can regenerate the decoded stream notes, OBJ scene preview, HTML previews, and texture PNGs:

```sh
python3 decode_omni_streams.py
```

Generated preview files and textures are ignored by git.
