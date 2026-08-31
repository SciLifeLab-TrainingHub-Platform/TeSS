require 'test_helper'

class RailsAdminUserFieldsTest < ActiveSupport::TestCase
  # Devise 5 declares the password length rule with procs, which made RailsAdmin
  # raise "comparison of Integer with Proc failed" while building the help text
  # for the field, breaking the whole user form under /admin.
  # See the patch in config/initializers/rails_admin.rb
  test 'password field help text renders with proc-based length validators' do
    field = RailsAdmin.config(User).edit.fields.detect { |f| f.name == :password }
    assert field, 'expected RailsAdmin to expose a password field on User'

    help = nil
    assert_nothing_raised { help = field.help }

    assert_includes help, User.password_length.min.to_s
    assert_includes help, User.password_length.max.to_s
  end

  # The password rule carries both kinds of option, so one field covers both
  # halves of the patch: procs get called, anything else is passed through.
  test 'callable length options are resolved and plain ones are left alone' do
    field = RailsAdmin.config(User).edit.fields.detect { |f| f.name == :password }
    assert field, 'expected RailsAdmin to expose a password field on User'

    assert_equal User.password_length.min, field.valid_length[:minimum]
    assert_equal User.password_length.max, field.valid_length[:maximum]
    assert_equal true, field.valid_length[:allow_blank]
  end

  # The patch has to keep the form alive even when an option cannot be resolved,
  # so a failing one is dropped rather than allowed to break the page - but it
  # has to be reported, otherwise a missing limit goes unnoticed.
  test 'a length option that cannot be resolved is dropped and logged' do
    field = RailsAdmin.config(User).edit.fields.detect { |f| f.name == :password }
    validator = ActiveModel::Validations::LengthValidator.new(attributes: [:password],
                                                              minimum: proc { raise 'cannot be resolved' },
                                                              maximum: 72)
    logged = []

    Rails.logger.stub(:error, ->(message) { logged << message }) do
      with_stubbed_validators(field, [validator]) do
        assert_nil field.valid_length[:minimum]
        assert_equal 72, field.valid_length[:maximum]
      end
    end

    assert_match(/could not resolve the :minimum length option for User#password/, logged.join("\n"))
    assert_match(/cannot be resolved/, logged.join("\n"))
  end

  private

  # The field caches the options it resolved, so clear that cache around the
  # stub to leave the shared RailsAdmin config untouched for the other tests.
  def with_stubbed_validators(field, validators, &block)
    field.instance_variable_set(:@valid_length, nil)
    User.stub(:validators_on, validators, &block)
  ensure
    field.instance_variable_set(:@valid_length, nil)
    field.instance_variable_set(:@help, nil)
  end
end
