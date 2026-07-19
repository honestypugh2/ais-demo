# syntax=docker/dockerfile:1
# ---- Build stage: install dependencies with uv -----------------------------
FROM python:3.11-slim AS build

# Install uv (fast, reproducible dependency management).
COPY --from=ghcr.io/astral-sh/uv:latest /uv /uvx /bin/

ENV UV_COMPILE_BYTECODE=1 \
    UV_LINK_MODE=copy \
    UV_PYTHON_DOWNLOADS=never

WORKDIR /app

# Install dependencies first (better layer caching).
COPY pyproject.toml uv.lock* ./
RUN --mount=type=cache,target=/root/.cache/uv \
    uv sync --frozen --no-install-project --no-dev || uv sync --no-install-project --no-dev

# Copy the application source and install the project.
COPY src ./src
COPY README.md ./
RUN --mount=type=cache,target=/root/.cache/uv \
    uv sync --frozen --no-dev || uv sync --no-dev

# ---- Runtime stage ---------------------------------------------------------
FROM python:3.11-slim AS runtime

# Create a non-root user.
RUN useradd --create-home --uid 10001 appuser
WORKDIR /app

COPY --from=build --chown=appuser:appuser /app /app
ENV PATH="/app/.venv/bin:$PATH" \
    PYTHONUNBUFFERED=1 \
    PORT=8000

USER appuser
EXPOSE 8000

CMD ["uvicorn", "ais_demo.api.main:app", "--host", "0.0.0.0", "--port", "8000"]
