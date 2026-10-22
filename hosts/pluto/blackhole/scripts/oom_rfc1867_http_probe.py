#!/usr/bin/env python3
"""HTTP multipart probe modeled on tests/basic/oom_rfc1867_upload_progress.phpt."""

from __future__ import annotations

import argparse
import http.client
import io
import sys
import time
import uuid

BOUNDARY = "---------------------------12345"


def part(name: str, body: bytes, filename: str | None = None, content_type: str = "text/plain") -> bytes:
    buf = io.BytesIO()
    if filename is None:
        disp = f'form-data; name="{name}"'
    else:
        disp = f'form-data; name="{name}"; filename="{filename}"'
    buf.write(f"--{BOUNDARY}\r\n".encode())
    buf.write(f"Content-Disposition: {disp}\r\n".encode())
    if filename is not None:
        buf.write(f"Content-Type: {content_type}\r\n".encode())
    buf.write(b"\r\n")
    buf.write(body)
    buf.write(b"\r\n")
    return buf.getvalue()


def build_progress_many_parts(num_parts: int, file_body: bytes = b"xxxxxxxx") -> bytes:
    body = io.BytesIO()
    body.write(
        part("PHPSESSID", b"abcdef0123456789abcdef0123456789")
        + part("PHP_SESSION_UPLOAD_PROGRESS", b"k")
    )
    for i in range(num_parts):
        body.write(
            part(f"u{i}", file_body, filename=f"f{i}.txt")
        )
    body.write(f"--{BOUNDARY}--\r\n".encode())
    return body.getvalue()


def build_progress_huge_key(key_bytes: int) -> bytes:
    body = io.BytesIO()
    body.write(part("PHPSESSID", b"abcdef0123456789abcdef0123456789"))
    body.write(f"--{BOUNDARY}\r\n".encode())
    body.write(b'Content-Disposition: form-data; name="PHP_SESSION_UPLOAD_PROGRESS"\r\n\r\n')
    body.write(b"A" * key_bytes)
    body.write(b"\r\n")
    body.write(part("u", b"x", filename="f.txt"))
    body.write(f"--{BOUNDARY}--\r\n".encode())
    return body.getvalue()


def post(host: str, port: int, path: str, payload: bytes, timeout: float) -> tuple[int, str, float]:
    conn = http.client.HTTPConnection(host, port, timeout=timeout)
    headers = {
        "Content-Type": f"multipart/form-data; boundary={BOUNDARY}",
        "Content-Length": str(len(payload)),
        "Cookie": "PHPSESSID=abcdef0123456789abcdef0123456789",
    }
    start = time.monotonic()
    try:
        conn.request("POST", path, body=payload, headers=headers)
        resp = conn.getresponse()
        data = resp.read(65536).decode("utf-8", errors="replace")
        elapsed = time.monotonic() - start
        return resp.status, data, elapsed
    except Exception as exc:  # noqa: BLE001
        elapsed = time.monotonic() - start
        return -1, f"{type(exc).__name__}: {exc}", elapsed
    finally:
        conn.close()


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--host", default="127.0.0.1")
    parser.add_argument("--port", type=int, default=8080)
    parser.add_argument("--path", default="/index.php")
    parser.add_argument(
        "--scenario",
        choices=("progress-many-parts", "progress-huge-key"),
        default="progress-many-parts",
    )
    parser.add_argument("--parts", type=int, default=4000)
    parser.add_argument("--key-bytes", type=int, default=1_048_576)
    parser.add_argument("--timeout", type=float, default=120.0)
    parser.add_argument("--label", default="")
    args = parser.parse_args()

    if args.scenario == "progress-many-parts":
        payload = build_progress_many_parts(args.parts)
    else:
        payload = build_progress_huge_key(args.key_bytes)

    run_id = args.label or str(uuid.uuid4())[:8]
    print(f"[{run_id}] scenario={args.scenario} payload_bytes={len(payload)}")
    status, body, elapsed = post(args.host, args.port, args.path, payload, args.timeout)
    print(f"[{run_id}] status={status} elapsed={elapsed:.3f}s")
    snippet = body[:2000].replace("\n", "\\n")
    print(f"[{run_id}] body_snippet={snippet!r}")
    if "Fatal error" in body or "Allowed memory size" in body:
        print(f"[{run_id}] signal=oom_fatal_in_response")
    if status == -1:
        print(f"[{run_id}] signal=connection_error")
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
