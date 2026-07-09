#!/usr/bin/env python3
"""Decode compact data streams from the unpacked Omniscent runtime.

The input is the unpacked .COM image produced from SNC_OMNI.COM.  The script
does not use SNC_OMNI.TXT; all offsets and formats come from the disassembled
runtime in SNC_OMNI_UNPACKED.ASM.
"""

from __future__ import annotations

import argparse
import json
import math
from dataclasses import dataclass
from pathlib import Path
from typing import Any

from PIL import Image


COM_BASE = 0x100
TEXTURE_SIZE = 64
TEXTURE_PIXELS = TEXTURE_SIZE * TEXTURE_SIZE


def u8(image: bytes, addr: int) -> int:
    return image[addr - COM_BASE]


def s8(value: int) -> int:
    return value - 0x100 if value & 0x80 else value


def u16(image: bytes, addr: int) -> int:
    off = addr - COM_BASE
    return image[off] | (image[off + 1] << 8)


def u32(value: int) -> int:
    return value & 0xFFFFFFFF


def bytes_at(image: bytes, start: int, end: int) -> bytes:
    return image[start - COM_BASE : end - COM_BASE]


def note_name(note: int) -> str:
    names = ("C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B")
    return f"{names[note % 12]}{note // 12 - 1}"


@dataclass
class RleNode:
    kind: str
    start: int
    end: int
    repeat: int | None = None
    word: tuple[int, int] | None = None
    children: list["RleNode"] | None = None

    def to_dict(self) -> dict[str, Any]:
        data: dict[str, Any] = {"kind": self.kind, "start": self.start, "end": self.end}
        if self.repeat is not None:
            data["repeat"] = self.repeat
        if self.word is not None:
            data["word"] = self.word
        if self.children is not None:
            data["children"] = [child.to_dict() for child in self.children]
        return data


def decode_rle_block(image: bytes, pos: int) -> tuple[bytes, int, list[RleNode]]:
    """Reproduce decode_rle_or_script at 063Bh.

    Positive first bytes are not counts; the routine copies the current word
    with MOVSW.  Negative bytes repeat the nested zero-terminated block abs(n)
    times.  Zero ends the current block and is consumed.
    """
    out = bytearray()
    nodes: list[RleNode] = []
    cur = pos
    while True:
        control = u8(image, cur)
        signed = s8(control)
        if control == 0:
            nodes.append(RleNode("end", cur, cur + 1))
            return bytes(out), cur + 1, nodes
        if signed > 0:
            word = (u8(image, cur), u8(image, cur + 1))
            out.extend(word)
            nodes.append(RleNode("word", cur, cur + 2, word=word))
            cur += 2
            continue

        repeat = -signed
        block_start = cur + 1
        repeated = bytearray()
        block_end = block_start
        children: list[RleNode] = []
        for _ in range(repeat):
            block, block_end, children = decode_rle_block(image, block_start)
            repeated.extend(block)
        out.extend(repeated)
        nodes.append(RleNode("repeat", cur, block_end, repeat=repeat, children=children))
        cur = block_end


def decode_music(image: bytes) -> list[dict[str, Any]]:
    channels = []
    pos = 0x0DE3
    channel_no = 0
    while True:
        channel_byte = u8(image, pos)
        instrument = u8(image, pos + 1)
        midi_channel = (channel_byte - 1) & 0xFF
        if midi_channel & 0x80:
            break
        expanded, end, tree = decode_rle_block(image, pos + 2)
        notes = []
        for i in range(0, len(expanded), 2):
            pitch = expanded[i]
            duration = expanded[i + 1] if i + 1 < len(expanded) else 0
            if pitch == 0:
                break
            notes.append(
                {
                    "pitch": pitch,
                    "note": note_name(pitch),
                    "duration_units": duration,
                    "timer_ticks": duration * 0x1D,
                    "seconds_at_350hz": round(duration * 0x1D / 350.0, 4),
                }
            )
        channels.append(
            {
                "source_offset": f"{pos:04X}",
                "midi_channel": midi_channel,
                "program": instrument,
                "expanded_bytes": len(expanded),
                "note_count": len(notes),
                "notes": notes,
                "rle_tree": [node.to_dict() for node in tree],
            }
        )
        channel_no += 1
        pos = end
    return channels


def decode_palette(image: bytes) -> list[dict[str, Any]]:
    pos = 0x0F28
    count = u8(image, pos)
    pos += 1
    records = []
    for index in range(count):
        steps = u8(image, pos)
        # The runtime reads [si+1], [si+2], [si+3] over three component passes.
        r, g, b = u8(image, pos + 1), u8(image, pos + 2), u8(image, pos + 3)
        records.append({"index": index, "steps": steps, "target_rgb_6bit": [r, g, b]})
        pos += 4
    return records


