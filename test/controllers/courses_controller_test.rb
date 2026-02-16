require "test_helper"

class CoursesControllerTest < ActionController::TestCase
  include Devise::Test::ControllerHelpers

  setup do
    @user = users(:regular_user)
    @node = nodes(:westeros)
    @content_providers = content_providers(:goblet)

    @mandatory = {
      title: "Test Course",
      description: "A test description",
      language: "en",
      keywords: %w[test ruby],
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

  test "should get index" do
    get :index
    assert_response :success
  end

  test 'courses index cards render as stretched links' do
    get :index
    assert_response :success
    assert_select 'ul.masonry.media-grid', count: 1
    assert_select 'ul.course-cards', count: 0
    assert_select 'ul.masonry.media-grid > ul', count: 0
    assert_select '.course-card', minimum: 1
    assert_select 'a.course-card__stretched-link', minimum: 1
    assert_select '.course-card__title-text', minimum: 1
  end

  test 'courses index shows next instance link when upcoming event exists' do
    course = courses(:one)
    course.update_column(:course_status, Course.course_statuses[:approved])
    template_event = events(:one)
    future_start = Time.zone.now + 1.year

    future_event = Event.create!(
      title: 'Future course instance',
      url: 'https://example.com/future-course-instance',
      user: users(:regular_user),
      course: course,
      start: future_start,
      end: future_start + 1.day,
      timezone: template_event.timezone,
      contact: template_event.contact,
      eligibility: template_event.eligibility,
      host_institutions: template_event.host_institutions,
      nodes: template_event.nodes,
      language: template_event.language,
      prerequisites: template_event.prerequisites,
      target_audience: template_event.target_audience,
      content_providers: template_event.content_providers,
      cost_basis: template_event.cost_basis,
      learning_objectives: template_event.learning_objectives,
      event_status: 'approved'
    )

    get :index
    assert_response :success
    assert_select "a.course-next-instance-link[href='#{event_path(future_event)}']", count: 1
  end

  test 'should get index with solr enabled' do
    with_settings(solr_enabled: true) do
      Course.stub(:search_and_filter, MockSearch.new(Course.all)) do
        get :index, params: { q: 'nightclub', keywords: 'ragtime' }
        assert_response :success
        assert_not_empty assigns(:courses)
      end
    end
  end

  test 'should get index as json' do
    parameters = @mandatory.merge(
      {
        nodes: [@node],
        content_providers: [@content_providers],
        user: @user
      })
    course = Course.create!(parameters)

    get :index, params: { format: :json }
    json_response = JSON.parse(response.body)

    assert_response :success

    assert_not_nil assigns(:courses)

    # List of expected fields in each course
    expected_fields = %w[
    id title description language keywords authors contributors url
    learning_outcomes structure_and_duration target_audience
    prerequisites_knowledge prerequisites_technical licence slug
    nodes events content_providers
  ]

    # Check each course in the response
    json_response.each do |course_json|
      expected_fields.each do |field|
        assert course_json.key?(field), "Expected course to have field '#{field}'"
      end

      # check nested arrays
      assert_kind_of Array, course_json['keywords'], 'Keywords should be an array'
      assert_kind_of Array, course_json['authors'], 'Authors should be an array'
      assert_kind_of Array, course_json['contributors'], 'Contributors should be an array'
      assert_kind_of Array, course_json['nodes'], 'Nodes should be an array'
      assert_kind_of Array, course_json['events'], 'Events should be an array'
      assert_kind_of Array, course_json['content_providers'], 'Content providers should be an array'
    end
  end

  test 'should get new' do
    sign_in @user
    get :new
    assert_response :success
    assert_select "label[for='course_event_ids']", text: 'Event(s)'
    assert_select 'span.help-block.small', text: 'Select any potential upcoming instances of your course'
  end

  test 'should get new page for logged in users only' do
    get :new
    assert_response :redirect
    sign_in @user
    get :new
    assert_response :success
    sign_in users(:admin)
    get :new
    assert_response :success
  end

  test 'should not get new page for basic users' do
    sign_in users(:basic_user)
    get :new
    assert_response :forbidden
  end

  # EDIT TESTS
  test 'should not get edit page for not logged in users' do

    parameters = @mandatory.merge(
      {
        nodes: [@node],
        content_providers: [@content_providers],
        user: @user
      })
    course = Course.create!(parameters)

    get :edit, params: { id: course }
    assert_redirected_to new_user_session_path
  end

  test 'should get edit for course owner' do

    parameters = @mandatory.merge(
      {
        nodes: [@node],
        content_providers: [@content_providers],
        user: @user
      })
    course = Course.create!(parameters)

    sign_in course.user
    get :edit, params: { id: course }
    assert_response :success
  end

  test 'should get edit for admin' do
    parameters = @mandatory.merge(
      {
        nodes: [@node],
        content_providers: [@content_providers],
        user: @user
      })
    course = Course.create!(parameters)
    sign_in users(:admin)
    get :edit, params: { id: course }
    assert_response :success
  end

  test 'should not get edit page for non-owner user' do
    parameters = @mandatory.merge(
      {
        nodes: [@node],
        content_providers: [@content_providers],
        user: @user
      })
    course = Course.create!(parameters)
    course.update_column(:course_status, Course.course_statuses[:approved])
    sign_in users(:another_regular_user)
    get :edit, params: { id: course }
    assert_response :forbidden
  end

  # CREATE TEST
  test 'should create course for user' do
    sign_in users(:regular_user)
    assert_difference('Course.count') do
      # Create event with all mandatory fields
      parameters = @mandatory.merge(
        {
          node_ids: [@node.id],
          content_provider_ids: [@content_providers.id],
        }
      )
      post :create, params: { course: parameters }
    end
  end

  test 'regular user create stores selected events as pending and does not link them' do
    sign_in users(:regular_user)

    approved_event = events(:one)
    approved_event.update_column(:event_status, Event.event_statuses[:approved]) unless approved_event.approved?
    assert_nil approved_event.course_id

    parameters = @mandatory.merge(
      node_ids: [@node.id],
      content_provider_ids: [@content_providers.id],
      event_ids: [approved_event.id]
    )

    assert_difference('Course.count', 1) do
      assert_difference('CoursePendingEvent.count', 1) do
        post :create, params: { course: parameters }
      end
    end

    course = assigns(:course)
    assert_redirected_to course_path(course)
    assert_equal 'awaiting_review', course.course_status
    assert_empty course.event_ids
    assert CoursePendingEvent.exists?(course_id: course.id, event_id: approved_event.id)
    assert_nil approved_event.reload.course_id
  end

  test 'regular user can update pending event selection on unapproved course' do
    sign_in users(:regular_user)

    first_event = events(:one)
    second_event = events(:two)

    parameters = @mandatory.merge(
      node_ids: [@node.id],
      content_provider_ids: [@content_providers.id],
      event_ids: [first_event.id]
    )
    post :create, params: { course: parameters }
    course = assigns(:course)

    assert_equal [first_event.id], course.course_pending_events.pluck(:event_id).sort

    patch :update, params: { id: course.id, course: { event_ids: [second_event.id] } }

    assert_redirected_to course_path(course)
    assert_equal [second_event.id], course.reload.course_pending_events.pluck(:event_id).sort
    assert_empty course.event_ids
    assert_nil first_event.reload.course_id
    assert_nil second_event.reload.course_id
  end

  test 'regular user cannot select an event that is already pending for another course' do
    sign_in users(:regular_user)

    event = events(:one)
    existing_course = Course.create!(
      @mandatory.merge(
        node_ids: [@node.id],
        content_provider_ids: [@content_providers.id],
        user: users(:regular_user)
      )
    )
    CoursePendingEvent.create!(course: existing_course, event: event)

    parameters = @mandatory.merge(
      title: 'Another course',
      node_ids: [@node.id],
      content_provider_ids: [@content_providers.id],
      event_ids: [event.id]
    )

    assert_no_difference('Course.count') do
      post :create, params: { course: parameters }
    end

    assert_response :success
    assert_template :new
  end

  test 'regular user cannot select an unapproved event' do
    sign_in users(:regular_user)

    unapproved_event = events(:one)
    unapproved_event.update_column(:event_status, Event.event_statuses[:awaiting_review])
    refute unapproved_event.approved?

    parameters = @mandatory.merge(
      title: 'Unapproved event selection course',
      node_ids: [@node.id],
      content_provider_ids: [@content_providers.id],
      event_ids: [unapproved_event.id]
    )

    assert_no_difference('Course.count') do
      post :create, params: { course: parameters }
    end

    assert_response :success
    assert_template :new
  end

  test 'regular user cannot select an event already linked to another course' do
    sign_in users(:regular_user)

    linked_course = Course.create!(
      @mandatory.merge(
        title: 'Linked course',
        node_ids: [@node.id],
        content_provider_ids: [@content_providers.id],
        user: users(:regular_user)
      )
    )
    linked_course.update_column(:course_status, Course.course_statuses[:approved])

    linked_event = events(:one)
    linked_event.update!(course: linked_course)
    assert_not_nil linked_event.course_id

    parameters = @mandatory.merge(
      title: 'Already linked event selection course',
      node_ids: [@node.id],
      content_provider_ids: [@content_providers.id],
      event_ids: [linked_event.id]
    )

    assert_no_difference('Course.count') do
      post :create, params: { course: parameters }
    end

    assert_response :success
    assert_template :new
  end

  test 'regular user cannot select an event they do not manage' do
    sign_in users(:regular_user)

    template_event = events(:one)
    other_users_provider = ContentProvider.create!(
      title: 'Other users provider',
      url: 'https://example.com/other-users-provider',
      user: users(:another_regular_user)
    )
    other_users_event = Event.create!(
      title: 'Other user event',
      url: 'https://example.com/other-user-event',
      user: users(:another_regular_user),
      start: template_event.start,
      end: template_event.end,
      timezone: template_event.timezone,
      contact: template_event.contact,
      eligibility: template_event.eligibility,
      host_institutions: template_event.host_institutions,
      nodes: template_event.nodes,
      language: template_event.language,
      prerequisites: template_event.prerequisites,
      target_audience: template_event.target_audience,
      content_providers: [other_users_provider],
      cost_basis: template_event.cost_basis,
      learning_objectives: template_event.learning_objectives,
      event_status: 'approved'
    )
    refute EventPolicy.new(Pundit::CurrentContext.new(users(:regular_user), nil), other_users_event).manage?

    parameters = @mandatory.merge(
      title: 'Unauthorized event selection course',
      node_ids: [@node.id],
      content_provider_ids: [@content_providers.id],
      event_ids: [other_users_event.id]
    )

    assert_no_difference('Course.count') do
      post :create, params: { course: parameters }
    end

    assert_response :success
    assert_template :new
  end

  test 'should create course for admin' do
    sign_in users(:admin)
    assert_difference('Course.count') do
      # Create event with all mandatory fields
      parameters = @mandatory.merge(
        {
          node_ids: [@node.id],
          content_provider_ids: [@content_providers.id],
        }
      )
      post :create, params: { course: parameters }
    end
    assert_redirected_to course_path(assigns(:course))
  end

  test 'invalid create re-renders new and preserves content provider selection' do
    sign_in users(:admin)

    assert_no_difference('Course.count') do
      approved_event = events(:one)
      approved_event.update_column(:event_status, Event.event_statuses[:approved]) unless approved_event.approved?

      parameters = @mandatory.merge(
        {
          title: '',
          node_ids: [@node.id],
          content_provider_ids: [@content_providers.id],
          event_ids: [approved_event.id]
        }
      )
      post :create, params: { course: parameters }
    end

    assert_response :success
    assert_template :new
    assert_select "select#course_content_provider_ids option[value='#{@content_providers.id}'][selected='selected']", count: 1
    assert_select "select#course_event_ids option[value='#{events(:one).id}'][selected='selected']", count: 1
  end

  test 'should not create course for non-logged in user' do
    assert_no_difference('Course.count') do
      # Create event with all mandatory fields
      parameters = @mandatory.merge(
        {
          node_ids: [@node.id],
          content_provider_ids: [@content_providers.id],
        }
      )
      post :create, params: { course: parameters }
    end
    assert_redirected_to new_user_session_path
  end

  test 'invalid update re-renders edit and preserves content provider selection' do
    parameters = @mandatory.merge(
      {
        nodes: [@node],
        content_providers: [@content_providers],
        user: @user
      }
    )
    course = Course.create!(parameters)

    sign_in course.user
    approved_event = events(:one)
    approved_event.update_column(:event_status, Event.event_statuses[:approved]) unless approved_event.approved?
    patch :update, params: { id: course.id, course: { title: '', event_ids: [approved_event.id] } }

    assert_response :success
    assert_template :edit
    assert_select "select#course_content_provider_ids option[value='#{@content_providers.id}'][selected='selected']", count: 1
    assert_select "select#course_event_ids option[value='#{approved_event.id}'][selected='selected']", count: 1
  end

  test 'unapproved update without event_ids preserves pending claims and keeps selection visible on failure' do
    sign_in users(:regular_user)

    pending_event = events(:one)

    post :create, params: { course: @mandatory.merge(
      node_ids: [@node.id],
      content_provider_ids: [@content_providers.id],
      event_ids: [pending_event.id]
    ) }
    course = assigns(:course)
    assert CoursePendingEvent.exists?(course_id: course.id, event_id: pending_event.id)

    patch :update, params: { id: course.id, course: { title: '' } }

    assert_response :success
    assert_template :edit
    assert CoursePendingEvent.exists?(course_id: course.id, event_id: pending_event.id)
    assert_select "select#course_event_ids option[value='#{pending_event.id}'][selected='selected']", count: 1
  end

  test 'unapproved update without event_ids preserves pending claims on success' do
    sign_in users(:regular_user)

    pending_event = events(:one)

    post :create, params: { course: @mandatory.merge(
      node_ids: [@node.id],
      content_provider_ids: [@content_providers.id],
      event_ids: [pending_event.id]
    ) }
    course = assigns(:course)
    assert CoursePendingEvent.exists?(course_id: course.id, event_id: pending_event.id)

    patch :update, params: { id: course.id, course: { title: 'Updated title only' } }

    assert_response :redirect
    assert CoursePendingEvent.exists?(course_id: course.id, event_id: pending_event.id)
    assert_nil pending_event.reload.course_id
  end

  test 'unapproved update with event_ids clears pending claims when empty selection submitted' do
    sign_in users(:regular_user)

    pending_event = events(:one)

    post :create, params: { course: @mandatory.merge(
      node_ids: [@node.id],
      content_provider_ids: [@content_providers.id],
      event_ids: [pending_event.id]
    ) }
    course = assigns(:course)
    assert CoursePendingEvent.exists?(course_id: course.id, event_id: pending_event.id)

    patch :update, params: { id: course.id, course: { event_ids: [''] } }

    assert_response :redirect
    assert_not CoursePendingEvent.exists?(course_id: course.id, event_id: pending_event.id)
  end

  test 'unapproved update hard-fails when trying to unlink a legacy linked event without permission' do
    course = Course.create!(
      @mandatory.merge(
        title: 'Legacy linked event course',
        node_ids: [@node.id],
        content_provider_ids: [@content_providers.id],
        user: users(:regular_user)
      )
    )

    template_event = events(:one)
    other_users_provider = ContentProvider.create!(
      title: 'Legacy other users provider',
      url: 'https://example.com/legacy-other-users-provider',
      user: users(:another_regular_user)
    )
    legacy_event = Event.create!(
      title: 'Legacy other user event',
      url: 'https://example.com/legacy-other-user-event',
      user: users(:another_regular_user),
      start: template_event.start,
      end: template_event.end,
      timezone: template_event.timezone,
      contact: template_event.contact,
      eligibility: template_event.eligibility,
      host_institutions: template_event.host_institutions,
      nodes: template_event.nodes,
      language: template_event.language,
      prerequisites: template_event.prerequisites,
      target_audience: template_event.target_audience,
      content_providers: [other_users_provider],
      cost_basis: template_event.cost_basis,
      learning_objectives: template_event.learning_objectives,
      event_status: 'approved'
    )
    refute EventPolicy.new(Pundit::CurrentContext.new(users(:regular_user), nil), legacy_event).manage?
    legacy_event.update_column(:course_id, course.id)
    assert_equal course.id, legacy_event.reload.course_id

    sign_in users(:regular_user)
    patch :update, params: { id: course.id, course: { event_ids: [''] } }

    assert_response :success
    assert_template :edit
    assert_equal course.id, legacy_event.reload.course_id
  end

  test 'invalid update does not reset revisions_required status' do
    course = Course.create!(
      @mandatory.merge(
        title: 'Revisions required course',
        node_ids: [@node.id],
        content_provider_ids: [@content_providers.id],
        user: users(:regular_user)
      )
    )
    course.update_column(:course_status, Course.course_statuses[:revisions_required])
    assert_equal 'revisions_required', course.course_status

    sign_in users(:regular_user)
    patch :update, params: { id: course.id, course: { title: '' } }

    assert_response :success
    assert_template :edit
    assert_equal 'revisions_required', course.reload.course_status
  end

  # SHOW TEST
  test 'should show course' do
    sign_in users(:regular_user)

    # Create a course to show
    parameters = @mandatory.merge(
      {
        node_ids: [@node.id],
        content_provider_ids: [@content_providers.id]
      }
    )
    post :create, params: { course: parameters }

    course = assigns(:course) # get the course just created

    # Show the course
    get :show, params: { id: course.id }
    assert_response :success
    assert assigns(:course)
    assert_equal course.id, assigns(:course).id
  end

  test 'unapproved course does not allow creating course instances' do
    sign_in users(:regular_user)

    course = courses(:one)
    get :show, params: { id: course.id }

    assert_response :success
    assert_select 'a', text: I18n.t('courses.actions.create_instance'), count: 0
    assert_select '.help-block', text: I18n.t('courses.messages.not_approved_instance_help')
  end

  test 'approved course allows creating course instances' do
    sign_in users(:regular_user)

    course = courses(:one)
    course.update_column(:course_status, Course.course_statuses[:approved])

    get :show, params: { id: course.id }

    assert_response :success
    assert_select 'a', text: I18n.t('courses.actions.create_instance'), count: 1
  end

  test 'course edit shows existing unapproved events with status' do
    sign_in users(:regular_user)

    course = courses(:one)
    course.update_column(:course_status, Course.course_statuses[:approved])

    template_event = events(:one)
    pending_event = Event.create!(
      title: 'Pending course instance',
      url: 'https://example.com/pending-course-instance',
      user: users(:regular_user),
      course: course,
      start: template_event.start,
      end: template_event.end,
      timezone: template_event.timezone,
      contact: template_event.contact,
      eligibility: template_event.eligibility,
      host_institutions: template_event.host_institutions,
      nodes: template_event.nodes,
      language: template_event.language,
      prerequisites: template_event.prerequisites,
      target_audience: template_event.target_audience,
      content_providers: template_event.content_providers,
      cost_basis: template_event.cost_basis,
      learning_objectives: template_event.learning_objectives
    )
    assert_equal 'awaiting_review', pending_event.event_status
    assert_includes Course.find(course.id).event_ids, pending_event.id

    get :edit, params: { id: course.id }

    assert_response :success
    assert_includes assigns(:course).event_ids, pending_event.id
    assert_includes assigns(:events).map(&:id), pending_event.id
    awaiting_review_label = I18n.t('courses.event_option_status.awaiting_review')
    assert_select "#course_event_ids option[value='#{pending_event.id}']", text: /Pending course instance\s*\(#{Regexp.escape(awaiting_review_label)}\)/
  end

  test 'should show event as json' do
    sign_in users(:regular_user)

    parameters = @mandatory.merge(
      {
        node_ids: [@node.id],
        content_provider_ids: [@content_providers.id]
      }
    )

    post :create, params: { course: parameters }

    course = assigns(:course)
    assert course.persisted?, "Course was not saved: #{course.errors.full_messages.join(', ')}"

    get :show, params: { id: course.id, format: :json }
    assert_response :success

    json_response = JSON.parse(response.body)

    # List of expected fields in each course
    expected_fields = %w[
    id title description language keywords authors contributors url
    learning_outcomes structure_and_duration target_audience
    prerequisites_knowledge prerequisites_technical licence slug
    nodes events content_providers
  ]

    # If the controller returns a single course as a hash
    expected_fields.each do |field|
      assert json_response.key?(field), "Expected course to have field '#{field}'"
    end

    # Check nested arrays
    %w[keywords authors contributors nodes events content_providers].each do |array_field|
      assert_kind_of Array, json_response[array_field], "#{array_field} should be an array"
    end
  end

  # UPDATE TEST
  test 'should update course' do
    sign_in users(:regular_user)

    parameters = @mandatory.merge(
      node_ids: [@node.id],
      content_provider_ids: [@content_providers.id]
    )
    post :create, params: { course: parameters }

    course = assigns(:course)
    assert course.persisted?, "Course was not saved: #{course.errors.full_messages.join(', ')}"

    # New attributes for update
    updated_attributes = {
      title: 'Updated Course Title',
      description: 'Updated description'
    }

    patch :update, params: { id: course.id, course: updated_attributes }

    updated_course = assigns(:course)
    assert_response :redirect
    assert_redirected_to course_path(updated_course)

    # Reload from DB and check the changes
    updated_course.reload
    assert_equal 'Updated Course Title', updated_course.title
    assert_equal 'Updated description', updated_course.description
  end

  test 'should not update course if not owner' do
    sign_in users(:regular_user)
    parameters = @mandatory.merge(
      node_ids: [@node.id],
      content_provider_ids: [@content_providers.id]
    )
    post :create, params: { course: parameters }

    course = assigns(:course)
    assert course.persisted?, "Course was not saved: #{course.errors.full_messages.join(', ')}"
    course.update_column(:course_status, Course.course_statuses[:approved])

    sign_out users(:regular_user)
    sign_in users(:another_regular_user)

    updated_attributes = {
      title: 'Hacked Title',
      description: 'Hacked description'
    }
    patch :update, params: { id: course.id, course: updated_attributes }

    updated_course = assigns(:course)

    # Reload from DB and ensure attributes did NOT change
    updated_course.reload
    assert_not_equal 'Hacked Title', updated_course.title
    assert_not_equal 'Hacked description', updated_course.description

    assert_response :forbidden
  end


  test 'should update course if admin' do
    sign_in users(:regular_user)
    parameters = @mandatory.merge(
      node_ids: [@node.id],
      content_provider_ids: [@content_providers.id]
    )
    post :create, params: { course: parameters }

    course = assigns(:course)
    assert course.persisted?, "Course was not saved: #{course.errors.full_messages.join(', ')}"

    sign_out users(:regular_user)
    sign_in users(:admin)

    updated_attributes = {
      title: 'Updated Course Title',
      description: 'Updated description'
    }
    patch :update, params: { id: course.id, course: updated_attributes }

    updated_course = assigns(:course)

    updated_course.reload
    assert_equal 'Updated Course Title', updated_course.title
    assert_equal 'Updated description', updated_course.description

    assert_redirected_to course_path(updated_course)
  end

  # DESTROY TESTS
  test 'should destroy course owned by user' do
    sign_in users(:regular_user)

    parameters = @mandatory.merge(
      node_ids: [@node.id],
      content_provider_ids: [@content_providers.id]
    )
    post :create, params: { course: parameters }

    course = assigns(:course)
    assert course.persisted?, "Course was not saved: #{course.errors.full_messages.join(', ')}"

    assert_difference('Course.count', -1) do
      delete :destroy, params: { id: course.id }
    end
    assert_redirected_to courses_path

  end

  test 'should destroy course when administrator' do
    sign_in users(:regular_user)

    parameters = @mandatory.merge(
      node_ids: [@node.id],
      content_provider_ids: [@content_providers.id]
    )
    post :create, params: { course: parameters }

    course = assigns(:course)
    assert course.persisted?, "Course was not saved: #{course.errors.full_messages.join(', ')}"

    sign_out users(:regular_user)
    sign_in users(:admin)

    assert_difference('Course.count', -1) do
      delete :destroy, params: { id: course.id }
    end
    assert_redirected_to courses_path
  end

  test 'should not destroy course not owned by user' do
    sign_in users(:regular_user)

    parameters = @mandatory.merge(
      node_ids: [@node.id],
      content_provider_ids: [@content_providers.id]
    )
    post :create, params: { course: parameters }

    course = assigns(:course)
    assert course.persisted?, "Course was not saved: #{course.errors.full_messages.join(', ')}"

    sign_out users(:regular_user)
    sign_in users(:another_regular_user)

    assert_difference('Course.count', 0) do
      delete :destroy, params: { id: course.id }
    end
    assert_response :forbidden
  end

  # CONTENT TESTS
  # BREADCRUMBS
  test 'breadcrumbs for course index' do
    get :index
    assert_response :success
    assert_select 'div.breadcrumbs', text: /Home/, count: 1 do
      assert_select 'a[href=?]', root_path, count: 1
      assert_select 'li[class=active]', text: /Courses/, count: 1
    end
  end

  test 'breadcrumbs for showing course' do
    sign_in users(:regular_user)
    parameters = @mandatory.merge(
      {
        node_ids: [@node.id],
        content_provider_ids: [@content_providers.id]
      }
    )
    post :create, params: { course: parameters }
    course = assigns(:course)

    # Show the course
    get :show, params: { id: course }

    assert_response :success
    assert assigns(:course)
    course = assigns(:course)

    assert_select 'div.breadcrumbs' do
      assert_select 'li > a[href$="/"] > span', text: /Home/, count: 1
      assert_select 'li > a[href$="/courses"] > span', text: /Courses/, count: 1
      assert_select 'li.active', text: /#{course.title}/, count: 1
    end
  end

  test 'breadcrumbs for editing course' do
    sign_in users(:regular_user)
    parameters = @mandatory.merge(
      {
        node_ids: [@node.id],
        content_provider_ids: [@content_providers.id]
      }
    )
    post :create, params: { course: parameters }
    course = assigns(:course)

    # Show the course
    get :edit, params: { id: course }

    assert_response :success
    assert_select 'div.breadcrumbs', text: /Home/, count: 1 do
      assert_select 'a[href=?]', root_path, count: 1
      assert_select 'li', text: /Courses/, count: 1 do
        assert_select 'a[href=?]', courses_url, count: 1
      end
      assert_select 'li', text: /#{course.title}/, count: 1 do
        assert_select 'a[href=?]', course_url(course), count: 1
      end
      assert_select 'li[class=active]', text: /Edit/, count: 1
    end

  end

  test 'breadcrumbs for creating new event' do
    sign_in users(:regular_user)
    get :new
    assert_response :success
    assert_select 'div.breadcrumbs', text: /Home/, count: 1 do
      assert_select 'a[href=?]', root_path, count: 1
      assert_select 'li', text: /Courses/, count: 1 do
        assert_select 'a[href=?]', courses_url, count: 1
      end
      assert_select 'li[class=active]', text: /New/, count: 1
    end
  end

  # Action Buttons

  test 'do not show action buttons when not owner or admin' do
    sign_in users(:regular_user)
    parameters = @mandatory.merge(
      {
        node_ids: [@node.id],
        content_provider_ids: [@content_providers.id]
      }
    )
    post :create, params: { course: parameters }
    course = assigns(:course)
    course.update_column(:course_status, Course.course_statuses[:approved])

    sign_out users(:regular_user)
    sign_in users(:another_regular_user)

    # Show the course
    get :show, params: { id: course }

    assert_select 'a.btn[href=?]', edit_course_path(course), count: 0 # No Edit
    assert_select 'a.btn[href=?]', course_path(course), count: 0 # No delete
  end

  test 'should show action buttons when owner' do
    sign_in users(:regular_user)
    parameters = @mandatory.merge(
      {
        node_ids: [@node.id],
        content_provider_ids: [@content_providers.id]
      }
    )
    post :create, params: { course: parameters }
    course = assigns(:course)

    # Show the course
    get :show, params: { id: course }
    assert_select 'a.btn[href=?]', edit_course_path(course), count: 1
    assert_select 'a.btn[href=?]', course_path(course), text: 'Delete', count: 1
  end

  test 'should show action buttons when admin' do
    sign_in users(:regular_user)
    parameters = @mandatory.merge(
      {
        node_ids: [@node.id],
        content_provider_ids: [@content_providers.id]
      }
    )
    post :create, params: { course: parameters }
    course = assigns(:course)

    sign_out users(:regular_user)
    sign_in users(:admin)

    # Show the course
    get :show, params: { id: course }
    assert_select 'a.btn[href=?]', edit_course_path(course), count: 1
    assert_select 'a.btn[href=?]', course_path(course), text: 'Delete', count: 1
  end

  test 'should find existing course by title and content provider' do
    provider1 = content_providers(:a_content_provider)
    provider2 = content_providers(:another_content_provider)
    title = 'Provider Aware Course'

    course1 = Course.create!(@mandatory.merge(
                               title: title,
                               url: 'https://example.com/provider-aware-course-1',
                               nodes: [@node],
                               content_providers: [provider1],
                               user: @user
                             ))
    course2 = Course.create!(@mandatory.merge(
                               title: title,
                               url: 'https://example.com/provider-aware-course-2',
                               nodes: [@node],
                               content_providers: [provider2],
                               user: @user
                             ))

    post :check_exists, params: { format: :json, course: { title: title, content_provider_id: provider1.id } }
    assert_response :success
    assert_equal course1.id, JSON.parse(response.body)['id']

    post :check_exists, params: { format: :json, course: { title: title, content_provider_id: provider2.id } }
    assert_response :success
    assert_equal course2.id, JSON.parse(response.body)['id']
  end

  test 'should find existing course by url' do
    sign_in users(:regular_user)
    parameters = @mandatory.merge(
      {
        node_ids: [@node.id],
        content_provider_ids: [@content_providers.id]
      }
    )
    post :create, params: { course: parameters }
    course = assigns(:course)
    sign_out users(:regular_user)

    post :check_exists, params: { format: :json, course: {url: course.url}}
    assert_response :success
    assert_equal(JSON.parse(response.body)['id'], course.id)
  end

  test 'should return nothing when course does not exist' do
    post :check_exists, params: { format: :json, course: { url: "http://no-such-site.com" } }
    assert_response :success
    assert_equal '{}', response.body
  end

  test 'should redirect when course exists (html)' do
    course = Course.create!(@mandatory.merge(
                              title: 'HTML Exists Course',
                              url: 'https://example.com/html-exists-course',
                              nodes: [@node],
                              content_providers: [@content_providers],
                              user: @user
                            ))

    post :check_exists, params: { course: { url: course.url } }
    assert_redirected_to course_path(course)
  end

  test 'should return ok when course does not exist (html)' do
    post :check_exists, params: { course: { url: 'http://no-such-site.com' } }
    assert_response :success
    assert_equal '', response.body
  end

  test 'check_exists does not disclose unverified courses to public' do
    unverified_course = Course.create!(@mandatory.merge(
                                         title: 'Hidden Unverified Course',
                                         url: 'https://example.com/hidden-unverified-course',
                                         nodes: [@node],
                                         content_providers: [@content_providers],
                                         user: users(:unverified_user)
                                       ))

    post :check_exists, params: { format: :json, course: { url: unverified_course.url } }
    assert_response :success
    assert_equal '{}', response.body
  end

  test 'check_exists returns disclosable duplicate when newest match is hidden' do
    visible_course = Course.create!(@mandatory.merge(
                                      title: 'Duplicate URL Visible Course',
                                      url: 'https://example.com/duplicate-url-course',
                                      nodes: [@node],
                                      content_providers: [@content_providers],
                                      user: users(:regular_user)
                                    ))
    hidden_course = Course.create!(@mandatory.merge(
                                     title: 'Duplicate URL Hidden Course',
                                     url: visible_course.url,
                                     nodes: [@node],
                                     content_providers: [@content_providers],
                                     user: users(:unverified_user)
                                   ))
    assert_operator hidden_course.id, :>, visible_course.id

    post :check_exists, params: { format: :json, course: { url: visible_course.url } }
    assert_response :success
    assert_equal visible_course.id, JSON.parse(response.body)['id']
  end

  test 'check_exists does not disclose shadowbanned courses to public but does to admin' do
    shadowbanned_course = Course.create!(@mandatory.merge(
                                           title: 'Hidden Shadowbanned Course',
                                           url: 'https://example.com/hidden-shadowbanned-course',
                                           nodes: [@node],
                                           content_providers: [@content_providers],
                                           user: users(:shadowbanned_user)
                                         ))

    post :check_exists, params: { format: :json, course: { url: shadowbanned_course.url } }
    assert_response :success
    assert_equal '{}', response.body

    sign_in users(:admin)
    post :check_exists, params: { format: :json, course: { url: shadowbanned_course.url } }
    assert_response :success
    assert_equal shadowbanned_course.id, JSON.parse(response.body)['id']
  end

  # todo: add reporting test cases and feature

end
