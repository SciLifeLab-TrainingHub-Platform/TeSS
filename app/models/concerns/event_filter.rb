# app/models/concerns/event_filter.rb
module EventFilter
  extend ActiveSupport::Concern

  # Additional filtering for events, regarding the task with the following workflow
  # https://scilifelab.atlassian.net/wiki/spaces/TI/pages/3183640604/Workflows
  # this function will execute as part of code of search_and_filter of module Searchable
  def event_filter(user)
    Proc.new do
      if user
        # If the user is an admin, include every event
        unless user.has_role?('admin')
          all_of do
            # Only include events that are not declined
            without(:event_status, Event.event_statuses.key(Event.event_statuses[:declined]))
            any_of do
              # Show events belonging to the user
              with(:user_id, user.id)
              # Or show approved events
              with(:event_status, Event.event_statuses.key(Event.event_statuses[:approved]))
            end
          end
        end
      else
        # If no user is logged in, show only approved events
        with(:event_status, Event.event_statuses.key(Event.event_statuses[:approved]))
      end
    end
  end
  module_function :event_filter
end
