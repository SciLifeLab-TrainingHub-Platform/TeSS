# The helper for searches
module SearchHelper

  def search_and_facet_params
    params.permit(*@model.search_and_facet_keys)
  end

  def clear_filters_path
    params.to_unsafe_h.except(*@model.search_and_facet_keys, :page)
  end

  def facet_title(name, value, html_options = {})
    return render_language_name(value) if name == 'language'

    html_options.delete(:title) || truncate(value.to_s, length: 50)
  end

  def filter_link(name, value, count, html_options = {}, &block)
    parameters = search_and_facet_params

    # if there's already a filter of the same facet type, create/add to an array
    if parameters.include?(name) && !html_options.delete(:replace)
      parameters[name] = Array.wrap(parameters[name]) | [value]
    else
      parameters[name] = value
    end

    parameters.delete('page') # remove the page option if it exists
    html_options.reverse_merge!(title: value.to_s)

    link_to parameters, html_options do
      if block_given?
        block.call
      else
        content_tag(:span, facet_title(name, value, html_options), class: 'facet-label') +
          content_tag(:span, "#{count}", class: 'facet-count')
      end
    end
  end

  def remove_filter_link(name, value, html_options = {}, &block)
    parameters = search_and_facet_params

    # delete a filter from an array or delete the whole facet if it is the only one
    if parameters.include?(name)
      if parameters[name].is_a?(Array)
        parameters[name].delete(value)
        # Go back to being just a singleton if only one element left
        parameters[name] = parameters[name].first if parameters[name].one?
      else
        parameters.delete(name)
      end
    end

    parameters.delete('page') # remove the page option if it exists
    html_options.reverse_merge!(title: value.to_s)

    link_to parameters, html_options do
      if block_given?
        block.call
      else
        content_tag(:span, facet_title(name, value, html_options), class: 'facet-label') +
          content_tag(:i, '', class: 'remove-facet-icon glyphicon glyphicon-remove')
      end
    end
  end

  def toggle_hidden_facet_link facet
    return "<span class='toggle-#{facet}' style='font-weight: bold;'>
            Show more #{facet.humanize.pluralize.downcase}</span>
            <i class='glyphicon glyphicon-chevron-down pull-right toggle-#{facet}'></i>
            <span class='toggle-#{facet}' style='font-weight: bold; display: none;'>
            Show fewer #{facet.humanize.pluralize.downcase}</span>
            <i class='glyphicon glyphicon-chevron-up pull-right toggle-#{facet}' style='display: none;'></i>
            ".html_safe
  end

  def searchable_resource_name(resource_type, variant: :short, count: 2)
    model_key = resource_type.model_name.i18n_key
    i18n_key  = :"features.#{model_key.to_s.pluralize}.#{variant}"

    name =
      if I18n.exists?(i18n_key)
        I18n.t(i18n_key)
      else
        resource_type.model_name.human(count: count)
      end
    name.downcase
  end

  # Returns a count string with custom names if model is in custom_model_entries
  def search_result_label(count, resource_type, variant: :short)
    custom_model_entries = {
      course: "catalogue entry"
    }

    model_key = resource_type.model_name.i18n_key

    # Use custom entry if defined, otherwise fallback to default
    if custom_model_entries.key?(model_key)
      pluralize(count, custom_model_entries[model_key])
    else
      pluralize(count, resource_type.model_name.human.downcase)
    end
  end
end
