# frozen_string_literal: true

class CourseEventLinkingEligibility
  def self.normalize_event_ids(raw_ids)
    Array(raw_ids).reject(&:blank?).map(&:to_i).reject(&:zero?).uniq
  end

  def self.actor_manageable_event_ids(actor:, request:, event_ids:)
    return [] unless actor

    context = Pundit::CurrentContext.new(actor, request)
    manageable_event_ids_for_context(context: context, event_ids: event_ids)
  end

  # Approval-time check for whether the course owner is allowed to manage the event.
  # This is request-agnostic by design (no scraper_user API exception).
  def self.owner_can_manage_event?(owner:, event:)
    return false unless owner && event

    context = Pundit::CurrentContext.new(owner, nil)
    EventPolicy.new(context, event).manage?
  end

  def self.owner_manageable_event_ids(owner:, event_ids:)
    return [] unless owner

    context = Pundit::CurrentContext.new(owner, nil)
    manageable_event_ids_for_context(context: context, event_ids: event_ids)
  end

  def self.pending_claim_conflict_event_ids(event_ids:, course_id: nil)
    requested_ids = normalize_event_ids(event_ids)
    return [] if requested_ids.blank?

    scope = CoursePendingEvent.where(event_id: requested_ids)
    scope = scope.where.not(course_id: course_id) if course_id.present?
    scope.distinct.order(:event_id).pluck(:event_id)
  end

  # Locks the event rows for update in deterministic ID order.
  #
  # NOTE: FOR UPDATE is only useful if the query is executed within an open transaction.
  def self.lock_events_for_update(event_ids)
    requested_ids = normalize_event_ids(event_ids)
    return [] if requested_ids.blank?

    # Preload associations used by policies to avoid N+1 queries while evaluating manage? checks.
    Event.preload(:user, content_providers: [:user, :editors])
         .where(id: requested_ids)
         .order(:id)
         .lock('FOR UPDATE')
         .to_a
  end

  def self.manageable_event_ids_for_context(context:, event_ids:)
    return [] unless context.respond_to?(:user) && context.respond_to?(:request)

    requested_ids = normalize_event_ids(event_ids)
    return [] if requested_ids.blank?

    events_by_id = Event.includes(:user, content_providers: [:user, :editors]).where(id: requested_ids).index_by(&:id)

    requested_ids.select do |id|
      event = events_by_id[id]
      next false unless event

      EventPolicy.new(context, event).manage?
    end
  end
  private_class_method :manageable_event_ids_for_context
end
