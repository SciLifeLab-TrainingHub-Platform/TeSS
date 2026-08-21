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
end
