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

  test "should get index" do
    get :index
    assert_response :success
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

  # test 'should get edit for event owner' do
  #
  # end
  #
  # test 'should get edit for admin' do
  #
  # end
  #
  #
  # test 'should not get edit page for non-owner user' do
  #
  # end
  #
  # # CREATE TEST
  # test 'should create event for user' do
  #
  # end
  # test 'should create event for admin' do
  #
  # end
  #
  # test 'should not create event for non-logged in user' do
  #
  # end
  #
  #
  #
  # test "should create course with valid params" do
  # end
  #
  # test "should not create course with invalid params" do
  # end
  #
  # # SHOW TEST
  # test 'should show course' do
  #
  # end
  #
  # test 'should show event as json' do
  #
  # end
  #
  # test 'should show event as json-api' do
  #
  # end
  #
  # # UPDATE TEST
  # test 'should update event' do
  #
  # end
  #
  # test 'should not update event if not owner' do
  #
  # end
  #
  # test 'should update event if admin' do
  #
  # end
  #
  # # DESTROY TESTS
  # test 'should destroy event owned by user' do
  #
  # end
  #
  # test 'should destroy event when administrator' do
  #
  # end
  #
  # test 'should not destroy event not owned by user' do
  #
  # end
  #
  # # CONTENT TESTS
  # # BREADCRUMBS
  # test 'breadcrumbs for events index' do
  #
  # end
  #
  # test 'breadcrumbs for showing event' do
  #
  # end
  #
  # test 'breadcrumbs for editing event' do
  #
  # end
  # test 'breadcrumbs for creating new event' do
  #
  # end
  #
  # test 'do not show action buttons when not owner or admin' do
  #
  # end
  # test 'should show action buttons when owner' do
  #
  # end
  #
  # test 'should show action buttons when admin' do
  #
  # end
  #
  # test 'should find existing event by title, content provider and date' do
  #
  # end
  #
  # test 'should find existing event by url' do
  #
  # end
  # test 'should return nothing when event does not exist' do
  #
  # end
  #
  # test 'should redirect to event URL' do
  #
  # end
  #
  # test 'should count index results' do
  #
  # end
  #
  # test "should return existing course from check_exists by URL" do
  # end
  #
  # test "should return 200 for non-existent course in check_exists" do
  # end

  #todo: add reporting test cases and feature

end
