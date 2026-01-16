require 'test_helper'

class CourseToEventPrefillerTest < ActiveSupport::TestCase
  setup do
    @node = nodes(:westeros)
    @other_node = nodes(:dorne)
    @provider1 = content_providers(:a_content_provider)
    @provider2 = content_providers(:another_content_provider)
    @user = users(:regular_user)
  end

  test 'prefills fields, providers, nodes, and reports applied fields + warnings' do
    course = Course.create!(
      title: 'Prefill Course',
      description: 'Course description',
      language: 'en',
      keywords: %w[alpha beta],
      url: 'https://example.com/prefill-course',
      learning_outcomes: 'Learning outcomes',
      structure_and_duration: '1 week',
      target_audience: ['students'],
      prerequisites_knowledge: 'Knowledge prereqs',
      prerequisites_technical: 'Tech prereqs',
      licence: 'Glide',
      authors: [],
      contributors: [],
      nodes: [@node],
      content_providers: [@provider1, @provider2],
      user: @user
    )

    event = Event.new

    @user.stub(:get_editable_providers, ContentProvider.where(id: [@provider1.id])) do
      with_settings(feature: { nodes: true }) do
        result = CourseToEventPrefiller.prefill(event, course, @user)

        assert_equal 'Prefill Course', event.title
        assert_equal 'Course description', event.description
        assert_equal 'Learning outcomes', event.learning_objectives
        assert_equal 'Knowledge prereqs', event.prerequisites
        assert_equal 'Tech prereqs', event.tech_requirements
        assert_equal %w[alpha beta], event.keywords
        assert_equal ['students'], event.target_audience
        assert_equal 'en', event.language
        assert_equal course, event.course

        assert_equal [@provider1.id], event.content_provider_ids
        assert_includes event.node_ids, @node.id

        assert_includes result.applied_fields, :course
        assert_includes result.applied_fields, :content_provider_ids
        assert_includes result.applied_fields, :node_ids
        assert_includes result.warnings, 'Content providers were limited to those you can edit.'
      end
    end
  end

  test 'does not overwrite existing fields' do
    course = Course.create!(
      title: 'Course Title',
      description: 'Course description',
      language: 'en',
      keywords: %w[alpha beta],
      url: 'https://example.com/prefill-course-existing',
      learning_outcomes: 'Learning outcomes',
      structure_and_duration: '1 week',
      target_audience: ['students'],
      prerequisites_knowledge: 'Knowledge prereqs',
      prerequisites_technical: 'Tech prereqs',
      licence: 'Glide',
      authors: [],
      contributors: [],
      nodes: [@node],
      content_providers: [@provider1],
      user: @user
    )

    event = Event.new(
      title: 'Existing title',
      keywords: ['existing'],
      target_audience: ['existing'],
      language: 'sv',
      node_ids: [@other_node.id],
      content_provider_ids: [@provider1.id]
    )

    with_settings(feature: { nodes: true }) do
      result = CourseToEventPrefiller.prefill(event, course, @user)

      assert_equal 'Existing title', event.title
      assert_equal ['existing'], event.keywords
      assert_equal ['existing'], event.target_audience
      assert_equal 'sv', event.language
      assert_equal [@other_node.id], event.node_ids
      assert_equal [@provider1.id], event.content_provider_ids

      assert_not_includes result.applied_fields, :title
      assert_not_includes result.applied_fields, :keywords
      assert_not_includes result.applied_fields, :target_audience
      assert_not_includes result.applied_fields, :language
      assert_not_includes result.applied_fields, :node_ids
      assert_not_includes result.applied_fields, :content_provider_ids
    end
  end

  test 'adds a warning when no course providers are editable' do
    course = Course.create!(
      title: 'Provider Warning Course',
      description: 'Course description',
      language: 'en',
      keywords: [],
      url: 'https://example.com/provider-warning-course',
      learning_outcomes: 'Learning outcomes',
      structure_and_duration: '1 week',
      target_audience: ['students'],
      prerequisites_knowledge: 'Knowledge prereqs',
      prerequisites_technical: 'Tech prereqs',
      licence: 'Glide',
      authors: [],
      contributors: [],
      nodes: [@node],
      content_providers: [@provider2],
      user: @user
    )

    event = Event.new

    @user.stub(:get_editable_providers, ContentProvider.where(id: [@provider1.id])) do
      result = CourseToEventPrefiller.prefill(event, course, @user)

      assert_empty event.content_provider_ids
      assert_not_includes result.applied_fields, :content_provider_ids
      assert_includes result.warnings, 'No content providers were prefilled because you cannot edit the course providers.'
    end
  end
end
