# frozen_string_literal: true

# Codespaces-only escape hatch for Rails' CSRF Origin check.
#
# Rails still verifies the authenticity_token against the session cookie (the
# real CSRF protection). This ONLY disables the additional defense-in-depth
# "Origin header must equal request.base_url" check, and ONLY when
# PREVIEW_RELAX_CSRF_ORIGIN_CHECK=true is set. In real production the env var
# is unset, so this file is a strict no-op.
#
# Why this exists:
# The GitHub Codespaces port-forwarding proxy terminates HTTPS at the edge and
# forwards to the container with the Host rewritten to localhost:3000. With the
# companion zz_assume_ssl_proxy.rb forcing the scheme to https, Rails computes
# request.base_url = "https://localhost:3000", while the browser sends
# Origin: https://<codespace>-3000.app.github.dev. localhost != github.dev, so
# Rails' Origin guard rejects every POST (cookie consent, login, any form) with
# HTTP 422 before the token check even runs. The Origin check simply cannot
# pass behind a Host-rewriting proxy, so we disable it for previews only.
#
# K8s + NGINX ingress is unaffected: the env var is not set there, and the
# ingress forwards a correct Host so base_url matches Origin naturally.
#
# Do NOT set this env var in production.

if ENV['PREVIEW_RELAX_CSRF_ORIGIN_CHECK'] == 'true'
  Rails.application.config.action_controller.forgery_protection_origin_check = false

  ActiveSupport.on_load(:action_controller) do
    self.forgery_protection_origin_check = false
  end
end
