#!/usr/bin/env python3
"""Small dependency-free VNC client for interacting with the QEMU test VM."""

import argparse
import socket
import struct
import time
import zlib
from pathlib import Path


KEYSYMS = {
    "backspace": 0xFF08,
    "tab": 0xFF09,
    "return": 0xFF0D,
    "escape": 0xFF1B,
    "delete": 0xFFFF,
    "left": 0xFF51,
    "up": 0xFF52,
    "right": 0xFF53,
    "down": 0xFF54,
    "ctrl": 0xFFE3,
    "shift": 0xFFE1,
    "alt": 0xFFE9,
    "super": 0xFFEB,
}

SHIFTED_CHARACTERS = {
    "!": "1",
    "@": "2",
    "#": "3",
    "$": "4",
    "%": "5",
    "^": "6",
    "&": "7",
    "*": "8",
    "(": "9",
    ")": "0",
    "_": "-",
    "+": "=",
    "{": "[",
    "}": "]",
    "|": "\\",
    ":": ";",
    '"': "'",
    "<": ",",
    ">": ".",
    "?": "/",
    "~": "`",
}


class VncClient:
    def __init__(self, host: str, port: int):
        self.sock = socket.create_connection((host, port), timeout=10)
        self.width = 0
        self.height = 0
        self._handshake()

    def _recv(self, size: int) -> bytes:
        result = bytearray()
        while len(result) < size:
            chunk = self.sock.recv(size - len(result))
            if not chunk:
                raise EOFError("VNC server closed the connection")
            result.extend(chunk)
        return bytes(result)

    def _handshake(self) -> None:
        version = self._recv(12)
        if not version.startswith(b"RFB "):
            raise RuntimeError(f"unexpected VNC banner: {version!r}")
        self.sock.sendall(b"RFB 003.008\n")

        security_types = self._recv(self._recv(1)[0])
        if 1 not in security_types:
            raise RuntimeError("the QEMU VNC server does not allow local no-auth access")
        self.sock.sendall(b"\x01")
        if self._recv(4) != b"\x00\x00\x00\x00":
            raise RuntimeError("VNC security negotiation failed")

        self.sock.sendall(b"\x01")
        self.width, self.height = struct.unpack(">HH", self._recv(4))
        self._recv(16)
        self._recv(struct.unpack(">I", self._recv(4))[0])

        pixel_format = struct.pack(
            ">BBBBHHHBBBxxx", 32, 24, 0, 1, 255, 255, 255, 16, 8, 0
        )
        self.sock.sendall(b"\x00\x00\x00\x00" + pixel_format)
        self.sock.sendall(struct.pack(">BBHii", 2, 0, 2, 0, -223))

    def key_event(self, keysym: int, down: bool) -> None:
        self.sock.sendall(struct.pack(">BBHI", 4, int(down), 0, keysym))
        time.sleep(0.04)

    def key(self, keysym: int) -> None:
        self.key_event(keysym, True)
        self.key_event(keysym, False)

    def shifted_key(self, keysym: int) -> None:
        self.key_event(KEYSYMS["shift"], True)
        self.key(keysym)
        self.key_event(KEYSYMS["shift"], False)

    def chord(self, value: str) -> None:
        parts = value.lower().split("+")
        if len(parts) < 2:
            raise ValueError("a chord needs at least one modifier and one key")
        modifiers = [KEYSYMS[part] for part in parts[:-1]]
        key_name = parts[-1]
        keysym = KEYSYMS.get(key_name, ord(key_name) if len(key_name) == 1 else None)
        if keysym is None:
            raise ValueError(f"unknown key in chord: {key_name}")
        for modifier in modifiers:
            self.key_event(modifier, True)
        self.key(keysym)
        for modifier in reversed(modifiers):
            self.key_event(modifier, False)

    def type_text(self, value: str) -> None:
        for character in value:
            if character == "\n":
                self.key(KEYSYMS["return"])
            elif character == "\t":
                self.key(KEYSYMS["tab"])
            elif character in SHIFTED_CHARACTERS:
                self.shifted_key(ord(SHIFTED_CHARACTERS[character]))
            else:
                self.key(ord(character))

    def pointer(self, x: int, y: int, button_mask: int = 0) -> None:
        self.sock.sendall(struct.pack(">BBHH", 5, button_mask, x, y))

    def click(self, x: int, y: int, button: int) -> None:
        mask = {1: 1, 2: 2, 3: 4}[button]
        self.pointer(x, y, mask)
        time.sleep(0.08)
        self.pointer(x, y)

    def screenshot(self) -> bytes:
        self.sock.sendall(
            struct.pack(">BBHHHH", 3, 0, 0, 0, self.width, self.height)
        )
        image = bytearray(self.width * self.height * 3)

        while True:
            message_type = self._recv(1)[0]
            if message_type == 0:
                self._recv(1)
                rectangles = struct.unpack(">H", self._recv(2))[0]
                for _ in range(rectangles):
                    x, y, width, height, encoding = struct.unpack(
                        ">HHHHi", self._recv(12)
                    )
                    if encoding == -223:
                        self.width, self.height = width, height
                        image = bytearray(width * height * 3)
                    elif encoding == 0:
                        raw = self._recv(width * height * 4)
                        for row_number in range(height):
                            row = raw[
                                row_number * width * 4 : (row_number + 1) * width * 4
                            ]
                            rgb = bytearray(width * 3)
                            rgb[0::3] = row[2::4]
                            rgb[1::3] = row[1::4]
                            rgb[2::3] = row[0::4]
                            offset = ((y + row_number) * self.width + x) * 3
                            image[offset : offset + width * 3] = rgb
                    else:
                        raise RuntimeError(f"unsupported VNC encoding: {encoding}")
                return bytes(image)
            if message_type == 2:
                continue
            if message_type == 3:
                self._recv(struct.unpack(">I", self._recv(4))[0])
                continue
            raise RuntimeError(f"unsupported VNC message: {message_type}")


