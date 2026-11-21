# Test environment: build + smoke-run on Linux from any machine. Also what CI runs.
#   docker build -t promethee-linux .                          (latest release)
#   docker build --build-arg VERSION=1.4.1 -t promethee-linux .
#   docker run --rm --shm-size=1g promethee-linux   (Chromium needs more than the default 64MB /dev/shm)
# Debian 13 with Node from apt (20.x, npm 9): exactly what the README tells users to install.
# The node:22 image hid a real break here (unpinned node-gyp 13 needs Node 22.22+).
FROM debian:trixie
RUN apt-get update && apt-get install -y --no-install-recommends \
      ca-certificates curl nodejs npm \
      unzip python3 make g++ xvfb xauth x11-utils \
      libnss3 libgtk-3-0 libgbm1 libasound2t64 libxss1 libsecret-1-0 \
    && rm -rf /var/lib/apt/lists/*
WORKDIR /src
COPY build.sh promethee ./
COPY patches ./patches
ARG VERSION=
RUN ./build.sh $VERSION
# Smoke test: the app must still run after 20s (--no-sandbox: container runs as root),
# and its UI must not hit a script error (a blank or "This screen went dark" window).
CMD ["bash", "-c", "timeout 20 xvfb-run -a ./promethee --no-sandbox --enable-logging=stderr > /tmp/app.log 2>&1; s=$?; grep -v -E 'dbus|APPIMAGE' /tmp/app.log | tail -15; if grep -q -E 'Uncaught|Failed to fetch dynamically imported module' /tmp/app.log; then echo 'FAIL: the UI hit a script error'; exit 1; fi; [ $s = 124 ] && echo \"OK: Promethee $(cat dist/current/VERSION) still running after 20s\" || { echo \"FAIL: exited with $s\"; exit 1; }"]
