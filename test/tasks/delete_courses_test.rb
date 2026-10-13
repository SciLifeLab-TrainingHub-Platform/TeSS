# frozen_string_literal: true

require 'test_helper'
require 'rake'

class DeleteCoursesTest < ActiveSupport::TestCase
  TASK_NAME = 'delete_courses:delete_old'

  setup do
    Rails.application.load_tasks
    Rake::Task[TASK_NAME].reenable

    @user = users(:regular_user)
    @node = nodes(:westeros)
    @content_providers = content_providers(:goblet)

    @mandatory = {
      title: 'Test Course',
      description: 'A test description',
      language: 'en',
      keywords: %w[test ruby],
      authors: [
        {
          'name' => 'John Doe',
          'affiliation' => 'Uni X',
          'orcid' => '0000-0001',
          'email' => 'johndoe@example.com'
        }
      ],
      contributors: [
        {
          'name' => 'Jane Doe',
          'affiliation' => 'Uni Y',
          'orcid' => '0000-0002',
          'email' => 'janedoe@example.com'
        }
      ],
      url: 'https://example.com/test_course',
      learning_outcomes: 'Learn testing',
      structure_and_duration: '1 week',
      target_audience: ['students'],
      prerequisites_knowledge: 'None',
      prerequisites_technical: 'None',
      licence: 'Glide',
      nodes: [@node],
      content_providers: [@content_providers],
      user: @user
    }
  end

  test 'deletes declined courses updated more than 90 days ago' do
    old_course = Course.create!(
      @mandatory.merge(
        course_status: :declined,
        updated_at: 91.days.ago
      )
    )

    older_course = Course.create!(
      @mandatory.merge(
        course_status: :declined,
        updated_at: 120.days.ago
      )
    )

    assert_difference('Course.count', -2) do
      Rake::Task[TASK_NAME].invoke
    end

    assert_not Course.exists?(old_course.id)
    assert_not Course.exists?(older_course.id)
  end

  test 'preserves declined courses updated within the last 90 days' do
    recent_course = Course.create!(
      @mandatory.merge(
        course_status: :declined,
        updated_at: 30.days.ago
      )
    )

    assert_no_difference('Course.count') do
      Rake::Task[TASK_NAME].invoke
    end

    assert Course.exists?(recent_course.id)
  end

  test 'preserves courses that are not declined regardless of age' do
    awaiting_review_91_days = Course.create!(
      @mandatory.merge(
        title: 'Awaiting Review Course - 91 Days Old',
        course_status: :awaiting_review,
        updated_at: 91.days.ago
      )
    )

    awaiting_review_120_days = Course.create!(
      @mandatory.merge(
        title: 'Awaiting Review Course - 120 Days Old',
        course_status: :awaiting_review,
        updated_at: 120.days.ago
      )
    )

    awaiting_review_recent = Course.create!(
      @mandatory.merge(
        title: 'Awaiting Review Course - Recent',
        course_status: :awaiting_review,
        updated_at: 30.days.ago
      )
    )

    approved_91_days = Course.create!(
      @mandatory.merge(
        title: 'Approved Course - 91 Days Old',
        course_status: :approved,
        updated_at: 91.days.ago
      )
    )

    approved_120_days = Course.create!(
      @mandatory.merge(
        title: 'Approved Course - 120 Days Old',
        course_status: :approved,
        updated_at: 120.days.ago
      )
    )

    approved_recent = Course.create!(
      @mandatory.merge(
        title: 'Approved Course - Recent',
        course_status: :approved,
        updated_at: 30.days.ago
      )
    )

    revisions_required_91_days = Course.create!(
      @mandatory.merge(
        title: 'Revisions Required Course - 91 Days Old',
        course_status: :revisions_required,
        updated_at: 91.days.ago
      )
    )

    revisions_required_120_days = Course.create!(
      @mandatory.merge(
        title: 'Revisions Required Course - 120 Days Old',
        course_status: :revisions_required,
        updated_at: 120.days.ago
      )
    )

    revisions_required_recent = Course.create!(
      @mandatory.merge(
        title: 'Revisions Required Course - Recent',
        course_status: :revisions_required,
        updated_at: 30.days.ago
      )
    )

    assert_no_difference('Course.count') do
      Rake::Task[TASK_NAME].invoke
    end

    assert Course.exists?(awaiting_review_91_days.id)
    assert Course.exists?(awaiting_review_120_days.id)
    assert Course.exists?(awaiting_review_recent.id)

    assert Course.exists?(approved_91_days.id)
    assert Course.exists?(approved_120_days.id)
    assert Course.exists?(approved_recent.id)

    assert Course.exists?(revisions_required_91_days.id)
    assert Course.exists?(revisions_required_120_days.id)
    assert Course.exists?(revisions_required_recent.id)
  end

  test 'deletes only declined courses older than 90 days' do
    old_declined = Course.create!(
      @mandatory.merge(
        title: 'Declined Course - 91 Days Old',
        course_status: :declined,
        updated_at: 91.days.ago
      )
    )

    recent_declined = Course.create!(
      @mandatory.merge(
        title: 'Declined Course - Recent',
        course_status: :declined,
        updated_at: 30.days.ago
      )
    )

    old_approved = Course.create!(
      @mandatory.merge(
        title: 'Approved Course - 120 Days Old',
        course_status: :approved,
        updated_at: 120.days.ago
      )
    )

    assert_difference('Course.count', -1) do
      Rake::Task[TASK_NAME].invoke
    end

    assert_not Course.exists?(old_declined.id)
    assert Course.exists?(recent_declined.id)
    assert Course.exists?(old_approved.id)
  end
end
