class ContentProviderSerializer < ApplicationSerializer
  attributes :id, :slug, :title, :description, :url, :image_url, :approval_notification_email, :keywords, :created_at, :updated_at, :contact

  has_many :events
  has_many :materials
end
