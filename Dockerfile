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
USER 1000
