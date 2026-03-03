require "test_helper"
require 'sidekiq/testing'

class CourseTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  def setup
    @user = users(:regular_user)
    @node = nodes(:westeros)
    @content_providers = content_providers(:goblet)

    @mandatory = {
      title: "Test Course",
      description: "A test description",
      language: "en",
      keywords: ["test", "ruby"],
      authors: [{ "name" => "John Doe", "affiliation" => "Uni X", "orcid" => "0000-0001", "email" => "johndoe@example.com" }],
      contributors: [{ "name" => "Jane Doe", "affiliation" => "Uni Y", "orcid" => "0000-0002", "email" => "janedoe@example.com" }],
      url: "https://example.com/test_course",
      learning_outcomes: "Learn testing",
      structure_and_duration: "1 week",
      target_audience: ["students"],
      prerequisites_knowledge: "None",
      prerequisites_technical: "None",
      licence: "Glide",
    }
  end

  test "does not throw error when creating" do
    assert_nothing_raised do
      parameters = @mandatory.merge({
          nodes: [@node],
          content_providers: [@content_providers],
          user: @user
        })

      course = Course.create!(parameters)
      assert course.persisted?, "Course should be saved successfully"
    end
  end

  test "is invalid without mandatory fields" do
    course = Course.new
    assert_not course.valid?, "Course should be invalid without mandatory fields"

    blank_fields = [
      :title,
      :url,
      :language,
      :description,
      :structure_and_duration,
      :learning_outcomes,
      :prerequisites_knowledge,
      :prerequisites_technical,
      :target_audience,
      :content_providers,
    ]

    blank_fields.each do |field|
      assert_includes course.errors[field], "can't be blank", "#{field} should have 'can't be blank' error"
    end
    assert_includes course.errors[:licence], "must be a controlled vocabulary term"
    assert_includes course.errors[:user], "must exist", "user should have 'must exist' error"
  end


  test "is invalid without content providers" do
    params = @mandatory.merge(user: @user, nodes: [@node])
    course = Course.new(params)
    course.content_providers = []
    assert_not course.valid?
    assert_includes course.errors[:content_providers], "can't be blank"
  end

  test "attaches default node on create when nodes feature enabled" do
    original_value = TeSS::Config.feature['nodes']
    TeSS::Config.feature['nodes'] = true

    default_node = Node.create!(
      slug: Node::SCILIFE_LAB_NODE_SLUG,
      name: "SciLifeLab",
      user: @user
    )

    course = Course.create!(
      @mandatory.merge(
        content_providers: [@content_providers],
        user: @user
      )
    )

    assert_includes course.nodes, default_node
  ensure
    TeSS::Config.feature['nodes'] = original_value
  end

  test "does not attach default node when nodes feature disabled" do
    original_value = TeSS::Config.feature['nodes']
    TeSS::Config.feature['nodes'] = false

    Node.create!(
      slug: Node::SCILIFE_LAB_NODE_SLUG,
      name: "SciLifeLab",
      user: @user
    )

    course = Course.create!(
      @mandatory.merge(
        content_providers: [@content_providers],
        user: @user
      )
    )

    assert_empty course.nodes
  ensure
    TeSS::Config.feature['nodes'] = original_value
  end

  test "does not attach node if default node not found" do
    original_value = TeSS::Config.feature['nodes']
    TeSS::Config.feature['nodes'] = true

    course = Course.create!(
      @mandatory.merge(
        content_providers: [@content_providers],
        user: @user
      )
    )

    assert_empty course.nodes, "Expected no nodes to be attached because default node is missing"
  ensure
    TeSS::Config.feature['nodes'] = original_value
  end

  test "does not attach default node on update" do
    original_value = TeSS::Config.feature['nodes']
    TeSS::Config.feature['nodes'] = true

    default_node = Node.create!(
      slug: Node::SCILIFE_LAB_NODE_SLUG,
      name: "SciLifeLab",
      user: @user
    )

    course = Course.create!(
      @mandatory.merge(
        content_providers: [@content_providers],
        user: @user
      )
    )

    course.nodes.clear
    course.update!(title: "Updated title")

    assert_empty course.nodes
  ensure
    TeSS::Config.feature['nodes'] = original_value
  end

  test "is valid without nodes if nodes feature is disabled" do
    original_value = TeSS::Config.feature['nodes']
    TeSS::Config.feature['nodes'] = false

    parameters = @mandatory.merge(
      content_providers: [@content_providers],
      user: @user
    )

    course = Course.new(parameters)
    assert course.valid?
  ensure
    TeSS::Config.feature['nodes'] = original_value
  end

  test "belongs to a user" do
    parameters = @mandatory.merge(
      {
        nodes: [@node],
        content_providers: [@content_providers],
        user: @user
      })

    course = Course.new(parameters)
    assert_equal @user, course.user
  end

  test "has and belongs to many content providers" do

    parameters = @mandatory.merge(
      {
        nodes: [@node],
        content_providers: [@content_providers],
        user: @user
      })

    course = Course.create!(parameters)
    assert_includes course.content_providers, @content_providers
  end

  test "can attach approved events to an unapproved course" do
    course = Course.create!(
      @mandatory.merge(
        nodes: [@node],
        content_providers: [@content_providers],
        user: @user
      )
    )
    assert course.awaiting_review?

    event = events(:one) # approved by default
    assert event.approved?

    assert course.update(event_ids: [event.id])
    assert_equal course.id, event.reload.course_id
  end

  test "declining a course unlinks its events" do
    course = Course.create!(
      @mandatory.merge(
        nodes: [@node],
        content_providers: [@content_providers],
        user: @user
      )
    )

    event = events(:one)
    assert event.update(course: course)

    assert course.update(course_status: Course.course_statuses[:declined])
    assert_nil event.reload.course_id
  end

  test "has many events dependent nullify" do
    course = Course.create!(@mandatory.merge(user: users(:trusted_user), content_providers: [@content_providers], nodes: [@node]))
    event = events(:one)
    event.update!(course: course)
    course.destroy
    assert_nil event.reload.course_id
  end

  test 'cannot unapprove a course while it has approved instances' do
    course = Course.create!(@mandatory.merge(user: users(:trusted_user), content_providers: [@content_providers], nodes: [@node]))
    approved_event = events(:one)
    approved_event.update!(course: course)

    refute course.update(course_status: Course.course_statuses[:awaiting_review])
    assert_includes course.errors[:course_status], I18n.t('activerecord.errors.models.course.attributes.course_status.cannot_unapprove_with_approved_instances')
  end
end
