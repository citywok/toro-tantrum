#!/bin/bash
set -euo pipefail

# Trigger NoNoNo build/test/install on the Mac builder.
#
# Pushes the current branch, sends a build-app SQS job to the
# mac-builder daemon, polls S3 for the result, and prints a summary.
#
# Usage:
#   ./trigger-build.sh              # test → archive → install
#   ./trigger-build.sh test         # run XCTests only
#   ./trigger-build.sh ci           # test → archive (no install)
#   ./trigger-build.sh archive      # archive only (skip tests)
#   ./trigger-build.sh install      # install last archive
#   ./trigger-build.sh --no-test    # archive → install (skip tests)
#
# Env:
#   CCT_BUILDER_SERVER     base URL for the long-poll relay (default https://fios.citywok.me:58888)
#   WORKER_AUTH_TOKEN      bearer token for the relay endpoint (optional; falls back to S3 polling)

REPO_ROOT="$(cd "$(dirname "$0")" && pwd)"
ACTION="${1:-all}"

exec python3 - "$REPO_ROOT" "$ACTION" <<'PYEOF'
import os
import secrets
import boto3
import json
import urllib.request
import urllib.error
import ssl
import sys
import subprocess
import time
from pathlib import Path

REGION = "us-east-1"
BUCKET = "cct-golf-builds"
QUEUE_URL = "https://sqs.us-east-1.amazonaws.com/613616587905/golf-builds"
SERVER_URL = os.environ.get("CCT_BUILDER_SERVER", "https://fios.citywok.me:58888")
POLL_TIMEOUT = 2100  # daemon timeout (1800s) plus polling/reporting slack
MANIFEST_PATH = ".mac-builder.yaml"

repo_root = sys.argv[1]
action = sys.argv[2]


def _worker_token() -> str:
    return os.environ.get("WORKER_AUTH_TOKEN", "")


def _long_poll_relay(cmd_id: str, token: str, timeout: int = 60) -> bool:
    if not token:
        return False
    url = f"{SERVER_URL}/api/builder/jobs/{cmd_id}?wait={timeout}"
    req = urllib.request.Request(url, headers={"Authorization": f"Bearer {token}"})
    ctx = ssl.create_default_context()
    ctx.check_hostname = False
    ctx.verify_mode = ssl.CERT_NONE
    try:
        with urllib.request.urlopen(req, timeout=timeout + 5, context=ctx) as resp:
            return resp.status == 200
    except Exception:
        return False


# ── Resolve repo URL ────────────────────────────────────────
repo_url = subprocess.check_output(
    ["git", "-C", repo_root, "remote", "get-url", "origin"],
    text=True,
).strip()
# Normalise SSH form (git@github.com:owner/repo.git) to HTTPS so the daemon
# can clone via the same URL it sees here.
if repo_url.startswith("git@github.com:"):
    repo_url = "https://github.com/" + repo_url[len("git@github.com:"):]
if not repo_url.endswith(".git"):
    repo_url += ".git"

# ── Push current branch ─────────────────────────────────────
branch = subprocess.check_output(
    ["git", "-C", repo_root, "rev-parse", "--abbrev-ref", "HEAD"],
    text=True,
).strip()

print(f"── NoNoNo {action} ──")
print(f"Branch: {branch}")
print(f"Pushing to origin...", end=" ", flush=True)
subprocess.run(
    ["git", "-C", repo_root, "push", "origin", branch],
    capture_output=True,
)
print("done")

# ── Resolve commit so the daemon can build at an exact SHA ──
commit = subprocess.check_output(
    ["git", "-C", repo_root, "rev-parse", "HEAD"],
    text=True,
).strip()

nonce = secrets.token_hex(8)
cmd_id = f"cmd-{int(time.time())}-{nonce}-nonono-{action}"

message = {
    "type": "command",
    "command_id": cmd_id,
    "action": "build-app",
    "params": {
        "repo_url": repo_url,
        "manifest_path": MANIFEST_PATH,
        "action": action,
        "commit": commit,
        "source_branch": branch,
        "timeout": 1800,
        "env": {
            "ASC_KEY_ID": "MA894X726H",
            "ASC_ISSUER_ID": "69a6de98-0f77-47e3-e053-5b8c7c11a4d1",
        },
    },
    "ts": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
}

