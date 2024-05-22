class Venue < ApplicationRecord
  has_many :events_venues, dependent: :destroy
  has_many :events, through: :events_venues
end
