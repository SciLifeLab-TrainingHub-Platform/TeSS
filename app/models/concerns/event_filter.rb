# app/models/concerns/event_filter.rb
module EventFilter
  extend ActiveSupport::Concern

  # Additional filtering for events, regarding the task with the following workflow
  # https://scilifelab.atlassian.net/wiki/spaces/TI/pages/3183640604/Workflows
  # this function will execute as part of code of search_and_filter of module Searchable
  def event_filter(user)
    Proc.new do
      if user
        any_of do
          with(:user_id, user.id) if attribute_method?(:user_id)
          with(:event_status, Event.event_statuses.key(Event.event_statuses[:approved]))
        end
      else
        with(:event_status, Event.event_statuses.key(Event.event_statuses[:approved]))
      end
    end
  end
  module_function :event_filter
end