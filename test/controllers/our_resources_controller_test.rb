require 'test_helper'

class OurResourcesControllerTest < ActionController::TestCase
  include Devise::Test::ControllerHelpers

  test 'should get resources landing page' do
    get :our_resources

    assert_response :success
    assert_select 'h1', 'Where do you find yourself?'
    assert_select '.resources-lifecycle__card', count: 4
    assert_select '.resources-lifecycle__card h2', text: 'Design & Develop'
    assert_select '.resources-lifecycle__card h2', text: 'Plan'
    assert_select '.resources-lifecycle__card h2', text: 'Deliver'
    assert_select '.resources-lifecycle__card h2', text: 'Evaluate & Archive'
  end
end