def build_vga_palette(image: bytes) -> list[tuple[int, int, int]]:
    records = decode_palette(image)
    palette6 = [[0, 0, 0] for _ in range(256)]
    for component in range(3):
        dx = 0
        output_index = 0
        for rec in records:
            steps = rec["steps"]
            target = rec["target_rgb_6bit"][component]
            delta = ((target << 8) - dx)
            if delta >= 0x8000:
                delta -= 0x10000
            if steps:
                step = int(delta / steps)
            else:
                step = 0
            for _ in range(steps):
                dx = (dx + step) & 0xFFFF
                if output_index < 256:
                    palette6[output_index][component] = (dx >> 8) & 0x3F
                output_index += 1
    return [tuple(min(255, component * 255 // 63) for component in color) for color in palette6]


class OmniRng:
    def __init__(self) -> None:
        self.seed = 0x08088405
        self.state = 0x000010FB

    def bounded(self, bound: int) -> int:
        self.state = u32(self.seed * self.state + 1)
        high = (self.state >> 16) & 0xFFFF
        return (high * bound) >> 16


def clear_texture(value: int = 0) -> bytearray:
    return bytearray([value & 0xFF] * TEXTURE_PIXELS)


def generate_circle_noise_texture(rng: OmniRng, radius: int, iterations: int) -> bytearray:
    tex = clear_texture(0)
    r2 = radius * radius
    widths: list[int] = []
    y = radius
    for _ in range(radius * 2):
        widths.append(int(round(math.sqrt(max(0, r2 - y * y)))))
        y -= 1
    for _ in range(iterations):
        di = rng.bounded(TEXTURE_PIXELS)
        for width in widths:
            count = width * 2
            if count:
                pos = (di - width) & 0x0FFF
                for _ in range(count):
                    tex[pos] = (tex[pos] + 1) & 0xFF
                    pos = (pos + 1) & 0x0FFF
            di = (di + TEXTURE_SIZE) & 0xFFFF
    return tex


def generate_sparkle_records(rng: OmniRng) -> list[tuple[int, int]]:
    records = []
    for _ in range(0x1E):
        phase = rng.bounded(0x100)
        position = rng.bounded(0x0F40) + 0x40
        records.append((phase, position))
    return records


def draw_sparkle_sprite(tex: bytearray, sprite: bytes, position: int, threshold: int) -> None:
    for y in range(5):
        row_pos = position + y * TEXTURE_SIZE
        for x in range(5):
            value = sprite[y * 5 + x] - threshold
            if value > 0:
                pos = row_pos + x
                if 0 <= pos < TEXTURE_PIXELS:
                    tex[pos] = (value + 0xE0) & 0xFF


def generate_sparkle_texture(image: bytes, sparkle_records: list[tuple[int, int]]) -> bytearray:
    tex = clear_texture(0)
    sprite = bytes_at(image, 0x1021, 0x103A)
    for phase, position in sparkle_records:
        phase = (phase - 1) & 0xFF
        threshold = phase & 0x3F
        if threshold > 0x1F:
            threshold = (~threshold) & 0x1F
        threshold >>= 1
        draw_sparkle_sprite(tex, sprite, position, threshold)
    return tex


def bake_camera_into_door_texture(textures: list[bytearray]) -> bytearray:
    baked = bytearray(textures[13])
    for pos, value in enumerate(textures[15]):
        if value != 0:
            baked[pos] = value
    return baked


def generate_textures(image: bytes) -> tuple[list[bytearray], list[tuple[int, int, int]]]:
    rng = OmniRng()
    textures = [clear_texture(0) for _ in range(20)]

    # Texture 17: radius 5, 800 random circles. Texture 16: radius 15, 112 circles.
    textures[17] = generate_circle_noise_texture(rng, radius=5, iterations=0x320)
    textures[16] = generate_circle_noise_texture(rng, radius=15, iterations=0x70)

    # Texture 18: averaged vertical noise.
    textures[18] = clear_texture(0x14)
    for di in range(TEXTURE_SIZE, TEXTURE_PIXELS):
        value = rng.bounded(4)
        value += textures[18][di - TEXTURE_SIZE]
        value += textures[18][di - TEXTURE_SIZE + 1]
        value = ((value - 1) & 0xFFFF) >> 1
        textures[18][di] = value & 0xFF

    # Texture 19: random scatter.
    textures[19] = clear_texture(3)
    for _ in range(TEXTURE_PIXELS):
        pos = rng.bounded(TEXTURE_PIXELS)
        textures[19][pos] = (textures[19][pos] + 1) & 0xFF

    # Texture 1: one static frame from the IRQ sparkle updater.
    sparkle_records = generate_sparkle_records(rng)
    textures[1] = generate_sparkle_texture(image, sparkle_records)

    # Texture 0: procedural distance-ish pattern.
    for di in range(TEXTURE_PIXELS):
        al = di & 0xFF
        if al & 0x08:
            al = (~al) & 0xFF
        xval = al & 0x0F
        al = (di >> 6) & 0xFF
        if al & 0x08:
            al = (~al) & 0xFF
        yval = al & 0x0F
        textures[0][di] = (min(xval, yval) + 0xE0) & 0xFF

    # Textures 2..15 are copied from noise sources 16..19 with offsets.
    for rec in decode_texture_sources(image):
        src = rec["source_texture"]
        dst = rec["dest_texture"]
        addend = rec["addend"]
        for i in range(TEXTURE_PIXELS):
            textures[dst][i] = (textures[src][i] + addend) & 0xFF

    # Apply rectangular texture recipes.
    for rec in decode_texture_rects(image):
        tex = textures[rec["texture"]]
        mode = rec["mode"]
        addend = rec["value_signed"]
        for y in range(rec["y0"], rec["y1"] + 1):
            for x in range(rec["x0"], rec["x1"] + 1):
                pos = y * TEXTURE_SIZE + x
                if mode == 1:
                    value = 0
                elif mode == 2:
                    value = tex[pos]
                else:
                    value = 0x98 if ((x + y) & 0x04) else 0
                tex[pos] = (value + addend) & 0xFF

    # Texture 11 red fade random dots.
    di = 0x0FFF
    al = 0x5E
    for row_count in range(0x14, 0, -1):
        for _ in range(row_count << 3):
            pos = (di - rng.bounded(TEXTURE_SIZE)) & 0xFFFF
            if 0 <= pos < TEXTURE_PIXELS:
                textures[11][pos] = al & 0xFF
        al = (al - 1) & 0xFF
        di -= TEXTURE_SIZE

    return textures, build_vga_palette(image)


def export_textures(image: bytes, output_dir: str) -> None:
    textures, palette = generate_textures(image)
    outdir = Path(output_dir)
    outdir.mkdir(parents=True, exist_ok=True)
    flat_palette = [component for rgb in palette for component in rgb]
    flat_palette.extend([0] * (768 - len(flat_palette)))

    for index, tex in enumerate(textures):
        indexed = Image.frombytes("P", (TEXTURE_SIZE, TEXTURE_SIZE), bytes(tex))
        indexed.putpalette(flat_palette)
        if index == 1:
            indexed.info["transparency"] = 0
        indexed.save(outdir / f"tex_{index:02d}.png")

        rgb = indexed.convert("RGBA" if index == 1 else "RGB")
        rgb.save(outdir / f"tex_{index:02d}_rgb.png")

    baked_door = bake_camera_into_door_texture(textures)
    indexed = Image.frombytes("P", (TEXTURE_SIZE, TEXTURE_SIZE), bytes(baked_door))
    indexed.putpalette(flat_palette)
    indexed.save(outdir / "tex_13_camera.png")
    indexed.convert("RGB").save(outdir / "tex_13_camera_rgb.png")

    sheet = Image.new("RGB", (TEXTURE_SIZE * 5, TEXTURE_SIZE * 4), (0, 0, 0))
    for index in range(20):
        img = Image.open(outdir / f"tex_{index:02d}_rgb.png")
        sheet.paste(img, ((index % 5) * TEXTURE_SIZE, (index // 5) * TEXTURE_SIZE))
    sheet.save(outdir / "contact_sheet.png")


def decode_texture_rects(image: bytes) -> list[dict[str, Any]]:
    records = []
    pos = 0x0F69
    end = 0x1005
    mode_names = {
        1: "fill value/addend",
        2: "add to existing texel",
        3: "checker/stripe pattern plus addend",
    }
    index = 0
    while pos < end:
        first = u8(image, pos)
        mode = first >> 4
        texture = first & 0x0F
        x0, y0, x1, y1, value = [u8(image, pos + i) for i in range(1, 6)]
        records.append(
            {
                "index": index,
                "texture": texture,
                "mode": mode,
                "mode_guess": mode_names.get(mode, "checker/other"),
                "x0": x0,
                "y0": y0,
                "x1": x1,
                "y1": y1,
                "value_signed": s8(value),
                "value_hex": f"{value:02X}",
            }
        )
        index += 1
        pos += 6
    return records


def decode_texture_sources(image: bytes) -> list[dict[str, Any]]:
    records = []
    pos = 0x1005
    dest_texture = 2
    while pos < 0x101F:
        word = u16(image, pos)
        source_texture_offset = word & 0xFF
        source_texture = source_texture_offset // 2
        addend = s8(word >> 8)
        records.append(
            {
                "dest_texture": dest_texture,
                "source_texture": source_texture,
                "source_texture_table_offset": source_texture_offset,
                "addend": addend,
                "raw_word": f"{word:04X}",
            }
        )
        dest_texture += 1
        pos += 2
    return records


def decode_sprite(image: bytes) -> list[list[int]]:
    blob = bytes_at(image, 0x1021, 0x103A)
    return [list(blob[row * 5 : row * 5 + 5]) for row in range(5)]


def decode_cube_tables(image: bytes) -> dict[str, Any]:
    face_blob = bytes_at(image, 0x1047, 0x105F)
    faces = []
    for i in range(6):
        raw = list(face_blob[i * 4 : i * 4 + 4])
        faces.append({"face": i, "corner_offsets": raw, "corner_indices_guess": [v // 8 for v in raw]})

    coord_blob = bytes_at(image, 0x105F, 0x108C)
    corners = []
    for i in range(15):
        xyz = [s8(v) for v in coord_blob[i * 3 : i * 3 + 3]]
        corners.append({"index": i, "xyz_signed": xyz})
    return {"faces": faces, "corners": corners}


def decode_camera_script(image: bytes) -> list[dict[str, Any]]:
    command_names = {
        0: "hold/no movement command",
        1: "toggle direction scalar then move axis 0",
        2: "increment axis 0",
        3: "decrement axis 0",
        4: "increment axis 1",
        5: "decrement axis 1",
        6: "increment axis 2",
        7: "decrement axis 2",
    }
    events = []
    pos = 0x12E3
    tick_cursor = 0
    while pos < 0x1364:
        value = u8(image, pos)
        cmd = value & 0x07
        duration_countdown = (value & 0xF8) * 2
        events.append(
            {
                "source_offset": f"{pos:04X}",
                "raw": f"{value:02X}",
                "command": cmd,
                "command_guess": "end" if value == 0 else command_names.get(cmd, "unknown"),
                "duration_countdown": duration_countdown,
                "approx_seconds_at_350hz": round(duration_countdown / 350.0, 4),
                "starts_after_countdown_sum": tick_cursor,
            }
        )
        pos += 1
        if value == 0:
            break
        tick_cursor += duration_countdown
    return events


def split_scene_streams(image: bytes) -> list[dict[str, Any]]:
    """Split the four scene streams at FF terminators.

    A full geometry decoder needs to emulate build_scene_geometry at 0C80h.
    This still makes the stream boundaries and token bytes visible.
    """
    streams = []
    pos = 0x108C
    for stream_index in range(4):
        start = pos
        while u8(image, pos) != 0xFF:
            pos += 1
        end = pos + 1
        blob = bytes_at(image, start, end)
        streams.append(
            {
                "stream": stream_index,
                "start": f"{start:04X}",
                "end": f"{end:04X}",
                "length": len(blob),
                "tokens_hex": " ".join(f"{b:02X}" for b in blob),
            }
        )
        pos = end
    return streams


def rotate_pair(values: list[float], a: int, b: int, angle_word: int) -> None:
    angle_word &= 0xFFFF
    signed_angle = angle_word - 0x10000 if angle_word & 0x8000 else angle_word
    angle = signed_angle * math.pi / 65536.0
    s = math.sin(angle)
    c = math.cos(angle)
    va = values[a]
    vb = values[b]
    values[a] = c * va - s * vb
    values[b] = s * va + c * vb


def rotate_point(values: list[float], angle1: int, angle2: int, angle3: int) -> None:
    # Port of rotate_matrix_euler/rotate_pair_by_angle at 0BD0h/0BADh.
    rotate_pair(values, 1, 2, angle1)
    rotate_pair(values, 2, 0, angle2)
    rotate_pair(values, 0, 1, angle3)


def decode_scene_geometry(image: bytes) -> dict[str, Any]:
    """High-level port of build_scene_geometry at 0C80h.

    This recovers the vertex and face topology produced by the compact cube-walk
    scene streams. Python floats stand in for x87, so a few coordinates may be
    off by one compared with exact runtime rounding after rotations.
    """
    face_offsets = [s8(v) for v in bytes_at(image, 0x1047, 0x105F)]
    coord_blob = bytes_at(image, 0x105F, 0x108C)
    base_points = [[float(s8(coord_blob[i * 3 + j])) for j in range(3)] for i in range(15)]

    vertices: list[tuple[int, int, int]] = []
    vertex_index: dict[tuple[int, int, int], int] = {}
    faces: list[dict[str, Any]] = []
    stream_summaries: list[dict[str, Any]] = []

    pos = 0x108C
    for stream_index in range(4):
        stream_start = pos
        stream_vertex_start = len(vertices)
        stream_face_start = len(faces)

        word_points = [tuple(int(v) for v in point) for point in base_points]
        float_points = [point[:] for point in base_points]

        while True:
            token_addr = pos
            token = u8(image, pos)
            pos += 1
            if token == 0xFF:
                break

            move_index = token & 0x0F
            face_attr_word = (((token & 0x70) + 0x0F) << 8) & 0xFFFF
            face_bytes = [u8(image, pos), u8(image, pos + 1), u8(image, pos + 2)]
            pos += 3

            nibbles: list[int] = []
            for byte in face_bytes:
                nibbles.append(byte >> 4)
                nibbles.append(byte & 0x0F)

            for face_id, nibble in enumerate(nibbles):
                texture = nibble - 1
                if texture < 0:
                    continue
                indices = []
                for corner_no in range(4):
                    table_offset = face_id * 4 + corner_no
                    corner_index = face_offsets[table_offset] // 8
                    point = word_points[corner_index]
                    if point not in vertex_index:
                        vertex_index[point] = len(vertices)
                        vertices.append(point)
                    indices.append(vertex_index[point])
                faces.append(
                    {
                        "stream": stream_index,
                        "token_offset": f"{token_addr:04X}",
                        "face_id": face_id,
                        "texture": texture,
                        "attr_word": f"{face_attr_word:04X}",
                        "vertices": indices,
                    }
                )

            vector_index = 8 + move_index
            if vector_index < len(float_points):
                for axis in range(3):
                    float_points[14][axis] += float_points[vector_index][axis]

            if token & 0x80:
                rot = u8(image, pos)
                high_angle = (rot & 0xF0) << 8
                for point_index in range(14):
                    dl = rot
                    angles = []
                    for _ in range(3):
                        carry = dl & 1
                        dl >>= 1
                        angles.append(high_angle if carry else 0)
                    rotate_point(float_points[point_index], angles[0], angles[1], angles[2])
                pos += 1

            bx = (move_index << 2) & 0xFF
            for corner_step in range(4):
                saved_bx = (bx + corner_step) & 0xFF
                src_index = face_offsets[saved_bx] // 8
                dst_index = face_offsets[saved_bx ^ 0x07] // 8
                word_points[dst_index] = word_points[src_index]
                word_points[src_index] = tuple(
                    int(round(float_points[src_index][axis] + float_points[14][axis]))
                    for axis in range(3)
                )

        stream_summaries.append(
            {
                "stream": stream_index,
                "start": f"{stream_start:04X}",
                "end": f"{pos:04X}",
                "vertices_added": len(vertices) - stream_vertex_start,
                "faces_added": len(faces) - stream_face_start,
            }
        )

    texture_histogram: dict[str, int] = {}
    for face in faces:
        key = str(face["texture"])
        texture_histogram[key] = texture_histogram.get(key, 0) + 1

    return {
        "vertex_count": len(vertices),
        "face_count": len(faces),
        "streams": stream_summaries,
        "texture_histogram": texture_histogram,
        "vertices": [{"index": i, "xyz": list(vertex)} for i, vertex in enumerate(vertices)],
        "faces": faces,
    }


def render_markdown(decoded: dict[str, Any]) -> str:
    lines: list[str] = []
    lines.append("# SNC_OMNI Stream Decode")
    lines.append("")
    lines.append("Generated from `SNC_OMNI_unpacked.com`; no DEBUG/TXT source is used.")
    lines.append("")

    lines.append("## Music Channels")
    for ch in decoded["music_channels"]:
        lines.append(
            f"- offset `{ch['source_offset']}`: MIDI channel {ch['midi_channel']}, "
            f"program `{ch['program']:02X}h`, {ch['note_count']} notes, "
            f"{ch['expanded_bytes']} expanded bytes"
        )
        preview = ch["notes"][:16]
        if preview:
            note_text = ", ".join(f"{n['note']}:{n['duration_units']}" for n in preview)
            lines.append(f"  preview: {note_text}")
    lines.append("")

    lines.append("## Palette Control Points")
    for rec in decoded["palette"]:
        lines.append(f"- {rec['index']:02d}: {rec['steps']} steps -> RGB6 {rec['target_rgb_6bit']}")
    lines.append("")

    lines.append("## Texture Rectangles")
    for rec in decoded["texture_rects"]:
        lines.append(
            f"- {rec['index']:02d}: tex {rec['texture']:02d}, mode {rec['mode']} "
            f"({rec['mode_guess']}), ({rec['x0']},{rec['y0']})..({rec['x1']},{rec['y1']}), "
            f"value {rec['value_signed']} / {rec['value_hex']}h"
        )
    lines.append("")

    lines.append("## Derived Texture Sources")
    for rec in decoded["texture_sources"]:
        lines.append(
            f"- tex {rec['dest_texture']:02d} <- tex {rec['source_texture']:02d} "
            f"with addend {rec['addend']} (`{rec['raw_word']}`, table offset "
            f"{rec['source_texture_table_offset']})"
        )
    lines.append("")

    lines.append("## 5x5 Sparkle Sprite")
    for row in decoded["sprite_5x5"]:
        lines.append("    " + " ".join(f"{v:02X}" for v in row))
    lines.append("")

    lines.append("## Cube Tables")
    for face in decoded["cube_tables"]["faces"]:
        lines.append(
            f"- face {face['face']}: offsets {face['corner_offsets']} "
            f"-> corner index guess {face['corner_indices_guess']}"
        )
    lines.append("")
    lines.append("Corner coordinate triples:")
    for corner in decoded["cube_tables"]["corners"]:
        lines.append(f"- {corner['index']:02d}: {corner['xyz_signed']}")
    lines.append("")

    lines.append("## Scene Streams")
    for stream in decoded["scene_streams"]:
        lines.append(
            f"- stream {stream['stream']}: `{stream['start']}`..`{stream['end']}`, "
            f"{stream['length']} bytes"
        )
        lines.append(f"  `{stream['tokens_hex']}`")
    lines.append("")

    geom = decoded["scene_geometry"]
    lines.append("## Decoded Scene Geometry")
    lines.append(f"- vertices: {geom['vertex_count']}")
    lines.append(f"- faces/quads: {geom['face_count']}")
    for stream in geom["streams"]:
        lines.append(
            f"- stream {stream['stream']}: +{stream['vertices_added']} vertices, "
            f"+{stream['faces_added']} faces (`{stream['start']}`..`{stream['end']}`)"
        )
    hist = ", ".join(
        f"tex {texture}: {count}"
        for texture, count in sorted(geom["texture_histogram"].items(), key=lambda item: int(item[0]))
    )
    lines.append(f"- texture histogram: {hist}")
    lines.append("")
    lines.append("First 12 vertices:")
    for vertex in geom["vertices"][:12]:
        lines.append(f"- {vertex['index']:03d}: {vertex['xyz']}")
    lines.append("")
    lines.append("First 12 faces:")
    for face in geom["faces"][:12]:
        lines.append(
            f"- stream {face['stream']} `{face['token_offset']}` face {face['face_id']} "
            f"tex {face['texture']} verts {face['vertices']}"
        )
    lines.append("")

    lines.append("## Camera Motion Script")
    for event in decoded["camera_script"]:
        lines.append(
            f"- `{event['source_offset']}` raw `{event['raw']}`: cmd {event['command']} "
            f"({event['command_guess']}), countdown {event['duration_countdown']} "
            f"ticks, approx {event['approx_seconds_at_350hz']}s"
        )
    lines.append("")
    return "\n".join(lines)


TEXTURE_COLORS = [
    (80, 80, 90),
    (160, 64, 48),
    (230, 72, 38),
    (224, 182, 67),
    (78, 126, 168),
    (90, 92, 100),
    (120, 137, 86),
    (64, 64, 72),
    (220, 220, 190),
    (70, 112, 80),
    (140, 96, 64),
    (184, 50, 44),
    (52, 80, 112),
    (30, 30, 35),
    (232, 188, 52),
]


def export_obj(decoded: dict[str, Any], obj_path: str, mtl_path: str) -> None:
    geom = decoded["scene_geometry"]
    obj = []
    obj.append("# Omniscent scene geometry decoded from SNC_OMNI.COM")
    obj.append(f"mtllib {Path(mtl_path).name}")
    obj.append("o omniscent_scene")
    for vertex in geom["vertices"]:
        x, y, z = vertex["xyz"]
        obj.append(f"v {x} {y} {z}")
    current_mat = None
    for face in geom["faces"]:
        mat = f"tex_{face['texture']:02d}"
        if mat != current_mat:
            obj.append(f"usemtl {mat}")
            current_mat = mat
        # OBJ indices are 1-based.
        indices = [str(v + 1) for v in face["vertices"]]
        obj.append("f " + " ".join(indices))

    mtl = ["# Materials keyed by decoded texture index"]
    for texture, color in enumerate(TEXTURE_COLORS):
        r, g, b = [component / 255.0 for component in color]
        mtl.extend(
            [
                f"newmtl tex_{texture:02d}",
                f"Kd {r:.4f} {g:.4f} {b:.4f}",
                "Ka 0.0500 0.0500 0.0500",
                "Ks 0.0000 0.0000 0.0000",
                "",
            ]
        )

    Path(obj_path).write_text("\n".join(obj) + "\n", encoding="utf-8")
    Path(mtl_path).write_text("\n".join(mtl), encoding="utf-8")


def export_html_preview(decoded: dict[str, Any], html_path: str) -> None:
    geom = decoded["scene_geometry"]
    payload = {
        "vertices": [vertex["xyz"] for vertex in geom["vertices"]],
        "faces": [
            {"texture": face["texture"], "vertices": face["vertices"], "stream": face["stream"]}
            for face in geom["faces"]
        ],
        "colors": TEXTURE_COLORS,
    }
    html = f"""<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Omniscent Scene Preview</title>
  <style>
    html, body {{
      margin: 0;
      width: 100%;
      height: 100%;
      overflow: hidden;
      background: #101114;
      color: #e8e6df;
      font: 13px system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
    }}
    canvas {{
      display: block;
      width: 100vw;
      height: 100vh;
    }}
    .hud {{
      position: fixed;
      left: 16px;
      top: 14px;
      display: grid;
      gap: 4px;
      pointer-events: none;
      text-shadow: 0 1px 2px #000;
    }}
  </style>
</head>
<body>
  <canvas id="view"></canvas>
  <div class="hud">
    <div>OMNISCENT decoded scene</div>
    <div>362 vertices / 367 quads</div>
    <div>drag: rotate · wheel: zoom</div>
  </div>
  <script>
  const scene = {json.dumps(payload)};
  const canvas = document.getElementById('view');
  const ctx = canvas.getContext('2d');
    let yaw = -0.72;
    let pitch = 0.44;
  let zoom = 1.2;
  let dragging = false;
  let lastX = 0;
  let lastY = 0;

  function resize() {{
    const dpr = window.devicePixelRatio || 1;
    canvas.width = Math.floor(window.innerWidth * dpr);
    canvas.height = Math.floor(window.innerHeight * dpr);
    ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
    draw();
  }}

  function transform(v) {{
    const cy = Math.cos(yaw), sy = Math.sin(yaw);
    const cp = Math.cos(pitch), sp = Math.sin(pitch);
    // Rotate the decoded model 90 degrees for preview: Z is vertical.
    let x = -v[0], y = -v[2], z = v[1];
    let x1 = x * cy - z * sy;
    let z1 = x * sy + z * cy;
    let y1 = y * cp - z1 * sp;
    let z2 = y * sp + z1 * cp + 860 / zoom;
    const scale = 520 / z2;
    return {{
      x: window.innerWidth * 0.5 + x1 * scale,
      y: window.innerHeight * 0.52 + y1 * scale,
      z: z2
    }};
  }}

  function draw() {{
    ctx.clearRect(0, 0, window.innerWidth, window.innerHeight);
    const projected = scene.vertices.map(transform);
    const faces = scene.faces.map((face) => {{
      const pts = face.vertices.map((i) => projected[i]);
      const depth = pts.reduce((sum, p) => sum + p.z, 0) / pts.length;
      return {{...face, pts, depth}};
    }}).sort((a, b) => b.depth - a.depth);

    for (const face of faces) {{
      const color = scene.colors[face.texture] || [180, 180, 180];
      ctx.beginPath();
      ctx.moveTo(face.pts[0].x, face.pts[0].y);
      for (let i = 1; i < face.pts.length; i++) ctx.lineTo(face.pts[i].x, face.pts[i].y);
      ctx.closePath();
      ctx.fillStyle = `rgb(${{color[0]}}, ${{color[1]}}, ${{color[2]}})`;
      ctx.globalAlpha = 0.86;
      ctx.fill();
      ctx.globalAlpha = 1;
      ctx.strokeStyle = 'rgba(245, 241, 225, 0.18)';
      ctx.lineWidth = 1;
      ctx.stroke();
    }}
  }}

  canvas.addEventListener('pointerdown', (event) => {{
    dragging = true;
    lastX = event.clientX;
    lastY = event.clientY;
    canvas.setPointerCapture(event.pointerId);
  }});
  canvas.addEventListener('pointermove', (event) => {{
    if (!dragging) return;
    yaw += (event.clientX - lastX) * 0.008;
    pitch += (event.clientY - lastY) * 0.008;
    pitch = Math.max(-1.4, Math.min(1.4, pitch));
    lastX = event.clientX;
    lastY = event.clientY;
    draw();
  }});
  canvas.addEventListener('pointerup', () => dragging = false);
  canvas.addEventListener('wheel', (event) => {{
    event.preventDefault();
    zoom *= event.deltaY > 0 ? 0.92 : 1.08;
    zoom = Math.max(0.35, Math.min(3.8, zoom));
    draw();
  }}, {{passive: false}});
  window.addEventListener('resize', resize);
  resize();
  </script>
</body>
</html>
"""
    Path(html_path).write_text(html, encoding="utf-8")


def textured_preview_faces(geom: dict[str, Any]) -> list[dict[str, Any]]:
    faces = []
    seen_tex13_quads: set[tuple[int, ...]] = set()
    for face in geom["faces"]:
        preview_face = {
            "texture": face["texture"],
            "vertices": face["vertices"],
            "stream": face["stream"],
            "faceId": face["face_id"],
        }
        if face["texture"] == 13:
            key = tuple(sorted(face["vertices"]))
            if key in seen_tex13_quads:
                continue
            seen_tex13_quads.add(key)
            preview_face["texture"] = 20
        faces.append(preview_face)
    return faces


def textured_preview_texture_files() -> list[str]:
    return [
        f"textures/tex_{texture_index:02d}_rgb.png"
        for texture_index in range(20)
    ] + ["textures/tex_13_camera_rgb.png"]


def export_textured_html_preview(decoded: dict[str, Any], html_path: str) -> None:
    geom = decoded["scene_geometry"]
    faces = textured_preview_faces(geom)
    payload = {
        "vertices": [vertex["xyz"] for vertex in geom["vertices"]],
        "faces": faces,
        "textureFiles": textured_preview_texture_files(),
    }
    html = f"""<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Omniscent Textured Scene Preview</title>
  <style>
    html, body {{
      margin: 0;
      width: 100%;
      height: 100%;
      overflow: hidden;
      background: #101114;
      color: #e8e6df;
      font: 13px system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
    }}
    #view {{
      width: 100vw;
      height: 100vh;
      display: block;
    }}
    .hud {{
      position: fixed;
      left: 16px;
      top: 14px;
      display: grid;
      gap: 4px;
      pointer-events: none;
      text-shadow: 0 1px 2px #000;
    }}
    .hud a {{
      color: #e8e6df;
      pointer-events: auto;
    }}
    .view-controls {{
      display: flex;
      gap: 6px;
      margin-top: 4px;
      pointer-events: auto;
    }}
    .view-controls button {{
      border: 1px solid rgba(232, 230, 223, 0.38);
      background: rgba(16, 17, 20, 0.78);
      color: #e8e6df;
      padding: 4px 8px;
      font: inherit;
      cursor: pointer;
    }}
    .view-controls button.active {{
      background: #e8e6df;
      color: #101114;
    }}
  </style>
</head>
<body>
  <div id="view"></div>
  <div class="hud">
    <div>OMNISCENT textured scene</div>
    <div>simple planar UV per quad · textures/tex_XX_rgb.png</div>
    <div>drag: rotate · wheel: zoom · right drag: pan</div>
    <div class="view-controls">
      <button id="externalView" type="button">External</button>
      <button id="internalView" type="button">Internal</button>
    </div>
    <a href="omni_scene_preview.html">solid-color preview</a>
  </div>
  <script type="importmap">
    {{
      "imports": {{
        "three": "https://unpkg.com/three@0.166.1/build/three.module.js"
      }}
    }}
  </script>
  <script type="module">
    import * as THREE from 'three';
    import {{ OrbitControls }} from 'https://unpkg.com/three@0.166.1/examples/jsm/controls/OrbitControls.js';

    const decoded = {json.dumps(payload)};
    const container = document.getElementById('view');
    const renderer = new THREE.WebGLRenderer({{ antialias: true }});
    renderer.setPixelRatio(Math.min(window.devicePixelRatio || 1, 2));
    renderer.setSize(window.innerWidth, window.innerHeight);
    renderer.setClearColor(0x101114, 1);
    container.appendChild(renderer.domElement);

    const scene = new THREE.Scene();
    const camera = new THREE.PerspectiveCamera(50, window.innerWidth / window.innerHeight, 1, 5000);
    camera.position.set(520, 420, 760);

    const controls = new OrbitControls(camera, renderer.domElement);
    controls.target.set(-30, -50, 30);
    controls.enableDamping = true;
    controls.dampingFactor = 0.08;

    const loader = new THREE.TextureLoader();
    const viewButtons = {{
      external: document.getElementById('externalView'),
      internal: document.getElementById('internalView')
    }};
    const materials = decoded.textureFiles.map((textureFile, textureIndex) => {{
      const tex = loader.load(textureFile);
      tex.colorSpace = THREE.SRGBColorSpace;
      tex.magFilter = THREE.NearestFilter;
      tex.minFilter = THREE.NearestFilter;
      tex.wrapS = THREE.RepeatWrapping;
      tex.wrapT = THREE.RepeatWrapping;
      return new THREE.MeshBasicMaterial({{
        map: tex,
        side: THREE.DoubleSide,
        transparent: textureIndex === 1,
        alphaTest: textureIndex === 1 ? 0.01 : 0
      }});
    }});

    function convertVertex(v) {{
      // Rotate decoded axes for a more natural preview orientation.
      return [v[0], v[2], v[1]];
    }}

    function quadUvsForFace() {{
      // ASM seeds vertices with texture-memory coords:
      // (0,63), (0,0), (63,0), (63,63). TextureLoader flips PNG rows by
      // default, so Three.js UV v is 1 - textureY / 63.
      return [[0, 0], [0, 1], [1, 1], [1, 0]];
    }}

    for (let textureIndex = 0; textureIndex < materials.length; textureIndex++) {{
      const positions = [];
      const uvs = [];
      const indices = [];
      let vertexCursor = 0;
      for (const face of decoded.faces) {{
        if (face.texture !== textureIndex) continue;
        const quad = face.vertices.map((i) => convertVertex(decoded.vertices[i]));
        const quadUvs = quadUvsForFace();
        for (let i = 0; i < 4; i++) {{
          positions.push(...quad[i]);
          uvs.push(...quadUvs[i]);
        }}
        indices.push(vertexCursor, vertexCursor + 1, vertexCursor + 2);
        indices.push(vertexCursor, vertexCursor + 2, vertexCursor + 3);
        vertexCursor += 4;
      }}
      if (!positions.length) continue;
      const geometry = new THREE.BufferGeometry();
      geometry.setAttribute('position', new THREE.Float32BufferAttribute(positions, 3));
      geometry.setAttribute('uv', new THREE.Float32BufferAttribute(uvs, 2));
      geometry.setIndex(indices);
      geometry.computeBoundingSphere();
      const mesh = new THREE.Mesh(geometry, materials[textureIndex]);
      mesh.name = `texture_${{textureIndex}}`;
      scene.add(mesh);
    }}

    const wireGeometry = new THREE.BufferGeometry();
    const wirePositions = [];
    for (const face of decoded.faces) {{
      const quad = face.vertices.map((i) => convertVertex(decoded.vertices[i]));
      for (let i = 0; i < 4; i++) {{
        const a = quad[i];
        const b = quad[(i + 1) % 4];
        wirePositions.push(...a, ...b);
      }}
    }}
    wireGeometry.setAttribute('position', new THREE.Float32BufferAttribute(wirePositions, 3));
    const wire = new THREE.LineSegments(
      wireGeometry,
      new THREE.LineBasicMaterial({{ color: 0xf2ead8, transparent: true, opacity: 0.16 }})
    );
    scene.add(wire);

    function setViewMode(mode) {{
      const internal = mode === 'internal';
      for (const material of materials) {{
        material.side = internal ? THREE.BackSide : THREE.DoubleSide;
        material.needsUpdate = true;
      }}
      wire.material.opacity = internal ? 0.08 : 0.16;
      viewButtons.external.classList.toggle('active', !internal);
      viewButtons.internal.classList.toggle('active', internal);
      history.replaceState(null, '', internal ? '#internal' : '#external');
    }}

    viewButtons.external.addEventListener('click', () => setViewMode('external'));
    viewButtons.internal.addEventListener('click', () => setViewMode('internal'));
    window.addEventListener('keydown', (event) => {{
      if (event.key.toLowerCase() === 'i') setViewMode('internal');
      if (event.key.toLowerCase() === 'e') setViewMode('external');
    }});
    setViewMode(location.hash === '#internal' ? 'internal' : 'external');

    function resize() {{
      camera.aspect = window.innerWidth / window.innerHeight;
      camera.updateProjectionMatrix();
      renderer.setSize(window.innerWidth, window.innerHeight);
    }}
    window.addEventListener('resize', resize);

    function animate() {{
      controls.update();
      renderer.render(scene, camera);
      requestAnimationFrame(animate);
    }}
    animate();
  </script>
</body>
</html>
"""
    Path(html_path).write_text(html, encoding="utf-8")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", default="SNC_OMNI_unpacked.com")
    parser.add_argument("--json", default="omni_decoded_streams.json")
    parser.add_argument("--markdown", default="omni_decoded_streams.md")
    parser.add_argument("--obj", default="omni_scene.obj")
    parser.add_argument("--mtl", default="omni_scene.mtl")
    parser.add_argument("--html", default="omni_scene_preview.html")
    parser.add_argument("--textured-html", default="omni_scene_textured_preview.html")
    parser.add_argument("--textures", default="textures")
    args = parser.parse_args()

    image = Path(args.input).read_bytes()
    decoded = {
        "music_channels": decode_music(image),
        "palette": decode_palette(image),
        "texture_rects": decode_texture_rects(image),
        "texture_sources": decode_texture_sources(image),
        "sprite_5x5": decode_sprite(image),
        "cube_tables": decode_cube_tables(image),
        "scene_streams": split_scene_streams(image),
        "scene_geometry": decode_scene_geometry(image),
        "camera_script": decode_camera_script(image),
    }

    Path(args.json).write_text(json.dumps(decoded, indent=2), encoding="utf-8")
    Path(args.markdown).write_text(render_markdown(decoded), encoding="utf-8")
    export_obj(decoded, args.obj, args.mtl)
    export_textures(image, args.textures)
    export_html_preview(decoded, args.html)
    export_textured_html_preview(decoded, args.textured_html)
    print(f"wrote {args.json}")
    print(f"wrote {args.markdown}")
    print(f"wrote {args.obj}")
    print(f"wrote {args.mtl}")
    print(f"wrote {args.html}")
    print(f"wrote {args.textured_html}")
    print(f"wrote {args.textures}/tex_00.png .. tex_19.png and tex_13_camera.png")


if __name__ == "__main__":
    main()
