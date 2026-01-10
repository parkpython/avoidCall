# 1. 파이썬 3.10 버전으로 시작
FROM python:3.10-slim

# 2. 작업 폴더 설정
WORKDIR /app

# 3. 필요한 파일들 복사 (backend 폴더에서 가져오기)
# (이 부분이 핵심입니다! backend 폴더 안의 내용물을 꺼내옵니다)
COPY backend/requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# 4. 나머지 코드 복사
COPY backend/ .

# 5. 실행 명령어 (환경변수 PORT 사용)
CMD ["sh", "-c", "uvicorn main:app --host 0.0.0.0 --port ${PORT:-8000}"]