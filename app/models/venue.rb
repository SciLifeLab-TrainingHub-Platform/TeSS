class Venue < ApplicationRecord
  has_many :event_venues, dependent: :destroy
  has_many :events, through: :event_venues
end
