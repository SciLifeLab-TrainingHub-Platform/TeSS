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

  test 'length options that are plain numbers are left alone' do
    field = RailsAdmin.config(User).edit.fields.detect { |f| f.name == :username }

    assert_nothing_raised { field.help }
  end
end
