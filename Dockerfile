# syntax=docker/dockerfile:1.7
FROM python:3.11-slim AS base

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1

WORKDIR /app

# System deps
RUN apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates curl \
    && rm -rf /var/lib/apt/lists/*

# Create non-root user
RUN groupadd -g 10001 appgroup \
    && useradd -r -u 10001 -g appgroup appuser

# Install Python deps first (leverage layer caching)
COPY app/requirements.txt /app/app/requirements.txt
RUN pip install --upgrade pip \
    && pip install -r /app/app/requirements.txt

# Copy application code
COPY app /app/app

EXPOSE 8080
USER appuser

CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8080"]
