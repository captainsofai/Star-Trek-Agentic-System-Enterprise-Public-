# USS Enterprise: Velín pro Google Cloud Run.
# Sestavení z kořene repa: docker build -f warp/gcp/Dockerfile .
FROM node:22-slim
RUN apt-get update \
 && apt-get install -y --no-install-recommends python3 ca-certificates git \
 && rm -rf /var/lib/apt/lists/* \
 && npm install -g @anthropic-ai/claude-code
WORKDIR /app
COPY plugin /app/plugin
COPY warp /app/warp
ENV LANG=C.UTF-8 PYTHONUNBUFFERED=1 ENTERPRISE_CONFIG=/data/.velin/config.json
CMD ["python3", "/app/warp/velin.py", "server"]
