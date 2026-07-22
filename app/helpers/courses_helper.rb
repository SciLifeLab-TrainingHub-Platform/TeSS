module CoursesHelper
  COURSE_INFO = <<~TEXT.freeze
    The catalogue is a registry of regularly occurring and self-paced training offered at #{TeSS::Config.site['title_short']}.
    These are typically courses, but may also include other recurring training activities.

    The purpose of the catalogue is to provide an overview of all training opportunities available at #{TeSS::Config.site['title_short']}.
    It allows potential participants to discover and connect with courses, even when no upcoming session is currently scheduled.

    To get started, click "create catalogue entry" and complete the form with the relevant information. Once the form is submitted, it will be reviewed by our moderators.
  TEXT

  def course_section_card(title, options = {}, &block)
    options = options.present? ? options.dup : {}
    options[:class] = [options[:class], 'course-section-card'].compact.join(' ')
    options[:base_class] ||= 'event-section-card'
    options[:title_class] ||= 'event-section-title'
    section_card(title, options, &block)
  end

  def course_detail_item(label, value = nil, options = {}, &block)
    defaults = {
      base_class: 'event-detail',
      item_class: 'event-detail-item',
      label_class: 'event-detail-label',
      value_class: 'event-detail-value'
    }
    detail_item(label, value, defaults.merge(options), &block)
  end

  def course_pill_list(values, variant: :accent)
    pill_list(values, variant: variant)
  end

  def course_target_audience(course)
    Array(course.target_audience).flatten.compact.reject(&:blank?).map do |value|
      target_audience_title_for_label(value)
    end
  end

  def course_keywords(course)
    Array(course.keywords).flatten.compact.reject(&:blank?)
  end

  def course_event_option_label(event)
    return event.title if event.approved?

    suffix = I18n.t("courses.event_option_status.#{event.event_status}", default: event.event_status.humanize)
    "#{event.title} (#{suffix})"
  end

  def course_people_list(people)
    people = normalize_course_people(people)

    return ''.html_safe if people.blank?

    content_tag(:ul, class: 'course-people-list') do
      safe_join(people.map { |person| course_person_list_item(person) })
    end
  end

  def course_events_grouped(course)
    events_source =
      if course.respond_to?(:association) && course.association(:events).loaded?
        course.events
      else
        Event.includes(:content_providers).where(course_id: course.id)
      end

    filtered_events = filter_course_events(events_source)
    events = if filtered_events.respond_to?(:to_a)
               filtered_events.to_a
             else
               Array(filtered_events).compact
             end
    return { upcoming: [], past: [] } if events.blank?

    sorted = events.sort_by { |event| event.start || event.updated_at || Time.zone.at(0) }
    now = Time.zone.now
    upcoming, past = sorted.partition do |event|
      start_at = event.start
      start_at.blank? || start_at >= now
    end

    {
      upcoming: upcoming,
      past: past.sort_by { |event| event.start || event.updated_at || Time.zone.at(0) }.reverse
    }
  end

  def course_event_date_range(event)
    start_at = event.start
    finish_at = event.end

    if start_at.present? && finish_at.present?
      "#{format_course_date(start_at)} – #{format_course_date(finish_at)}"
    elsif start_at.present?
      format_course_date(start_at)
    elsif finish_at.present?
      format_course_date(finish_at)
    else
      'Dates to be confirmed'
    end
  end

  def course_next_event(course)
    @course_next_event_cache ||= {}
    @course_next_event_cache[course.id] ||= begin
      grouped = course_events_grouped(course)
      grouped[:upcoming].first
    end
  end

  def filter_courses_by_status(courses, user)
    return Course.none if courses.blank?

    if user&.is_admin?
      courses
    elsif user
      # Show approved courses and the user's courses (excluding declined)
      courses.where(
        "course_status = ? OR (user_id = ? AND course_status != ?)",
        Course.course_statuses[:approved], user.id, Course.course_statuses[:declined]
      )
    else
      # Show only approved courses for non-logged-in users
      courses.where(course_status: Course.course_statuses[:approved])
    end
  end

  def filter_courses_by_status(courses, user)
    return Course.none if courses.blank?

    if user&.is_admin?
      courses
    elsif user
      # Show approved courses and the user's courses (excluding declined)
      courses.where(
        "course_status = ? OR (user_id = ? AND course_status != ?)",
        Course.course_statuses[:approved], user.id, Course.course_statuses[:declined]
      )
    else
      # Show only approved courses for non-logged-in users
      courses.where(course_status: Course.course_statuses[:approved])
    end
  end

  private

  def format_course_date(datetime)
    l(datetime, format: :long)
  rescue StandardError
    datetime.to_s
  end

  def course_person_list_item(person)
    parts = []

    name = person['name'].presence
    affiliation = person['affiliation'].presence
    orcid = person['orcid'].presence
    email = person['email'].presence

    parts << content_tag(:span, name, class: 'course-person-name') if name
    parts << content_tag(:span, affiliation, class: 'course-person-affiliation') if affiliation

    if orcid
      normalized_orcid = orcid.delete(' ')
      orcid_url = normalized_orcid.start_with?('http') ? normalized_orcid : "https://orcid.org/#{normalized_orcid}"
      parts << link_to(orcid_url, target: '_blank', rel: 'noopener noreferrer', class: 'course-person-orcid') do
        image_tag('modern/icons/orcid.svg', alt: 'ORCID iD', class: 'course-person-orcid-icon') +
          content_tag(:span, 'ORCID', class: 'course-person-orcid-text')
      end
    end

    parts << mail_to(email, email, class: 'course-person-email') if email

    content = parts.compact
    return ''.html_safe if content.blank?

    content_tag(:li, safe_join(content, ' · '), class: 'course-person')
  end

  def normalize_course_people(people)
    Array(people).each_with_object([]) do |person, collection|
      next if person.blank?

      normalized = if person.respond_to?(:to_h)
                     person.to_h
                   elsif person.is_a?(String)
                     begin
                       parsed = JSON.parse(person)
                       parsed.is_a?(Hash) ? parsed : nil
                     rescue JSON::ParserError
                       nil
                     end
                   elsif person.is_a?(Hash)
                     person
                   end

      next unless normalized.is_a?(Hash)

      normalized = normalized.stringify_keys
      next if normalized.values.all? { |value| value.blank? }

      collection << normalized
    end
  end

  def filter_course_events(events_source)
    return Event.none if events_source.blank?

    if events_source.is_a?(ActiveRecord::Relation)
      if current_user&.is_admin?
        events_source
      elsif current_user
        events_source.where(
          "event_status = :approved OR (user_id = :user_id AND event_status != :declined)",
          approved: Event.event_statuses[:approved],
          user_id: current_user.id,
          declined: Event.event_statuses[:declined]
        )
      else
        events_source.where(event_status: Event.event_statuses[:approved])
      end
    else
      filter_events_array(events_source)
    end
  end

  def filter_events_array(events_array)
    events = Array(events_array).compact
    return [] if events.blank?

    if current_user&.is_admin?
      events
    elsif current_user
      events.reject do |event|
        event.event_status == 'declined' && event.user_id == current_user.id
      end.select do |event|
        event.event_status == 'approved' || event.user_id == current_user.id
      end
    else
      events.select { |event| event.event_status == 'approved' }
    end
  end

  def show_course_revision_notice?(course)
    course.course_status == Course.course_statuses.key(Course.course_statuses[:revisions_required])
  end
end
