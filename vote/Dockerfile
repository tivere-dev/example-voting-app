# Base image pinned by version tag (readable) and digest (immutable).
FROM python:3.13.16-slim-trixie@sha256:70729b46c69b4f1e97c4822c1af3df53a1476cf5ddc6c087c0c10bc3a5678c2f

# Don't write .pyc files, flush logs straight to stdout, keep pip quiet and cache-free
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1 \
    PIP_ROOT_USER_ACTION=ignore

WORKDIR /usr/local/app

# Dependencies first: this layer is reused until requirements.txt changes.
# pip is removed afterwards: the app never installs packages at runtime, and
# pip's own bundled copies of certifi, urllib3, msgpack and setuptools were
# flagged by Trivy (including a CRITICAL in certifi).
COPY requirements.txt ./
RUN pip install -r requirements.txt && pip uninstall -y pip

# Unprivileged user with a fixed numeric UID, so Kubernetes can verify runAsNonRoot
RUN groupadd --system --gid 10001 app && \
    useradd --system --uid 10001 --gid app --no-create-home --shell /usr/sbin/nologin app

# Code stays owned by root, so the app user can read it but not change it
COPY . .

USER 10001

# Ports below 1024 need root on many Kubernetes nodes, so listen on 8080
EXPOSE 8080

# Python's standard library does the check, so curl is not needed in the image
HEALTHCHECK --interval=15s --timeout=5s --start-period=10s --retries=3 \
  CMD ["python", "-c", "import urllib.request; urllib.request.urlopen('http://localhost:8080/', timeout=4)"]

CMD ["gunicorn", "app:app", "-b", "0.0.0.0:8080", "--log-file", "-", "--access-logfile", "-", "--workers", "4", "--keep-alive", "0", "--worker-tmp-dir", "/dev/shm", "--no-control-socket"]
