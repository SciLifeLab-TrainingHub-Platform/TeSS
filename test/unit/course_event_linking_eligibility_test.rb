require 'test_helper'

class CourseEventLinkingEligibilityTest < ActiveSupport::TestCase
  test 'normalize_event_ids removes blanks, zeros, and duplicates' do
    assert_equal [1, 2], CourseEventLinkingEligibility.normalize_event_ids(['', '1', '2', '2', 0, '0', nil])
  end

  test 'actor_manageable_event_ids uses policy manage? to filter ids' do
    event = events(:one)

    assert_equal [event.id], CourseEventLinkingEligibility.actor_manageable_event_ids(actor: users(:regular_user), request: nil, event_ids: [event.id])
    assert_equal [], CourseEventLinkingEligibility.actor_manageable_event_ids(actor: users(:another_regular_user), request: nil, event_ids: [event.id])
    assert_equal [event.id], CourseEventLinkingEligibility.actor_manageable_event_ids(actor: users(:curator), request: nil, event_ids: [event.id])
  end

  test 'actor_manageable_event_ids does not grant scraper_user api-only permissions for course linking' do
    event = events(:one)
    scraper = users(:scraper_user)

    api_format = Struct.new(:json?).new(true)
    api_request = Struct.new(:post?, :put?, :patch?, :format).new(true, false, false, api_format)

    assert_equal [], CourseEventLinkingEligibility.actor_manageable_event_ids(actor: scraper, request: api_request, event_ids: [event.id])
    assert_equal [], CourseEventLinkingEligibility.actor_manageable_event_ids(actor: scraper, request: nil, event_ids: [event.id])
  end

  test 'owner_can_manage_event? is request-agnostic and matches expected roles' do
    event = events(:one)

    assert CourseEventLinkingEligibility.owner_can_manage_event?(owner: users(:regular_user), event: event)
    assert_not CourseEventLinkingEligibility.owner_can_manage_event?(owner: users(:another_regular_user), event: event)
    assert CourseEventLinkingEligibility.owner_can_manage_event?(owner: users(:curator), event: event)
    assert_not CourseEventLinkingEligibility.owner_can_manage_event?(owner: users(:scraper_user), event: event)
  end

  test 'owner_manageable_event_ids filters by owner manage rules' do
    event = events(:one)

    assert_equal [event.id], CourseEventLinkingEligibility.owner_manageable_event_ids(owner: users(:regular_user), event_ids: [event.id])
    assert_equal [], CourseEventLinkingEligibility.owner_manageable_event_ids(owner: users(:another_regular_user), event_ids: [event.id])
  end

  test 'pending_claim_conflict_event_ids returns events pending for other courses' do
    event = events(:one)
    course = courses(:one)
    other_course = courses(:two)

    CoursePendingEvent.create!(course: course, event: event)

    assert_equal [event.id], CourseEventLinkingEligibility.pending_claim_conflict_event_ids(event_ids: [event.id])
    assert_equal [], CourseEventLinkingEligibility.pending_claim_conflict_event_ids(event_ids: [event.id], course_id: course.id)
    assert_equal [event.id], CourseEventLinkingEligibility.pending_claim_conflict_event_ids(event_ids: [event.id], course_id: other_course.id)
  end

  test 'lock_events_for_update returns events in deterministic id order' do
    ids = [events(:two).id, events(:one).id]
    locked = CourseEventLinkingEligibility.lock_events_for_update(ids)

    assert_equal ids.sort, locked.map(&:id)
  end
end
