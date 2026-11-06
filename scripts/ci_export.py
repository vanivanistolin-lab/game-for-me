"""Run an export with actionable, credential-free GitHub annotations."""
import pathlib
import subprocess
import sys

preset, output, flag = sys.argv[1:]
result = subprocess.run(['godot', '--headless', flag, preset, output], stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
print(result.stdout)
target = pathlib.Path(output)
if result.returncode or not target.exists() or target.stat().st_size < 1_000_000:
    tail = result.stdout[-7000:]
    safe = tail.replace('%', '%25').replace('\r', '%0D').replace('\n', '%0A')
    print(f'::error title={preset} export failed::{safe}')
    sys.exit(1)
