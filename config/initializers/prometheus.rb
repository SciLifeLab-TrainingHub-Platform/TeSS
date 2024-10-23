require 'prometheus/client'
require 'prometheus/client/formats/text'

# Create a new Prometheus registry
prometheus = Prometheus::Client.registry

# Create a gauge metric for memory usage
MEMORY_GAUGE = Prometheus::Client::Gauge.new(:memory_usage, docstring: 'Memory usage in bytes')
prometheus.register(MEMORY_GAUGE)

# Create a gauge metric for CPU usage
CPU_GAUGE = Prometheus::Client::Gauge.new(:cpu_usage, docstring: 'CPU usage in percentage')
prometheus.register(CPU_GAUGE)
