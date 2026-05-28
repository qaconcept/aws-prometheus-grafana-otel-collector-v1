FROM python:3.9-slim
WORKDIR /app
COPY main.py .
RUN pip install opentelemetry-api opentelemetry-sdk opentelemetry-exporter-otlp-proto-grpc
CMD ["python", "main.py"]