def png_chunk(chunk_type: bytes, data: bytes) -> bytes:
    return (
        struct.pack(">I", len(data))
        + chunk_type
        + data
        + struct.pack(">I", zlib.crc32(chunk_type + data) & 0xFFFFFFFF)
    )


def write_png(path: Path, width: int, height: int, rgb: bytes) -> None:
    scanlines = b"".join(
        b"\x00" + rgb[row * width * 3 : (row + 1) * width * 3]
        for row in range(height)
    )
    data = (
        b"\x89PNG\r\n\x1a\n"
        + png_chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 2, 0, 0, 0))
        + png_chunk(b"IDAT", zlib.compress(scanlines, 6))
        + png_chunk(b"IEND", b"")
    )
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(data)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--host", default="127.0.0.1")
    parser.add_argument("--port", type=int, default=5901)
    subparsers = parser.add_subparsers(dest="command", required=True)

    screenshot = subparsers.add_parser("screenshot")
    screenshot.add_argument("output", type=Path)

    click = subparsers.add_parser("click")
    click.add_argument("x", type=int)
    click.add_argument("y", type=int)
    click.add_argument("--button", type=int, choices=(1, 2, 3), default=1)

    move = subparsers.add_parser("move")
    move.add_argument("x", type=int)
    move.add_argument("y", type=int)

    type_command = subparsers.add_parser("type")
    type_command.add_argument("text")

    key = subparsers.add_parser("key")
    key.add_argument("name", choices=sorted(KEYSYMS))

    chord = subparsers.add_parser("chord")
    chord.add_argument("keys", help="Key chord such as ctrl+shift+e or alt+return")

    args = parser.parse_args()
    client = VncClient(args.host, args.port)
    if args.command == "screenshot":
        rgb = client.screenshot()
        write_png(args.output, client.width, client.height, rgb)
        print(args.output)
    elif args.command == "click":
        client.click(args.x, args.y, args.button)
    elif args.command == "move":
        client.pointer(args.x, args.y)
    elif args.command == "type":
        client.type_text(args.text)
    elif args.command == "key":
        client.key(KEYSYMS[args.name])
    elif args.command == "chord":
        client.chord(args.keys)


if __name__ == "__main__":
    main()
