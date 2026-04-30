#!/usr/bin/env python3
"""
web/server.py — terminal-gym web interface server.

Serves the 3-panel web UI and provides a real bash PTY per WebSocket session.

Usage:
    python3 web/server.py [--port 8080] [--host 127.0.0.1]

    Or via Makefile:
    make web
"""

import argparse
import asyncio
import fcntl
import json
import os
import pty
import signal
import struct
import sys
import tempfile
import termios
from pathlib import Path

from aiohttp import web

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT))

from core.export import export_content  # noqa: E402
from core.grading import load_grades, save_grades, matches  # noqa: E402
from core.missions import load_missions  # noqa: E402

STATIC_DIR = Path(__file__).resolve().parent / "static"


# ─── PTY session management ──────────────────────────────────────────────────


class PtySession:
    """Manages a single bash PTY session tied to a WebSocket."""

    def __init__(self, rows=24, cols=80):
        self.master_fd = None
        self.pid = None
        self.rows = rows
        self.cols = cols

    def start(self):
        master_fd, slave_fd = pty.openpty()
        fcntl.ioctl(
            slave_fd,
            termios.TIOCSWINSZ,
            struct.pack("HHHH", self.rows, self.cols, 0, 0),
        )

        pid = os.fork()
        if pid == 0:
            # ── Child ──
            os.close(master_fd)
            os.setsid()
            os.dup2(slave_fd, 0)
            os.dup2(slave_fd, 1)
            os.dup2(slave_fd, 2)
            if slave_fd > 2:
                os.close(slave_fd)
            env = os.environ.copy()
            env["TERM"] = "xterm-256color"
            env["PS1"] = r"\[\e[32m\]\u@terminal-gym\[\e[0m\]:\[\e[34m\]\w\[\e[0m\]\$ "
            env["HISTFILE"] = os.path.join(
                tempfile.gettempdir(), f"tgym_hist_{os.getpid()}.log"
            )
            env["HISTSIZE"] = "10000"
            env["HISTFILESIZE"] = "10000"
            env["PROMPT_COMMAND"] = "history -a"
            try:
                fcntl.ioctl(slave_fd, termios.TIOCSCTTY, 0)
            except OSError:
                pass
            os.execve("/bin/bash", ["/bin/bash", "--norc", "-i"], env)

        # ── Parent ──
        os.close(slave_fd)
        self.master_fd = master_fd
        self.pid = pid

    def resize(self, rows, cols):
        self.rows = rows
        self.cols = cols
        if self.master_fd is not None:
            try:
                fcntl.ioctl(
                    self.master_fd,
                    termios.TIOCSWINSZ,
                    struct.pack("HHHH", rows, cols, 0, 0),
                )
            except OSError:
                pass

    def write(self, data):
        if self.master_fd is not None:
            try:
                os.write(self.master_fd, data)
            except OSError:
                pass

    def cleanup(self):
        if self.master_fd is not None:
            try:
                os.close(self.master_fd)
            except OSError:
                pass
            self.master_fd = None
        if self.pid is not None:
            try:
                os.kill(self.pid, signal.SIGTERM)
                os.waitpid(self.pid, 0)
            except (OSError, ChildProcessError):
                try:
                    os.kill(self.pid, signal.SIGKILL)
                    os.waitpid(self.pid, 0)
                except (OSError, ChildProcessError):
                    pass
            self.pid = None


# ─── WebSocket handler ────────────────────────────────────────────────────────


async def ws_terminal(request):
    ws = web.WebSocketResponse()
    await ws.prepare(request)

    session = PtySession()
    session.start()
    histfile = os.path.join(tempfile.gettempdir(), f"tgym_hist_{session.pid}.log")
    histfile_pos = 0
    missions = load_missions(str(ROOT / "missions"))
    grades = load_grades()

    loop = asyncio.get_event_loop()

    # Read PTY output → send to browser via add_reader (non-blocking)
    async def pty_reader():
        queue = asyncio.Queue()

        def on_readable():
            try:
                data = os.read(session.master_fd, 4096)
                if data:
                    queue.put_nowait(data)
                else:
                    queue.put_nowait(None)
            except OSError:
                queue.put_nowait(None)

        loop.add_reader(session.master_fd, on_readable)
        try:
            while True:
                data = await queue.get()
                if data is None:
                    break
                await ws.send_bytes(data)
        finally:
            try:
                loop.remove_reader(session.master_fd)
            except Exception:
                pass

    reader = asyncio.create_task(pty_reader())

    # Poll HISTFILE for grading events every 500ms
    async def grading_poller():
        nonlocal histfile_pos, grades
        while True:
            await asyncio.sleep(0.5)
            try:
                if not os.path.exists(histfile):
                    continue
                with open(histfile, 'r', errors='replace') as f:
                    f.seek(histfile_pos)
                    chunk = f.read()
                    histfile_pos = f.tell()
                for line in chunk.splitlines():
                    cmd = line.strip()
                    if not cmd or cmd.startswith('#'):
                        continue
                    for m in missions:
                        for pi, page in enumerate(m.pages()):
                            for exp in page.expected:
                                if matches(cmd, exp):
                                    key = f'page_{pi}'
                                    mg = grades.setdefault(m.num, {})
                                    pg = mg.setdefault(key, {
                                        'title': page.title,
                                        'expected': page.expected,
                                        'done': [],
                                    })
                                    if cmd not in pg['done']:
                                        pg['done'].append(cmd)
                                        save_grades(grades)
                                        await ws.send_str(json.dumps({
                                            'type': 'grade',
                                            'mission': m.num,
                                            'page': pi,
                                            'title': page.title,
                                            'expected': page.expected,
                                            'done': pg['done'],
                                        }))
            except (OSError, asyncio.CancelledError):
                pass

    grader = asyncio.create_task(grading_poller())

    try:
        async for msg in ws:
            if msg.type == web.WSMsgType.BINARY:
                session.write(msg.data)
            elif msg.type == web.WSMsgType.TEXT:
                try:
                    ctrl = json.loads(msg.data)
                    if ctrl.get("type") == "resize":
                        session.resize(ctrl["rows"], ctrl["cols"])
                except (json.JSONDecodeError, KeyError):
                    pass
    finally:
        reader.cancel()
        grader.cancel()
        session.cleanup()

    return ws


# ─── Content API ──────────────────────────────────────────────────────────────

_content_cache = None


def get_content():
    global _content_cache
    if _content_cache is None:
        _content_cache = export_content(str(ROOT / "missions"))
    return _content_cache


async def api_content(request):
    return web.json_response(get_content())


async def index(request):
    return web.FileResponse(STATIC_DIR / "index.html")


async def healthcheck(request):
    return web.Response(text="ok")


# ─── App factory ──────────────────────────────────────────────────────────────


def create_app():
    app = web.Application()
    app.router.add_get("/healthz", healthcheck)
    app.router.add_get("/", index)
    app.router.add_get("/api/content", api_content)
    app.router.add_get("/ws/terminal", ws_terminal)
    app.router.add_static("/static/", STATIC_DIR, show_index=False)
    return app


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="terminal-gym web server")
    parser.add_argument("--port", type=int, default=8080)
    parser.add_argument("--host", default="127.0.0.1")
    args = parser.parse_args()

    app = create_app()
    print(f"\n  terminal-gym web UI")
    print(f"  http://{args.host}:{args.port}\n")
    web.run_app(app, host=args.host, port=args.port, print=None)
