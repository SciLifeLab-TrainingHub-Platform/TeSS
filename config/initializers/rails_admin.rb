# Devise 5 declares the password length rule with procs, e.g.
#   validates_length_of :password, minimum: proc { password_length.min }
# RailsAdmin writes each field's help text by comparing those options against
# integers, so every user form under /admin fails to render with
# "comparison of Integer with Proc failed". Here we run the procs first and hand
# RailsAdmin the numbers they return.
# Upstream bug, still present in rails_admin 3.3.0:
# https://github.com/railsadminteam/rails_admin/issues/3711
# Remove this patch once a released version carries the upstream fix.
RailsAdmin::Config::Fields::Base.register_instance_option :valid_length do
  @valid_length ||= begin
    model = abstract_model.model
    field_name = name
    validator = model.validators_on(field_name).detect { |v| v.kind == :length }

    (validator&.options || {}).to_h do |key, option|
      next [key, option] unless option.respond_to?(:call)

      value = begin
        option.call(model)
      rescue StandardError => e
        # Drop the option rather than break the form, but say so loudly: a
        # silently missing limit is how this goes unnoticed for months.
        Rails.logger.error("RailsAdmin could not resolve the :#{key} length option for " \
                           "#{model}##{field_name}: #{e.class} - #{e.message}")
        nil
      end

      [key, value]
    end
  end
end

RailsAdmin.config do |config|
  config.main_app_name = ['TeSS', 'Administration']
  config.asset_source = :sprockets

  config.authenticate_with do
    redirect_to main_app.root_path unless current_user.try(:is_admin?)
    warden.authenticate! scope: :user
  end

  config.current_user_method(&:current_user)

  config.model 'Course' do
    navigation_label 'Course/Event'
    weight -4
  end

  config.model 'CourseInterest' do
    navigation_label 'Course/Event'
    weight -3
  end

  config.model 'Event' do
    navigation_label 'Course/Event'
    weight -2
  end
end