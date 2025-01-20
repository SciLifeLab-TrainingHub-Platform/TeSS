class EventContentProvider < ApplicationRecord
  belongs_to :event
  belongs_to :content_provider

  before_destroy :destroy_event_if_orphaned

  private
  def destroy_event_if_orphaned
    event.destroy if event.event_content_providers.count == 1
  end
end
