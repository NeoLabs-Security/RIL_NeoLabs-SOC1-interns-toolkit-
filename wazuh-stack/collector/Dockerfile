FROM python:3.13.5-alpine3.22

RUN addgroup -S collector && adduser -S -G collector -h /app collector

WORKDIR /app
COPY collector.py healthcheck.py /app/

RUN python -m compileall -q /app \
    && chown -R collector:collector /app

USER collector
ENTRYPOINT ["python", "/app/collector.py"]
