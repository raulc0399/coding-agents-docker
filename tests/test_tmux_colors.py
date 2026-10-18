import os
from pathlib import Path
import pty
import shutil
import subprocess
import tempfile
import time
import unittest


ROOT = Path(__file__).resolve().parents[1]


@unittest.skipUnless(shutil.which("tmux"), "tmux is required for color integration tests")
class TmuxColorTests(unittest.TestCase):
    def write_config(self, agent, destination):
        dockerfile = (ROOT / agent / "Dockerfile").read_text().replace("\\\n", "")
        config = ""
        for instruction in dockerfile.splitlines():
            if instruction.startswith("RUN ") and instruction.endswith(" > /etc/tmux.conf"):
                # Evaluate the image's config writer without writing to the host's /etc.
                command = instruction[4:].removesuffix(" > /etc/tmux.conf")
                config += subprocess.check_output(["sh", "-c", command], text=True)
        destination.write_text(config)

    def test_attached_clients_support_rgb_and_panes_support_256_colors(self):
        for agent in ("claude", "codex"):
            with self.subTest(agent=agent), tempfile.TemporaryDirectory(prefix="tmux-colors-") as directory:
                config = Path(directory) / "tmux.conf"
                self.write_config(agent, config)
                command = ["tmux", "-S", str(Path(directory) / "socket"), "-f", str(config)]
                env = dict(os.environ, TERM="xterm", COLORTERM="truecolor", LANG="C.UTF-8")
                env.pop("TMUX", None)
                subprocess.run([*command, "new", "-d", "-s", "colors", "sleep 30"],
                               env=env, check=True, capture_output=True)
                master, slave = pty.openpty()
                client = subprocess.Popen([*command, "-u", "attach", "-t", "colors"],
                                          env=env, stdin=slave, stdout=slave, stderr=slave)
                try:
                    features = ""
                    deadline = time.monotonic() + 5
                    while not features and time.monotonic() < deadline:
                        features = subprocess.check_output(
                            [*command, "list-clients", "-F", "#{client_termfeatures}"],
                            env=env, text=True).strip()
                        if not features:
                            time.sleep(0.05)
                    self.assertIn("RGB", features.split(","))
                    self.assertIn("256", features.split(","))
                    terminal = subprocess.check_output(
                        [*command, "show-options", "-gv", "default-terminal"], env=env, text=True).strip()
                    colors = subprocess.check_output(["tput", "-T", terminal, "colors"], env=env, text=True)
                    self.assertGreaterEqual(int(colors), 256)
                    focus_events = subprocess.check_output(
                        [*command, "show-options", "-sv", "focus-events"], env=env, text=True).strip()
                    self.assertEqual(focus_events, "on")
                finally:
                    subprocess.run([*command, "kill-server"], env=env, capture_output=True)
                    client.wait(timeout=5)
                    os.close(slave)
                    os.close(master)


if __name__ == "__main__":
    unittest.main()
