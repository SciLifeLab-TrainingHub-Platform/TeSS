class EventPrice < ApplicationRecord
  belongs_to :event

  # Default audience types
  DEFAULT_AUDIENCE_TYPES = %w[academic non-academic all others].freeze

  # validations
  validates :cost, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :currency, presence: true
  validates :audience_type, presence: true

  # callback actions
  before_save :normalize_audience_type

  private

  def normalize_audience_type
    self.audience_type = audience_type.strip.downcase if audience_type.present?
  end
end
