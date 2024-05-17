class Venue < ApplicationRecord
  has_many :events_venues
  has_many :events, through: :events_venues
end
