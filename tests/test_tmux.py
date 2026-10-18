import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]
CLI_FLAGS = {
    "claude": ["--dangerously-skip-permissions"],
    "codex": ["--no-daemon", "--dangerously-bypass-approvals-and-sandbox"],
}
MOCK_COMMAND = """#!/usr/bin/env python3
import json
import os
from pathlib import Path
import sys

command = Path(sys.argv[0]).name
args = sys.argv[1:]
with open(os.environ['MOCK_LOG'], 'a') as log:
    log.write(json.dumps([command, *args]) + '\\n')
if command == 'tmux' and 'has-session' in args:
    sys.exit(0 if os.environ.get('MOCK_SESSION') == '1' else 1)
if command == 'claude' and args == ['auth', 'status']:
    print('{"loggedIn":false}')
if command == 'node':
    print('unavailable')
if command == 'docker' and args[0] == 'ps':
    if os.environ.get('MOCK_DOCKER_ERROR') == '1':
        sys.exit(1)
    print(os.environ.get('MOCK_CONTAINER', ''), end='')
"""


class TmuxStartupTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix="agent-tmux-test-")
        self.addCleanup(self.temporary.cleanup)
        self.directory = Path(self.temporary.name)
        self.log = self.directory / "commands.jsonl"
        for command in ("tmux", "claude", "codex", "node", "docker"):
            executable = self.directory / command
            executable.write_text(MOCK_COMMAND)
            executable.chmod(0o755)
        self.env = dict(os.environ, PATH=f"{self.directory}:{os.environ['PATH']}",
                        MOCK_LOG=str(self.log), MOCK_SESSION="0", MOCK_CONTAINER="", MOCK_DOCKER_ERROR="0",
                        HOST_MCP_TOKEN="", BASH_ENV="")

    def run_script(self, *args):
        self.log.write_text("")
        result = subprocess.run(["bash", *args], env=self.env, input="",
                                capture_output=True, text=True, cwd=self.directory)
        self.assertEqual(result.returncode, 0, result.stderr)
        return result, [json.loads(line) for line in self.log.read_text().splitlines()]

    def test_new_sessions_force_utf8_and_preserve_cli_flags(self):
        for agent, flags in CLI_FLAGS.items():
            with self.subTest(agent=agent):
                _, commands = self.run_script(str(ROOT / agent / "entrypoint.sh"))
                self.assertEqual(commands[-1], ["tmux", "-u", "new", "-A", "-s", agent, agent, *flags])

    def test_existing_sessions_reattach_without_reconfiguring_agent(self):
        self.env["MOCK_SESSION"] = "1"
        self.env["HOST_MCP_TOKEN"] = "test-token"
        for agent in CLI_FLAGS:
            with self.subTest(agent=agent):
                _, commands = self.run_script(str(ROOT / agent / "entrypoint.sh"))
                self.assertEqual(commands, [
                    ["tmux", "has-session", "-t", f"={agent}"],
                    ["tmux", "-u", "attach", "-t", f"={agent}"],
                ])

    def test_launchers_reconnect_to_project_container_without_starting_another(self):
        for agent in CLI_FLAGS:
            with self.subTest(agent=agent):
                self.env["MOCK_CONTAINER"] = f"d-{agent}-project-1\n"
                _, commands = self.run_script(str(ROOT / f"d_{agent}"))
                self.assertEqual(commands, [
                    ["docker", "ps", "--format", "{{.Names}}",
                     "--filter", f"label=coding-agents.agent={agent}",
                     "--filter", f"label=coding-agents.workdir={self.directory}"],
                    ["docker", "exec", "-it", f"d-{agent}-project-1", f"{agent}-entrypoint"],
                ])

    def test_container_lookup_handles_no_match_and_duplicate_matches(self):
        for containers, expected in (("", ""), ("project-2\nproject-1\n", "project-2")):
            with self.subTest(containers=containers):
                self.env["MOCK_CONTAINER"] = containers
                result, commands = self.run_script(
                    "-c", 'set -euo pipefail; source "$1"; container=""; '
                    'find_agent_container claude "/projects/with spaces" container; printf "%s" "$container"',
                    "bash", str(ROOT / "lib/env_mounts.sh"))
                self.assertEqual(result.stdout, expected)
                self.assertIn("label=coding-agents.workdir=/projects/with spaces", commands[0])

    def test_launchers_stop_when_container_lookup_fails(self):
        self.env["MOCK_DOCKER_ERROR"] = "1"
        for agent in CLI_FLAGS:
            with self.subTest(agent=agent):
                self.log.write_text("")
                result = subprocess.run(["bash", str(ROOT / f"d_{agent}")], env=self.env,
                                        input="", capture_output=True, text=True, cwd=self.directory)
                self.assertNotEqual(result.returncode, 0)
                commands = [json.loads(line) for line in self.log.read_text().splitlines()]
                self.assertEqual(len(commands), 1)
                self.assertEqual(commands[0][:2], ["docker", "ps"])


if __name__ == "__main__":
    unittest.main()
