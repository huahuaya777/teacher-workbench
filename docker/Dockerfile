FROM python:3.12-slim-trixie
ENV PYTHONDONTWRITEBYTECODE=1 PYTHONUNBUFFERED=1 \
    DJANGO_SETTINGS_MODULE=config.settings_container \
    PATH="/usr/lib/postgresql/17/bin:${PATH}"
RUN apt-get update \
    && mkdir -p /etc/postgresql-common \
    && printf 'create_main_cluster = false\n' > /etc/postgresql-common/createcluster.conf \
    && apt-get install -y --no-install-recommends postgresql-17 redis-server gosu tini \
    && rm -rf /var/lib/apt/lists/* \
    && groupadd --gid 10001 workbench \
    && useradd --uid 10001 --gid workbench --no-create-home workbench
WORKDIR /app
COPY requirements.txt requirements-container.txt ./
RUN pip install --no-cache-dir -r requirements-container.txt
# Deliberate allowlist: never COPY the repository, private files, or deployment history.
COPY manage.py ./
COPY config/*.py ./config/
COPY workbench/ ./workbench/
COPY templates/ ./templates/
COPY docker/ ./docker/
RUN chmod -R a+rX /app \
    && chmod 755 docker/entrypoint.sh \
    && mkdir -p /app/staticfiles /app/data \
    && DJANGO_DEBUG=1 DJANGO_SETTINGS_MODULE=config.settings python manage.py collectstatic --noinput \
    && chown -R 10001:10001 /app/staticfiles /app/data \
    && install -d -m 700 -o 10001 -g 10001 /var/lib/teacher-workbench /var/lib/teacher-workbench-keyring
EXPOSE 8000
VOLUME ["/var/lib/teacher-workbench", "/var/lib/teacher-workbench-keyring"]
USER 10001:10001
HEALTHCHECK --interval=20s --timeout=5s --start-period=90s --retries=3 \
    CMD ["python", "/app/docker/healthcheck.py"]
ENTRYPOINT ["/usr/bin/tini", "--", "/app/docker/entrypoint.sh"]
CMD ["serve"]
