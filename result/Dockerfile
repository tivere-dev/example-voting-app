# Node 24 LTS, pinned by version tag (readable) and digest (immutable).
FROM node:24.22.0-trixie-slim@sha256:7f486cabe892bff8fef04c0f7da8dba84a560be3e4e2740b7a86afc57ebec315

# tini runs as PID 1 so Ctrl+C / `docker stop` / Kubernetes SIGTERM reach node
RUN apt-get update && \
    apt-get install -y --no-install-recommends tini && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /usr/local/app

ENV NODE_ENV=production \
    PORT=8080

# Dependencies first, installed exactly as recorded in package-lock.json
COPY package.json package-lock.json ./
RUN npm ci --omit=dev && npm cache clean --force

# Code stays owned by root, so the app user can read it but not change it
COPY . .

# The base image's built-in "node" user, given by number so Kubernetes can
# verify runAsNonRoot
USER 1000

# Ports below 1024 need root on many Kubernetes nodes, so listen on 8080
EXPOSE 8080

# Node's own http module does the check, so curl is not needed in the image
HEALTHCHECK --interval=15s --timeout=5s --start-period=10s --retries=3 \
  CMD ["node", "-e", "require('http').get('http://localhost:8080/', r => process.exit(r.statusCode === 200 ? 0 : 1)).on('error', () => process.exit(1))"]

ENTRYPOINT ["/usr/bin/tini", "--"]
CMD ["node", "server.js"]
