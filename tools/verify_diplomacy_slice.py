#!/usr/bin/env python3
"""Lightweight static checks for the Milestone 9 diplomacy vertical slice.

Godot is not always available on the dev host, so this script verifies the
cross-file wiring that must exist for AI proposals -> player inbox -> response.
"""
from __future__ import annotations

from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

REQUIRED_SNIPPETS = {
    "scripts/autoloads/diplomacy_manager.gd": [
        "enum ProposalType { CEASEFIRE, ALLIANCE, TRADE_PACT, VASSALAGE }",
        "func send_proposal(",
        "func respond_to_proposal(",
        "func get_pending_messages_for(",
        "func _apply_proposal(",
        "EventBus.diplomatic_message_sent.emit(message)",
        "EventBus.diplomatic_proposal_resolved.emit(message, accepted)",
    ],
    "scripts/autoloads/ai_director.gd": [
        "DiplomacyManager.ProposalType.CEASEFIRE",
        "DiplomacyManager.ProposalType.TRADE_PACT",
        "DiplomacyManager.ProposalType.ALLIANCE",
    ],
    "scripts/autoloads/event_bus.gd": [
        "signal diplomatic_message_sent(message: Dictionary)",
        "signal diplomatic_proposal_resolved(message: Dictionary, accepted: bool)",
    ],
    "scenes/map/diplomacy_panel.gd": [
        "var _message_list: VBoxContainer",
        "func _refresh_messages()",
        "func _build_message_row(message: Dictionary)",
        "DiplomacyManager.respond_to_proposal(message_id, true)",
        "DiplomacyManager.respond_to_proposal(message_id, false)",
    ],
    "scenes/map/map_hud.gd": [
        "func _on_diplomatic_message_sent(message: Dictionary)",
        "func _on_diplomatic_proposal_resolved(message: Dictionary, accepted: bool)",
    ],
    "GAME_SYSTEMS.md": [
        "Incoming AI proposals appear in the panel's **Messages** section",
    ],
    "README.md": [
        "player diplomacy panel with AI proposal messages",
    ],
}


def check_balanced(path: Path) -> list[str]:
    text = path.read_text()
    pairs = {"(": ")", "[": "]", "{": "}"}
    stack: list[tuple[str, int]] = []
    in_string = False
    escape = False
    for line_no, line in enumerate(text.splitlines(), start=1):
        for ch in line:
            if in_string:
                if escape:
                    escape = False
                elif ch == "\\":
                    escape = True
                elif ch == '"':
                    in_string = False
                continue
            if ch == '"':
                in_string = True
            elif ch in pairs:
                stack.append((ch, line_no))
            elif ch in pairs.values():
                if not stack or pairs[stack[-1][0]] != ch:
                    return [f"{path}: unmatched {ch!r} on line {line_no}"]
                stack.pop()
    if stack:
        opener, line_no = stack[-1]
        return [f"{path}: unmatched {opener!r} from line {line_no}"]
    return []


def main() -> int:
    failures: list[str] = []
    for rel_path, snippets in REQUIRED_SNIPPETS.items():
        path = ROOT / rel_path
        if not path.exists():
            failures.append(f"missing file: {rel_path}")
            continue
        text = path.read_text()
        for snippet in snippets:
            if snippet not in text:
                failures.append(f"{rel_path}: missing snippet {snippet!r}")
        if path.suffix == ".gd":
            failures.extend(check_balanced(path))

    if failures:
        print("Diplomacy slice verification FAILED:")
        for item in failures:
            print("-", item)
        return 1
    print("Diplomacy slice verification passed: proposal state, AI routing, player inbox, event log, and docs are wired.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
