class EventsVenue < ApplicationRecord
  belongs_to :event
  belongs_to :venue
end
