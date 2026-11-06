#!/bin/sh
set -eu
cd "$(dirname "$0")"
export GAME_SERVER=1
exec ./GameForMe-Server.x86_64 --headless
