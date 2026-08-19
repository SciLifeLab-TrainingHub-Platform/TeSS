module StaticHelper
  def homepage_event_date_range(event, range_separator: '-')
    start_date = event.start&.to_date
    end_date = event.end&.to_date

    return if start_date.blank?
    return start_date.strftime('%B %-d, %Y') if end_date.blank? || end_date == start_date

    if start_date.year != end_date.year
      "#{start_date.strftime('%B %-d, %Y')}#{range_separator}#{end_date.strftime('%B %-d, %Y')}"
    elsif start_date.month != end_date.month
      "#{start_date.strftime('%B %-d')}#{range_separator}#{end_date.strftime('%B %-d, %Y')}"
    else
      "#{start_date.strftime('%B %-d')}#{range_separator}#{end_date.strftime('%-d, %Y')}"
    end
  end

  def homepage_event_location(event)
    event.cities.map(&:name).join(', ').presence || event.country
  end

  def homepage_training_delivery_label(event)
    return if event.presence.blank?

    t("homepage.upcoming_training.delivery.#{event.presence}", default: event.presence.humanize)
  end

  def homepage_training_locations(event)
    return [] if event.online?

    cities = event.cities.map(&:name).reject(&:blank?)
    cities.presence || Array(event.country.presence)
  end

  def homepage_training_registration_label(event)
    deadline = event.application_deadline
    return if deadline.blank?
    return t('homepage.upcoming_training.registration_closed') unless deadline.future?

    t('homepage.upcoming_training.apply_by', date: deadline.strftime('%b %-d, %Y'))
  end
end
