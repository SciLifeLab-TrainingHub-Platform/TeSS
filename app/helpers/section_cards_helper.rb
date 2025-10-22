module SectionCardsHelper
  def section_card(title, options = {}, &block)
    body_content = capture(&block)
    return ''.html_safe if body_content.blank?

    base_class = options.delete(:base_class) || 'event-section-card'
    title_class = options.delete(:title_class) || 'event-section-title'
    classes = [base_class, options[:class]].compact.join(' ')

    content_tag(:div, class: classes) do
      concat content_tag(:h3, title, class: title_class)
      concat body_content
    end
  end

  def detail_item(label, value = nil, options = {}, &block)
    content = block_given? ? capture(&block) : value
    return ''.html_safe if content.blank?

    base_class = options[:base_class] || 'event-detail'
    item_class = options[:item_class] || "#{base_class}-item"
    label_class = options[:label_class] || "#{base_class}-label"
    value_class = options[:value_class] || "#{base_class}-value"

    content_tag(:div, class: item_class) do
      concat content_tag(:span, label, class: label_class)
      concat content_tag(:div, content, class: value_class)
    end
  end

  def pill_list(values, options = {})
    variant = options[:variant] || :accent
    values = Array(values).flatten.compact.reject(&:blank?)
    return ''.html_safe if values.empty?

    base_class = options[:base_class] || 'event-pill'
    list_class = options[:list_class] || "#{base_class}-list"

    content_tag(:div, class: list_class) do
      safe_join(values.map do |value|
        classes = [base_class]
        classes << "#{base_class}--#{variant}" if variant
        content_tag(:span, value, class: classes.join(' '))
      end)
    end
  end
end
