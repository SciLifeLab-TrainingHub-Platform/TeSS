require 'test_helper'

class ContentProviderTest < ActiveSupport::TestCase
  setup do
    mock_images
  end

  test 'should not save invalid content provider' do
    content_provider = ContentProvider.new
    assert content_provider.invalid?
    assert content_provider.errors[:title].any?
    assert content_provider.errors[:url].any?
  end

  test 'should allow empty image_url' do
    content_provider = content_providers(:provider_with_empty_image_url)
    assert content_provider.valid?
  end

  test 'should not allow invalid image_url' do
    content_provider = content_providers(:provider_with_invalid_image_url)
    assert content_provider.invalid?
    assert content_provider.errors[:image_url].any?
  end

  test 'should have node' do
    content_provider = content_providers(:goblet)
    assert content_provider.node == nodes(:good)
  end

  test 'should have contact' do
    assert !content_providers(:no_contact_provider).nil?
    assert content_providers(:no_contact_provider).contact.nil?

    assert !content_providers(:empty_contact_provider).nil?
    assert !content_providers(:empty_contact_provider).contact.nil?
    assert content_providers(:empty_contact_provider).contact.blank?

    assert !content_providers(:bare_email_contact_provider).nil?
    assert !content_providers(:bare_email_contact_provider).contact.nil?
    assert_equal 'user@provider.com',
                 content_providers(:bare_email_contact_provider).contact

    assert !content_providers(:name_and_email_contact_provider).nil?
    assert !content_providers(:name_and_email_contact_provider).contact.nil?
    assert_equal 'Jim (jim@provider.com)',
                 content_providers(:name_and_email_contact_provider).contact
  end

  test 'should strip attributes' do
    mock_images
    WebMock.stub_request(:any, 'http://website.com').to_return(status: 200, body: 'hi')
    content_provider = content_providers(:goblet)
    assert content_provider.update(title: ' Provider  Title  ',
                                   url: "\t  \t  http://website.com ",
                                   image_url: " http://image.host/another_image.png\n")
    assert_equal 'Provider  Title', content_provider.title
    assert_equal 'http://website.com', content_provider.url
    assert_equal 'http://image.host/another_image.png', content_provider.image_url
  end

  test 'should correctly destroy associated items when destroyed' do
    content_provider = content_providers(:goblet)
    material = materials(:material_with_external_resource)
    event = events(:event_with_external_resource)
    learning_path = learning_paths(:one)
    learning_path.update!(content_provider: content_provider)
    source = sources(:first_source)
    source.update!(content_provider: content_provider)

    material_count = content_provider.materials.count
    event_count = content_provider.events.count
    learning_path_count = content_provider.learning_paths.count
    source_count = content_provider.sources.count

    assert_difference('Material.count', -material_count) do
      assert_difference('Event.count', -event_count) do
        assert_difference('LearningPath.count', -learning_path_count) do
          assert_difference('Source.count', -source_count) do
            content_provider.destroy!
          end
        end
      end
    end

    assert_nil Material.find_by_id(material.id)
    assert_nil Event.find_by_id(event.id)
    assert_nil LearningPath.find_by_id(learning_path.id)
    assert_nil Source.find_by_id(source.id)
  end

  test 'should be valid with a proper approval_notification_email' do
    content_provider = content_providers(:approval_notification_email_contact_provider)
    assert content_provider.valid?, 'ContentProvider with valid approval_notification_email should be valid'
  end

  test 'should be valid without approval_notification_email' do
    content_provider = content_providers(:no_approval_notification_email_contact_provider)
    assert content_provider.valid?, 'ContentProvider without approval_notification_email should still be valid'
  end

  test 'should be valid with empty approval_notification_email' do
    content_provider = content_providers(:empty_approval_notification_email_contact_provider)
    assert content_provider.valid?, 'ContentProvider with empty approval_notification_email should be valid'
  end

  test 'should be invalid with malformed approval_notification_email' do
    content_provider = ContentProvider.new(
      title: 'Content Provider with invalid approval_notification_email',
      url: 'http://example.com',
      user: users(:regular_user),
      contact: 'user@provider.com',
      approval_notification_email: 'not-an-email'
    )
    assert_not content_provider.valid?, 'ContentProvider with invalid approval_notification_email should not be valid'
    assert_includes content_provider.errors[:approval_notification_email], 'is invalid'
  end
end
