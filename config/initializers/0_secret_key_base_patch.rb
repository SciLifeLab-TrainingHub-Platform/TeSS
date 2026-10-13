# frozen_string_literal: true

# Ported from upstream TeSS 841005338. `Rails.application.secrets` is deprecated from Rails 7.1,
# so read `secret_key_base` from ENV, credentials or config/secrets.yml ourselves.
# Unlike upstream, never generate and write a key at boot: k8s pods must get SECRET_KEY_BASE from ENV.
module Extensions
  module SecretKeyBase
    def secret_key_base
      @secret_key_base ||=
        # TODO: use Rails.env.local? once on Rails 7.1+
        if Rails.env.development? || Rails.env.test? || ENV['SECRET_KEY_BASE_DUMMY']
          super
        else
          ENV['SECRET_KEY_BASE'] || Rails.application.credentials.secret_key_base || secret_from_file
        end
    end

    private

    # Values containing ERB (e.g. `<%= ENV["SECRET_KEY_BASE"] %>`) are not evaluated here; ENV is checked first.
    def secret_from_file
      file = Rails.root.join('config/secrets.yml')
      secret = YAML.load(file.read, aliases: true).dig(Rails.env, 'secret_key_base') if file.exist?
      return secret if secret.present? && !secret.start_with?('<%')

      raise 'No secret key base found! Either set the SECRET_KEY_BASE environment variable, ' \
            'edit config/secrets.yml, or use Rails encrypted credentials.'
    end
  end
end

Rails::Application::Configuration.prepend Extensions::SecretKeyBase
