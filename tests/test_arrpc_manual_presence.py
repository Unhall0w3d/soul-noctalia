#!/usr/bin/env python3
"""Deterministic protocol checks for the bounded arRPC helper."""

from __future__ import annotations

import importlib.machinery
import importlib.util
import json
import socket
import struct
import sys
import tempfile
import threading
import unittest
from contextlib import redirect_stdout
from io import StringIO
from pathlib import Path
from unittest import mock


ROOT = Path(__file__).resolve().parents[1]
HELPER = ROOT / "manual-presence" / "arrpc-manual-presence"
sys.dont_write_bytecode = True
loader = importlib.machinery.SourceFileLoader("arrpc_manual_presence", str(HELPER))
spec = importlib.util.spec_from_loader("arrpc_manual_presence", loader)
assert spec and spec.loader
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


class ArrpcManualPresenceTests(unittest.TestCase):
    def test_validators_bound_input(self) -> None:
        self.assertTrue(module.valid_application_id("12345678901234567"))
        self.assertFalse(module.valid_application_id("not-an-id"))
        self.assertFalse(module.valid_application_id("123"))
        self.assertTrue(module.valid_text("Working"))
        self.assertFalse(module.valid_text(""))
        self.assertFalse(module.valid_text("x" * 129))

    def test_socket_candidates_prefer_flatpak_vesktop_then_native_runtime(self) -> None:
        with mock.patch.dict(module.os.environ, {"XDG_RUNTIME_DIR": "/tmp/arrpc-runtime"}, clear=True):
            candidates = module.socket_candidates()
        self.assertEqual(
            candidates[0],
            Path("/tmp/arrpc-runtime/.flatpak/dev.vencord.Vesktop/xdg-run/discord-ipc-0"),
        )
        self.assertEqual(candidates[10], Path("/tmp/arrpc-runtime/discord-ipc-0"))

    def test_socket_identity_changes_with_rpc_instance(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            socket_path = Path(temporary) / "discord-ipc-0"
            socket_path.touch()
            with mock.patch.object(module, "socket_candidates", return_value=[socket_path]):
                identity = module.socket_identity()
            self.assertRegex(identity, r"^\d+:\d+$")

    def test_publish_handshake_and_activity_frame(self) -> None:
        received: list[tuple[int, dict]] = []
        with tempfile.TemporaryDirectory() as temporary:
            socket_path = Path(temporary) / "discord-ipc-0"
            server = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
            server.bind(str(socket_path))
            server.listen(1)

            def serve() -> None:
                connection, _ = server.accept()
                with connection:
                    for expected in (0, 1):
                        header = module.read_exact(connection, 8)
                        opcode, size = struct.unpack("<II", header)
                        payload = json.loads(module.read_exact(connection, size))
                        received.append((opcode, payload))
                        if expected == 0:
                            connection.sendall(module.encode(1, {"evt": "READY", "data": {}}))
                        else:
                            connection.sendall(module.encode(1, {"cmd": "SET_ACTIVITY", "nonce": payload["nonce"], "data": {}}))

            thread = threading.Thread(target=serve)
            thread.start()
            old_candidates = module.socket_candidates
            module.socket_candidates = lambda: [socket_path]
            try:
                module.send_activity("12345678901234567", {"details": "Testing", "instance": False})
            finally:
                module.socket_candidates = old_candidates
                thread.join(timeout=2)
                server.close()

        self.assertEqual([item[0] for item in received], [0, 1])
        self.assertEqual(received[0][1]["client_id"], "12345678901234567")
        self.assertEqual(received[1][1]["cmd"], "SET_ACTIVITY")
        self.assertEqual(received[1][1]["args"]["activity"]["details"], "Testing")

    def test_clear_uses_same_stable_activity_slot(self) -> None:
        captured: list[tuple[str, dict | None]] = []
        with mock.patch.object(module, "send_activity", side_effect=lambda app_id, activity: captured.append((app_id, activity))):
            with mock.patch.object(sys, "argv", ["arrpc-manual-presence", "clear", "--application-id", "12345678901234567"]):
                with redirect_stdout(StringIO()):
                    self.assertEqual(module.main(), 0)
        self.assertEqual(captured, [("12345678901234567", None)])


if __name__ == "__main__":
    unittest.main()
