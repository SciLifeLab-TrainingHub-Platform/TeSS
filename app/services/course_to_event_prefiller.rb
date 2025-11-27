class CourseToEventPrefiller
  Result = Struct.new(:applied_fields, :warnings, keyword_init: true)

  def self.prefill(event, course, user)
    applied = []
    warnings = []

    set_field(event, :title, default_title(course), applied)
    set_field(event, :description, course.description, applied)
    set_field(event, :learning_objectives, course.learning_outcomes, applied)
    set_field(event, :prerequisites, course.prerequisites_knowledge, applied)
    set_field(event, :tech_requirements, course.prerequisites_technical, applied)
    set_array_field(event, :keywords, course.keywords, applied)
    set_array_field(event, :target_audience, course.target_audience, applied)
    set_field(event, :language, course.language, applied)

    set_course_association(event, course, applied)
    prefill_content_providers(event, course, user, applied, warnings)
    prefill_nodes(event, course, applied)

    Result.new(applied_fields: applied, warnings: warnings)
  end

  def self.prefill_payload(course, user)
    editable_provider_ids = Array(user&.get_editable_providers&.pluck(:id))
    course_provider_ids = course.content_providers.pluck(:id)
    allowed_provider_ids = editable_provider_ids.present? ? (course_provider_ids & editable_provider_ids) : []

    warnings = []
    if allowed_provider_ids.length < course_provider_ids.length && allowed_provider_ids.any?
      warnings << 'Content providers were limited to those you can edit.'
    end
    if allowed_provider_ids.empty? && course_provider_ids.any?
      warnings << 'No content providers were prefilled because you cannot edit the course providers.'
    end

    node_ids = filtered_node_ids(course)

    payload = {
      title: course.title,
      description: course.description,
      learning_objectives: course.learning_outcomes,
      prerequisites: course.prerequisites_knowledge,
      tech_requirements: course.prerequisites_technical,
      keywords: course.keywords,
      target_audience: course.target_audience,
      language: course.language,
      course_id: course.id,
      content_provider_ids: allowed_provider_ids,
      node_ids: node_ids,
      warnings: warnings
    }

    payload[:applied_fields] = payload.keys.reject { |k| k == :warnings }.select { |k| payload[k].present? }
    payload
  end

  def self.set_field(event, field, value, applied)
    return unless event.respond_to?(field) && event.public_send(field).blank? && value.present?

    event.public_send("#{field}=", value)
    applied << field
  end
  private_class_method :set_field

  def self.set_array_field(event, field, values, applied)
    return unless event.respond_to?(field)
    return if event.public_send(field).present?

    values = Array(values).compact
    return if values.blank?

    event.public_send("#{field}=", values)
    applied << field
  end
  private_class_method :set_array_field

  def self.set_course_association(event, course, applied)
    return unless event.respond_to?(:course) && event.course.blank?

    event.course = course
    applied << :course
  end
  private_class_method :set_course_association

  def self.prefill_content_providers(event, course, user, applied, warnings)
    return unless event.respond_to?(:content_provider_ids)
    return if event.content_provider_ids.present?

    editable_provider_ids = Array(user&.get_editable_providers&.pluck(:id))
    return if editable_provider_ids.blank?

    course_provider_ids = course.content_providers.pluck(:id)
    allowed_ids = course_provider_ids & editable_provider_ids

    if allowed_ids.any?
      event.content_provider_ids = allowed_ids
      applied << :content_provider_ids
      warnings << 'Content providers were limited to those you can edit.' if allowed_ids.length < course_provider_ids.length
    else
      warnings << 'No content providers were prefilled because you cannot edit the course providers.'
    end
  end
  private_class_method :prefill_content_providers

  def self.prefill_nodes(event, course, applied)
    return unless TeSS::Config.feature['nodes'] && Node.all.count.positive?
    return unless event.respond_to?(:node_ids)
    return if event.node_ids.present?

    existing_node_ids = Node.pluck(:id)
    course_node_ids = Array(course.node_ids) & existing_node_ids
    return if course_node_ids.blank?

    event.node_ids = course_node_ids
    applied << :node_ids
  end
  private_class_method :prefill_nodes

  def self.default_title(course)
    return nil unless course.respond_to?(:title)

    course_title = course.title.to_s.strip
    return nil if course_title.blank?

    course_title
  end
  private_class_method :default_title

  def self.filtered_node_ids(course)
    return [] unless TeSS::Config.feature['nodes'] && Node.all.count.positive?

    existing_node_ids = Node.pluck(:id)
    Array(course.node_ids) & existing_node_ids
  end
  private_class_method :filtered_node_ids
end
