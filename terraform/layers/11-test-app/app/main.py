import time
import random
from opentelemetry import trace
from opentelemetry.exporter.otlp.proto.grpc.trace_exporter import OTLPSpanExporter
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import BatchSpanProcessor
from opentelemetry.sdk.resources import Resource

resource = Resource(attributes={"service.name": "python-test-app"})
provider = TracerProvider(resource=resource)

# FIX: Dropping the hardcoded string lets the container automatically
# pull 'http://otel.local:4317' directly from its ECS environment layout!
processor = BatchSpanProcessor(OTLPSpanExporter())

provider.add_span_processor(processor)
trace.set_tracer_provider(provider)
tracer = trace.get_tracer(__name__)

def perform_task():
    # Adding flush=True print statements ensures your logs stream instantly to CloudWatch
    print("--> Executing span payload sequence...", flush=True)
    with tracer.start_as_current_span("parent_task"):
        time.sleep(random.uniform(0.1, 0.3))
        with tracer.start_as_current_span("child_task_db_query"):
            time.sleep(random.uniform(0.05, 0.2))
    print("<-- Span telemetry bundle successfully processed.", flush=True)

if __name__ == "__main__":
    print("Application successfully initialized. Starting event collection loop...", flush=True)
    while True:
        perform_task()
        time.sleep(5)