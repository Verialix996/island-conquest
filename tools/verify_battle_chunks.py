#!/usr/bin/env python3
"""Static checks for battle chunk resources and WorldGenerator integration."""
from __future__ import annotations

from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[1]
WORLD_GENERATOR = ROOT / "scenes/battle/world_generator.gd"
CHUNK_SCRIPT = ROOT / "scenes/battle/chunks/battle_chunk.gd"
CHUNK_DIR = ROOT / "scenes/battle/chunks"


def fail(message: str) -> None:
    print(f"FAIL: {message}")
    sys.exit(1)


def main() -> None:
    if not WORLD_GENERATOR.exists():
        fail("WorldGenerator script is missing")

    world_text = WORLD_GENERATOR.read_text(encoding="utf-8")
    required_world_markers = [
        "DEFAULT_BATTLE_CHUNKS",
        "use_chunk_generation",
        "_place_chunk_cover",
        "_seed_chunk_zone_positions",
        "_place_cover_at",
    ]
    for marker in required_world_markers:
        if marker not in world_text:
            fail(f"WorldGenerator missing chunk integration marker: {marker}")

    if "_place_cover()" not in world_text or "_place_chunk_cover()" not in world_text:
        fail("WorldGenerator must keep legacy cover generation and chunk cover generation")

    if not CHUNK_SCRIPT.exists():
        fail("BattleChunk resource script is missing")

    chunk_script_text = CHUNK_SCRIPT.read_text(encoding="utf-8")
    for marker in ["class_name BattleChunk", "get_cover_positions", "get_zone_positions"]:
        if marker not in chunk_script_text:
            fail(f"BattleChunk script missing marker: {marker}")

    chunk_files = sorted(CHUNK_DIR.glob("chunk_*.tscn"))
    if len(chunk_files) < 2:
        fail("Expected at least two reusable battle chunk scenes")

    total_cover_slots = 0
    total_zone_slots = 0
    for chunk_file in chunk_files:
        text = chunk_file.read_text(encoding="utf-8")
        if "res://scenes/battle/chunks/battle_chunk.gd" not in text:
            fail(f"{chunk_file.name} does not use the BattleChunk script")
        cover_slots = len(re.findall(r"parent=\"CoverSlots\"", text))
        zone_slots = len(re.findall(r"parent=\"ZoneSlots\"", text))
        if cover_slots < 1:
            fail(f"{chunk_file.name} must define at least one cover slot")
        if zone_slots < 1:
            fail(f"{chunk_file.name} must define at least one zone slot")
        total_cover_slots += cover_slots
        total_zone_slots += zone_slots

    if total_cover_slots < 6:
        fail("Chunk resources should define at least six cover slots for first battle layout")
    if total_zone_slots < 4:
        fail("Chunk resources should define at least four zone slots for first battle layout")

    print(
        "PASS: battle chunk data and WorldGenerator integration markers present "
        f"({len(chunk_files)} chunks, {total_cover_slots} cover slots, {total_zone_slots} zone slots)"
    )


if __name__ == "__main__":
    main()
