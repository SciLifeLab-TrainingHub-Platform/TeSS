class City < ApplicationRecord
  has_many :event_cities, dependent: :destroy
  has_many :events, through: :event_cities

  ONLINE_CITY = 'Online'.freeze
  scope :online, -> { where(name: ONLINE_CITY) }
end
