class EventContentProvider < ApplicationRecord
  belongs_to :event
  belongs_to :content_provider
end
