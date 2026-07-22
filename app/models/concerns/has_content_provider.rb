module HasContentProvider
  extend ActiveSupport::Concern

  included do
    belongs_to :content_provider, optional: true
  end
end
