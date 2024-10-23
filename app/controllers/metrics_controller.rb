require 'prometheus/client/formats/text'
require 'prometheus'
class MetricsController < ApplicationController
    def index
        Rails.logger.info Prometheus::Client.registry.metrics
        render plain: Prometheus::Client::Formats::Text.marshal(Prometheus::Client.registry)
        #render plain: Prometheus::Client::TextFormatter.marshal(Prometheus::Client.registry)
    end
  end
  