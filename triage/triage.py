#!/usr/bin/env python3
from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import subprocess
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path
from typing import Any


STACK_LINE_RE = re.compile(r"^\s*#\d+\s+.*$")
ADDR_RE = re.compile(r"0x[0-9a-fA-F]+")
BUILDID_RE = re.compile(r"\(BuildId: [^)]+\)")
WS_RE = re.compile(r"\s+")


@dataclass
class CrashResult:
    crash_file: str
    crash_path: str
    exit_code: int
    signature: str
    signature_hash: str
    stacktrace: list[str]
    log_path: str


def run_cmd(cmd: list[str], timeout_sec: int = 30) -> tuple[int, str]:
    proc = subprocess.run(
        cmd,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        text=True,
        timeout=timeout_sec,
        check=False,
    )
    return proc.returncode, proc.stdout


def normalize_stack_line(line: str) -> str:
    # Remove addresses and build IDs, normalize whitespace.
    line = ADDR_RE.sub("0xADDR", line)
    line = BUILDID_RE.sub("", line)
    line = WS_RE.sub(" ", line).strip()
    return line


def extract_stacktrace(output: str) -> list[str]:
    lines = output.splitlines()
    stack: list[str] = []

    in_stack = False
    for ln in lines:
        # libFuzzer crash often prints "ERROR: libFuzzer: deadly signal" then stack frames "#0 ..."
        if "ERROR: libFuzzer:" in ln or "AddressSanitizer" in ln or "UndefinedBehaviorSanitizer" in ln:
            in_stack = True

        if in_stack and STACK_LINE_RE.match(ln):
            stack.append(normalize_stack_line(ln))

        # Stop if we reached "SUMMARY:" line (common end)
        if in_stack and ln.startswith("SUMMARY:"):
            break

    # Fallback: keep first ~30 stack-like lines if nothing matched
    if not stack:
        for ln in lines:
            if STACK_LINE_RE.match(ln):
                stack.append(normalize_stack_line(ln))
            if len(stack) >= 30:
                break

    return stack


def signature_from_stack(stack: list[str]) -> str:
    # Keep top N frames for signature stability
    top = stack[:12] if stack else ["NO_STACKTRACE"]
    sig = "\n".join(top)
    return sig


def sha256_hex(s: str) -> str:
    return hashlib.sha256(s.encode("utf-8")).hexdigest()


def ensure_dir(p: Path) -> None:
    p.mkdir(parents=True, exist_ok=True)


def load_meta(run_dir: Path) -> dict[str, Any]:
    meta_file = run_dir / "meta.json"
    if meta_file.exists():
        return json.loads(meta_file.read_text(encoding="utf-8"))
    return {}


