FROM weblate/weblate:2026.7
USER root
RUN file=$(find /app/venv -path '*/weblate/accounts/notifications.py') && \
    test -n "$file" && \
    sed -i -E 's|"Message-ID": f"\{uuid4\(\)\}@\{get_site_domain\(\)\}"|"Message-ID": f"<{uuid4()}@{get_site_domain()}>"|' "$file" && \
    grep -q '"Message-ID": f"<{uuid4()}@{get_site_domain()}>"' "$file"
USER 1000
