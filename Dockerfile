# ---------- Stage 1: Builder ----------
# Use slim base to keep image small
FROM python:3.12-slim AS builder

# Avoid writing .pyc, and keep logs unbuffered
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

WORKDIR /app

# System deps (optional but common). Keep minimal.
# - build-essential: only needed if any dependency compiles native extensions.
# If you know you don't need compilation, you can remove build-essential.
RUN apt-get update && apt-get install -y --no-install-recommends \
      build-essential \
    && rm -rf /var/lib/apt/lists/*

# Copy dependency file(s) first for better caching
COPY requirements-dev.txt /app/requirements-dev.txt

# Create venv inside image and install deps
RUN python -m venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"

RUN pip install --upgrade pip wheel setuptools \
    && pip install -r /app/requirements-dev.txt

# Copy application code
COPY . /app

# Install your project package (works if pyproject.toml or setup.py exists)
RUN pip install -e .


# ---------- Stage 2: Runtime ----------
FROM python:3.12-slim AS runtime

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

# Create non-root user for security (recommended)
RUN useradd -m -u 10001 appuser

WORKDIR /app

# Copy the venv from builder stage
COPY --from=builder /opt/venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"

# Copy only the app source (optional: if you want only runtime files)
COPY --from=builder /app /app

# Switch to non-root user
USER appuser

# EXPOSE is optional (useful if this is a web service)
EXPOSE 8000

# Default command:
# If your entrypoint is app/main.py, this works.
# If your actual module is different, update accordingly.
CMD ["python", "-m", "app.main"]