def triage_run(target: str, run_dir: Path, fuzzer_path: Path, timeout_sec: int) -> dict[str, Any]:
    crashes_dir = run_dir / "crashes"
    if not crashes_dir.exists():
        raise SystemExit(f"Crashes directory not found: {crashes_dir}")

    crash_files = sorted([p for p in crashes_dir.iterdir() if p.is_file()])
    meta = load_meta(run_dir)

    report_dir = Path("/workspace/artifacts/reports") / target / run_dir.name
    ensure_dir(report_dir)

    results: list[CrashResult] = []
    signatures: dict[str, list[str]] = {}

    for crash in crash_files:
        log_path = report_dir / f"{crash.name}.repro.log"

        cmd = [str(fuzzer_path), str(crash)]
        exit_code, out = run_cmd(cmd, timeout_sec=timeout_sec)

        log_path.write_text(out, encoding="utf-8")

        stack = extract_stacktrace(out)
        sig = signature_from_stack(stack)
        sig_hash = sha256_hex(sig)

        results.append(
            CrashResult(
                crash_file=crash.name,
                crash_path=str(crash),
                exit_code=exit_code,
                signature=sig,
                signature_hash=sig_hash,
                stacktrace=stack,
                log_path=str(log_path),
            )
        )

        signatures.setdefault(sig_hash, []).append(crash.name)

    # Build summary
    unique = len(signatures)
    total = len(results)

    report_json = {
        "target": target,
        "run_dir": str(run_dir),
        "run_id": run_dir.name,
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "meta": meta,
        "counts": {"total_crashes": total, "unique_signatures": unique},
        "signatures": [
            {
                "signature_hash": h,
                "crashes": names,
            }
            for h, names in sorted(signatures.items(), key=lambda x: (-len(x[1]), x[0]))
        ],
        "crashes": [
            {
                "crash_file": r.crash_file,
                "crash_path": r.crash_path,
                "exit_code": r.exit_code,
                "signature_hash": r.signature_hash,
                "stacktrace": r.stacktrace,
                "log_path": r.log_path,
            }
            for r in results
        ],
    }

    (report_dir / "report.json").write_text(json.dumps(report_json, indent=2), encoding="utf-8")

    # Markdown report
    lines: list[str] = []
    lines.append(f"# Fuzz Triage Report — {target}")
    lines.append("")
    lines.append(f"- **Run ID:** `{run_dir.name}`")
    lines.append(f"- **Run dir:** `{run_dir}`")
    lines.append(f"- **Generated:** `{report_json['generated_at']}`")
    lines.append(f"- **Total crashes:** **{total}**")
    lines.append(f"- **Unique signatures:** **{unique}**")
    lines.append("")
    if meta:
        lines.append("## Meta")
        lines.append("```json")
        lines.append(json.dumps(meta, indent=2))
        lines.append("```")
        lines.append("")

    lines.append("## Signatures (dedup)")
    for entry in report_json["signatures"]:
        h = entry["signature_hash"]
        names = entry["crashes"]
        lines.append(f"### `{h[:12]}` — {len(names)} crash(es)")
        lines.append("")
        for n in names:
            lines.append(f"- `{n}`")
        lines.append("")

    lines.append("## Crash details")
    for r in results:
        lines.append(f"### `{r.crash_file}`")
        lines.append("")
        lines.append(f"- **Signature:** `{r.signature_hash}`")
        lines.append(f"- **Repro log:** `{Path(r.log_path).as_posix()}`")
        lines.append("")
        if r.stacktrace:
            lines.append("```")
            lines.extend(r.stacktrace[:30])
            lines.append("```")
        else:
            lines.append("_No stacktrace extracted._")
        lines.append("")

    (report_dir / "report.md").write_text("\n".join(lines), encoding="utf-8")

    return {
        "report_dir": str(report_dir),
        "report_md": str(report_dir / "report.md"),
        "report_json": str(report_dir / "report.json"),
        "total_crashes": total,
        "unique_signatures": unique,
    }


def main() -> None:
    ap = argparse.ArgumentParser(description="Triage crashes for a fuzz run and generate report.")
    ap.add_argument("--target", default="cjson", help="Target name (default: cjson)")
    ap.add_argument("--run", required=True, help="Run directory (repo-relative or absolute)")
    ap.add_argument("--timeout", type=int, default=20, help="Timeout seconds per crash repro")
    args = ap.parse_args()

    target = args.target

    # Inside container we use /workspace as repo root mount
    run_arg = args.run
    run_dir = Path(run_arg)
    if not run_dir.is_absolute():
        run_dir = Path("/workspace") / run_arg

    if target == "cjson":
        fuzzer_path = Path("/workspace/targets/cjson/out/cjson_fuzzer")
    else:
        raise SystemExit(f"Unknown target: {target}")

    if not fuzzer_path.exists():
        raise SystemExit(f"Fuzzer binary not found: {fuzzer_path} (did you build?)")

    summary = triage_run(target, run_dir, fuzzer_path, timeout_sec=args.timeout)
    print("[+] Triage complete")
    print(json.dumps(summary, indent=2))


if __name__ == "__main__":
    main()