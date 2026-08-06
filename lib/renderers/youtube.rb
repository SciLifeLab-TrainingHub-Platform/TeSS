require 'uri'

module Renderers
  class Youtube
    VALID_HOSTS = %w[youtube.com youtu.be m.youtube.com www.youtube.com].freeze
    VALID_SCHEMES = %w[http https].freeze
    EMBED_URL_TEMPLATE = 'https://www.youtube.com/embed/%{code}'.freeze
    TEMPLATE = %(<iframe width="560" height="315" src="#{EMBED_URL_TEMPLATE}" title="YouTube video player" frameborder="0" allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture" allowfullscreen></iframe>)

    class << self
      def extract_video_code(url)
        parsed_url = URI.parse(url)
        host = parsed_url.host.to_s.downcase
        scheme = parsed_url.scheme.to_s.downcase

        return unless VALID_HOSTS.include?(host) && VALID_SCHEMES.include?(scheme)

        match = if host == 'youtu.be'
                  parsed_url.path.match(%r{\A/([-_a-zA-Z0-9]+)})
                else
                  url.match(/[\?&]v[i]?=([-_a-zA-Z0-9]+)/) ||
                    url.match(%r{/v/([-_a-zA-Z0-9]+)}) ||
                    url.match(%r{/embed/([-_a-zA-Z0-9]+)})
                end

        match[1] if match
      rescue URI::InvalidURIError, TypeError
        nil
      end

      def embed_url(url)
        code = extract_video_code(url)
        EMBED_URL_TEMPLATE % { code: code } if code
      end
    end

    def initialize(resource)
      @resource = resource
    end

    def can_render?
      @resource.url && extract_video_code(@resource.url)
    end

    def render_content
      code = extract_video_code(@resource.url)
      (TEMPLATE % { code: code }).html_safe
    end

    def extract_video_code(url)
      self.class.extract_video_code(url)
    end
  end
end
