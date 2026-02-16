# frozen_string_literal: true

class CoursePendingEvent < ApplicationRecord
  belongs_to :course
  belongs_to :event

  # DB unique index on event_id is the authoritative constraint; this validation provides user-facing errors.
  validates :event_id, uniqueness: true
end
