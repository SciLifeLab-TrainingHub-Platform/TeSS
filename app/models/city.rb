class City < ApplicationRecord
  has_many :event_cities, dependent: :destroy
  has_many :events, through: :event_cities
end