# ── Send via SQS ────────────────────────────────────────────
sqs = boto3.client("sqs", region_name=REGION)
s3 = boto3.client("s3", region_name=REGION)

print(f"Sending to Mac builder...", end=" ", flush=True)
sqs.send_message(QueueUrl=QUEUE_URL, MessageBody=json.dumps(message))
print("sent")
print(f"Waiting for result (up to {POLL_TIMEOUT}s)...\n")

# ── Long-poll relay first, fall back to S3 ──────────────────
result_key = f"commands/{cmd_id}/result.json"
start = time.time()
result = None
token = _worker_token()
if _long_poll_relay(cmd_id, token, timeout=60):
    try:
        obj = s3.get_object(Bucket=BUCKET, Key=result_key)
        result = json.loads(obj["Body"].read())
    except Exception:
        result = None

while result is None and time.time() - start < POLL_TIMEOUT:
    try:
        obj = s3.get_object(Bucket=BUCKET, Key=result_key)
        result = json.loads(obj["Body"].read())
        break
    except s3.exceptions.NoSuchKey:
        pass
    except Exception as e:
        if "NoSuchKey" not in str(e):
            print(f"  poll error: {e}")
    elapsed = int(time.time() - start)
    if elapsed > 0 and elapsed % 15 == 0:
        print(f"  ... {elapsed}s", flush=True)
    time.sleep(2)

if result is None:
    print(f"\n✗ Timed out after {POLL_TIMEOUT}s")
    sys.exit(1)

elapsed = int(time.time() - start)

status = result["status"]
stdout = result.get("stdout", "")
stderr = result.get("stderr", "")
exit_code = result.get("exit_code", -1)

# ── Filter and display output ──────────────────────────────
# Skip git noise, xcodebuild compile/link/copy spam — keep only meaningful lines
import re

lines = stdout.strip().split("\n")
meaningful = []
skip_prefixes = (
    "M\t", "Your branch", "Already up", "Updating ", "Fast-forward",
    " 1 file changed", " mobile/", "Switched to", "From github",
    " * branch",
)
# xcodebuild verbose noise patterns
skip_patterns = re.compile(r"""
    ^\s*(cd|builtin-|/usr/bin/|/Applications/Xcode|CompileC|Ld\s|
    CompileSwift|MergeSwiftModule|SwiftDriver|SwiftCompile|
    CpResource|ProcessInfoPlist|LinkStoryboards|CopySwiftLibs|
    Copy\s|CodeSign\s|Validate\s|ExtractAppIntents|Signing\s|
    WriteAuxiliary|CreateBuildDirectory|MkDir|RegisterExecution|
    note:|warning:\s+no\s+rule|builtin-copy|builtin-swift|
    builtin-validation|Emitting\s|GenerateDSYM|ProcessProduct|
    SwiftMergeGeneratedHeaders|SwiftEmitModule|
    /Users/andrew/Library/Developer|
    \s*-[-\w]|.*\.hmap|.*\.json\s|.*DerivedData|.*modulecache|
    .*swiftmodule|.*Intermediates|.*Objects-normal|.*\.dep\b|
    .*\.profraw|.*replacing existing|.*OutputFileMap|
    .*swift-overrides|.*DerivedSources|.*xctoolchain|
    .*SwiftFileList|.*AppShortcuts|.*DependencyMetadata|
    upload:|Completed\s+\d|
    ^\d{4}-\d{2}-\d{2}\s+\d{2}:\d{2}:\d{2}\.\d+\s+(xcodebuild|appintentsmetadataprocessor))
""", re.VERBOSE | re.IGNORECASE)

for line in lines:
    stripped = line.strip()
    if not stripped:
        continue
    if any(stripped.startswith(p) for p in skip_prefixes):
        continue
    if skip_patterns.match(stripped):
        continue
    meaningful.append(line)

print("\n".join(meaningful))

# ── Summary ─────────────────────────────────────────────────
print(f"\n{'─' * 40}")
if exit_code == 0:
    print(f"✓ {action.upper()} PASSED ({elapsed}s)")
else:
    print(f"✗ {action.upper()} FAILED (exit {exit_code}, {elapsed}s)")
    if stderr:
        # Show last few lines of stderr for diagnostics
        for line in stderr.strip().split("\n")[-5:]:
            if not any(line.strip().startswith(p) for p in skip_prefixes):
                print(f"  {line}")

sys.exit(0 if exit_code == 0 else 1)
PYEOF
