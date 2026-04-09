FROM python:3.12-slim

WORKDIR /app

RUN apt-get update && apt-get install -y --no-install-recommends \
    bash \
    make \
    && rm -rf /var/lib/apt/lists/*

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY core/ core/
COPY lib/ lib/
COPY missions/ missions/
COPY web/ web/

# Run as non-root
RUN useradd -m gym
USER gym

EXPOSE 8080

CMD ["python3", "web/server.py", "--host", "0.0.0.0", "--port", "8080"]
