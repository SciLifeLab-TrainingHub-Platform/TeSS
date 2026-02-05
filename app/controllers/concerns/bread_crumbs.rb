# Inspired by SEEK's breadcrumbs library
# https://github.com/seek4science/seek/blob/02d63e9e483deb466ee9097252446c02b5837916/lib/seek/breadcrumbs.rb

module BreadCrumbs
  extend ActiveSupport::Concern

  # Maps controller names to human-friendly breadcrumb labels.
  # This allows us to show "Training" instead of "Events" in breadcrumbs
  # without renaming controllers, models, routes, or policies.
  CONTROLLER_NAME_ALIASES = {
    'events' => 'Training'
  }.freeze

  private

  # Returns the breadcrumb label for the current controller.
  # Uses an alias if defined above, otherwise falls back to the default
  # Rails-style humanized controller name.
  # Example: EventsController => "Training", UsersController  => "Users"
  def breadcrumb_controller_name
    CONTROLLER_NAME_ALIASES.fetch(controller_name) do
      controller_name.singularize.humanize.pluralize
    end
  end

  # Make sure this is called after the @resource is set!
  def set_breadcrumbs
    # Instead of using controller_name directly, we now use the
    # breadcrumb_controller_name helper so aliases are respected.
    add_base_breadcrumbs(breadcrumb_controller_name)

    if params[:id]
      resource = instance_variable_get("@#{controller_name.singularize}")

      add_show_breadcrumb resource if (resource && resource.respond_to?(:new_record?) && !resource.new_record?)

      add_breadcrumb action_name.capitalize.humanize, url_for(resource) unless action_name == 'show'
    elsif action_name != 'index'
      add_breadcrumb action_name.capitalize.humanize, url_for(:controller => controller_name, :action => action_name)
    end
  end

  def add_base_breadcrumbs(con_name = controller_name)
    #Home
    add_breadcrumb 'Home', root_path

    #Index
    add_index_breadcrumb(con_name)
  end

  def add_index_breadcrumb(con_name, breadcrumb_name = nil)

    # Default breadcrumb name now comes from breadcrumb_controller_name
    # so controller aliases (e.g. Events → Training) are applied consistently.
    breadcrumb_name ||= breadcrumb_controller_name

    # URL still uses the real controller name to avoid breaking routing
    add_breadcrumb breadcrumb_name, url_for(controller: "/#{controller_name}", action: 'index')
  end

  def add_show_breadcrumb resource, breadcrumb_name = nil
    breadcrumb_name ||= if resource.respond_to?(:title)
                          resource.title
                        elsif resource.respond_to?(:name) && resource.name.present?
                          resource.name
                        else
                          resource.id
                        end

    add_breadcrumb breadcrumb_name, url_for(resource)
  end

  def add_breadcrumb(name, url = '', options = {})
    @breadcrumbs ||= []
    @breadcrumbs << { name: name, url: url, options: options }
  end
end
