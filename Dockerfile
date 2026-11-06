# syntax=docker/dockerfile:1
FROM debian:bookworm-slim AS build
ARG GODOT_VERSION=4.4.1
RUN apt-get update && apt-get install -y --no-install-recommends ca-certificates curl unzip && rm -rf /var/lib/apt/lists/*
WORKDIR /tools
RUN --mount=type=secret,id=proxy_ca \
    set -eu; \
    if [ -f /run/secrets/proxy_ca ]; then export CURL_CA_BUNDLE=/run/secrets/proxy_ca; fi; \
    base="https://github.com/godotengine/godot/releases/download/${GODOT_VERSION}-stable"; \
    curl -fL --retry 3 "$base/Godot_v${GODOT_VERSION}-stable_linux.x86_64.zip" -o "Godot_v${GODOT_VERSION}-stable_linux.x86_64.zip"; \
    curl -fL --retry 3 "$base/Godot_v${GODOT_VERSION}-stable_export_templates.tpz" -o "Godot_v${GODOT_VERSION}-stable_export_templates.tpz"; \
    curl -fL --retry 3 "$base/SHA512-SUMS.txt" -o SHA512-SUMS.txt; \
    grep -F -e "Godot_v${GODOT_VERSION}-stable_linux.x86_64.zip" -e "Godot_v${GODOT_VERSION}-stable_export_templates.tpz" SHA512-SUMS.txt > selected.sha512; \
    test "$(wc -l < selected.sha512)" -eq 2; \
    sha512sum -c selected.sha512; \
    unzip -q "Godot_v${GODOT_VERSION}-stable_linux.x86_64.zip"; \
    install -m755 "Godot_v${GODOT_VERSION}-stable_linux.x86_64" /usr/local/bin/godot; \
    mkdir -p /root/.local/share/godot/export_templates/${GODOT_VERSION}.stable; \
    unzip -j "Godot_v${GODOT_VERSION}-stable_export_templates.tpz" templates/linux_debug.x86_64 templates/linux_release.x86_64 -d /root/.local/share/godot/export_templates/${GODOT_VERSION}.stable; \
    rm -f *.zip *.tpz Godot_v*-stable_linux.x86_64
WORKDIR /project
COPY . .
RUN godot --headless --editor --import --quit && mkdir -p build/server && godot --headless --export-release LinuxServer build/server/GameForMe-Server.x86_64 && test -s build/server/GameForMe-Server.x86_64
FROM debian:bookworm-slim AS runtime
RUN apt-get update && apt-get install -y --no-install-recommends python3 && rm -rf /var/lib/apt/lists/*
WORKDIR /app
COPY --from=build --chmod=755 /project/build/server/GameForMe-Server.x86_64 /app/GameForMe-Server
COPY --chmod=644 hosting/server.py /app/server.py
ENV GAME_SERVER=1 PORT=10000 XDG_DATA_HOME=/tmp/game-data XDG_CONFIG_HOME=/tmp/game-config XDG_CACHE_HOME=/tmp/game-cache
USER 10001:10001
EXPOSE 10000
CMD ["python3", "/app/server.py"]
