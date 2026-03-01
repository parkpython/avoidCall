FROM python:3.10-slim

WORKDIR /app

COPY backend/requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY backend/ .

# 👇 여기가 핵심입니다! (대괄호 없이 이렇게 적어야 $PORT가 숫자로 바뀝니다)
ENV PORT=8000
CMD uvicorn main:app --host 0.0.0.0 --port $PORT