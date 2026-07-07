FROM python:3.10-slim

WORKDIR /app

COPY backend/requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY backend/ ./backend/
COPY backend/ .
COPY scripts/ ./scripts/

# Railway service-specific entrypoint can be overridden with APP_MODULE.
ENV APP_MODULE=main:app
ENV PORT=8000
RUN chmod +x ./scripts/start_service.sh ./backend/openclaw_task.sh
RUN useradd --create-home --shell /usr/sbin/nologin appuser \
    && chown -R appuser:appuser /app
USER appuser
CMD ["./scripts/start_service.sh"]
