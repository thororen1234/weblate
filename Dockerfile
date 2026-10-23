FROM ubuntu:26.04 AS brotli
ARG BROTLI_VERSION=1.2.1
ARG BROTLI_SHA256=98d35d11a78dc453aebb7d10c3748f3f73ff78c8267c0dc697b8631f67bf7e8f
RUN apt-get update && \
    apt-get install -y --no-install-recommends ca-certificates curl cmake gcc libc6-dev make && \
    curl -fsSLo /tmp/brotli.tar.gz "https://github.com/google/brotli/archive/refs/tags/v${BROTLI_VERSION}.tar.gz" && \
    echo "${BROTLI_SHA256}  /tmp/brotli.tar.gz" | sha256sum -c - && \
    tar xzf /tmp/brotli.tar.gz -C /tmp && \
    cmake -S "/tmp/brotli-${BROTLI_VERSION}" -B /tmp/build -DCMAKE_BUILD_TYPE=Release -DBUILD_TESTING=OFF \
    -DCMAKE_INSTALL_PREFIX=/out -DCMAKE_INSTALL_LIBDIR=lib && \
    cmake --build /tmp/build -j"$(nproc)" && \
    cmake --install /tmp/build

FROM weblate/weblate:2026.10
USER root
RUN file=$(find /app/venv -path '*/weblate/accounts/notifications.py') && \
    test -n "$file" && \
    sed -i -E 's|"Message-ID": f"\{uuid4\(\)\}@\{get_site_domain\(\)\}"|"Message-ID": f"<{uuid4()}@{get_site_domain()}>"|' "$file" && \
    grep -q '"Message-ID": f"<{uuid4()}@{get_site_domain()}>"' "$file"
RUN file=$(find /app/venv -path '*/weblate/settings_docker.py') && \
    test -n "$file" && \
    sed -i -E 's|^ADMINS = \(formataddr\(\(ADMIN_NAME, ADMIN_EMAIL\)\),\)$|ADMINS = () if ADMIN_EMAIL.endswith("@example.com") else (formataddr((ADMIN_NAME, ADMIN_EMAIL)),)|' "$file" && \
    grep -q '^ADMINS = () if ADMIN_EMAIL.endswith("@example.com")' "$file"
RUN file=$(find /app/venv -path '*/weblate/accounts/tasks.py') && \
    test -n "$file" && \
    sed -i -E 's|^(        for mail in mails:)$|\1\n            if mail["address"].lower().endswith("@example.com"):\n                continue|' "$file" && \
    grep -q '^            if mail\["address"\].lower().endswith("@example.com"):$' "$file"
COPY --from=brotli /out/lib/ /tmp/brotli/
RUN libdir=/usr/lib/x86_64-linux-gnu && \
    rm -f "$libdir"/libbrotli*.so.1.* && \
    cp -P /tmp/brotli/libbrotli*.so.1* "$libdir"/ && \
    for lib in dec common; do \
    for f in /app/venv/lib/python3*/site-packages/pillow.libs/libbrotli${lib}-*.so*; do \
    if [ -e "$f" ]; then cp "/tmp/brotli/libbrotli${lib}.so.1" "$f"; fi; \
    done; \
    done && \
    rm -rf /tmp/brotli && \
    uv pip install --python /app/venv/bin/python --no-cache brotli==1.2.1 && \
    /app/venv/bin/python -c "import ctypes, glob, importlib.metadata as m, brotli; \
    fixed = (1 << 24) | (2 << 12) | 1; \
    libs = ['libbrotlidec.so.1', *glob.glob('/app/venv/lib/python3*/site-packages/pillow.libs/libbrotlidec-*.so*')]; \
    assert all(ctypes.CDLL(p).BrotliDecoderVersion() >= fixed for p in libs), libs; \
    assert m.version('brotli') == '1.2.1' and brotli.decompress(brotli.compress(b'ok')) == b'ok'; \
    from PIL import features; assert features.check('freetype2')"
USER 1000
