# frozen_string_literal: true

# Trust an SSL-terminating reverse proxy in front of Puma.
#
# Activates ONLY when RAILS_ASSUME_SSL=true is set in the process environment.
# In real production (k8s + NGINX ingress) the env var is unset, so this file
# is a strict no-op. Currently the env var is set only by
# .devcontainer/docker-compose.codespaces.yml.
#
# Why this exists:
# Some reverse proxies (notably GitHub Codespaces port forwarding) terminate
# SSL at the edge but DO NOT forward the X-Forwarded-Proto: https header that
# Rack uses to derive request.scheme. Without intervention, Puma sees scheme
# = "http" while the browser sends Origin: https://..., which fails Rails'
# CSRF Origin guard with HTTP 422 on every POST (login, cookie consent, any
# form submission).
#
# K8s + NGINX ingress is unaffected because the standard ingress config sets
# `proxy_set_header X-Forwarded-Proto $scheme;` automatically, and Rack reads
# that header by default in Rack::Request#scheme.
#
# Rails 7.1 added `config.assume_ssl = true` for exactly this case; this app
# is pinned to Rails 7.0.8.4 where that setting is a silent no-op, so we
# implement the equivalent as a tiny middleware inserted at the top of the
# stack. The middleware is an anonymous class (assigned to a local variable,
# not a top-level constant) to satisfy rubocop's Lint/ConstantDefinitionInBlock.
#
# Filename prefix `zz_` keeps this initializer at the end of the alphabetical
# load order, after every other initializer — middleware ordering doesn't
# strictly require this, but it makes the inserted-before-everything intent
# explicit.

if ENV['RAILS_ASSUME_SSL'] == 'true'
  assume_ssl_proxy_middleware = Class.new do
    def initialize(app)
      @app = app
    end

    def call(env)
      env['HTTPS'] = 'on'
      env['rack.url_scheme'] = 'https'
      env['HTTP_X_FORWARDED_PROTO'] = 'https'
      @app.call(env)
    end

    def self.name
      'AssumeSslProxyMiddleware'
    end
  end

  Rails.application.config.middleware.insert_before 0, assume_ssl_proxy_middleware
end
