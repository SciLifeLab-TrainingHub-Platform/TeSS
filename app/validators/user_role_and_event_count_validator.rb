# frozen_string_literal: true

class UserRoleAndEventCountValidator < ActiveModel::Validator

  def validate(record)
    # Get the changes
    changes_hash = record.changes

    # Only proceed if role_id or approved_events_count is changed
    return unless changes_hash.key?("role_id") || changes_hash.key?("approved_events_count")

    # Fetch roles by title
    trusted_user_role = Role.find_by(title: "Trusted user")
    registered_user_role = Role.find_by(title: "Registered user")

    # Determine current and new values
    current_role = record.role
    new_role_id = changes_hash.dig("role_id", 1)
    new_role = new_role_id ? Role.find(new_role_id) : current_role

    current_approved_events_count = record.approved_events_count
    new_approved_events_count = changes_hash.key?("approved_events_count") ? changes_hash.dig("approved_events_count", 1) : current_approved_events_count

    if new_role == trusted_user_role && new_approved_events_count <= User::EVENT_APPROVAL_THRESHOLD
      record.errors.add(:base, "A 'Trusted user' cannot have approved events count less than or equal to #{User::EVENT_APPROVAL_THRESHOLD}. Please change the input accordingly.")
    elsif new_role == registered_user_role && new_approved_events_count > User::EVENT_APPROVAL_THRESHOLD
      record.errors.add(:base, "A 'Registered user' cannot have approved events count more than #{User::EVENT_APPROVAL_THRESHOLD}. Please change the input accordingly.")
    end
  end
end
