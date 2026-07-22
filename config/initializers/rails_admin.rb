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