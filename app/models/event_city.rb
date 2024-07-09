class EventCity < ApplicationRecord
  belongs_to :event
  belongs_to :city
end
