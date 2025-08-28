json.array!(@content_providers) do |content_provider|
  json.extract! content_provider, :id, :id, :title, :image_url, :description, :approval_notification_email,
                :url, :created_at, :updated_at, :contact
  json.url content_provider_url(content_provider)
end
