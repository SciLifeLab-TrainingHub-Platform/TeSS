# The controller for actions related to home page
class StaticController < ApplicationController
  UPCOMING_TRAINING_LIMIT = 4

  skip_before_action :authenticate_user!, :authenticate_user_from_token!

  def privacy; end

  def home
    @container_class = 'homepage-container container-fluid'
    load_homepage_content
  end

  def showcase
    @container_class = 'showcase-container container-fluid'
  end

  private

  def load_homepage_content
    events = homepage_event_scope

    @featured_event = events.reorder(created_at: :desc, id: :desc).first

    events = events.where.not(id: @featured_event.id) if @featured_event
    @upcoming_training_events = events.reorder(start: :asc, id: :asc).limit(UPCOMING_TRAINING_LIMIT)
    @provider_count = ContentProvider.from_verified_users.count
  end

  def homepage_event_scope
    Event
      .from_verified_users
      .approved
      .where(visible: true)
      .where('events.end >= ?', Time.current)
      .left_outer_joins(:link_monitor)
      .where('link_monitors.id IS NULL OR link_monitors.fail_count < ?', LinkMonitor::FAILURE_THRESHOLD)
      .includes(:cities, :nodes, content_providers: :node)
  end
end
