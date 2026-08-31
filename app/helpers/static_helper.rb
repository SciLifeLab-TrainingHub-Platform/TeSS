# frozen_string_literal: true

module StaticHelper
  HOMEPAGE_TRAINING_CARD_TAG_LIMIT = 4

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

    cities = event.cities.map(&:name).compact_blank
    cities.presence || Array(event.country.presence)
  end

  def homepage_training_location_tags(event, delivery_present:)
    locations = homepage_training_locations(event)
    location_tag_limit = HOMEPAGE_TRAINING_CARD_TAG_LIMIT - (delivery_present ? 1 : 0)

    return locations if locations.size <= location_tag_limit

    visible_locations = locations.first(location_tag_limit - 1)
    remaining_count = locations.size - visible_locations.size

    visible_locations + [t('homepage.upcoming_training.more_locations', count: remaining_count)]
  end

  def homepage_training_registration_label(event)
    deadline = event.application_deadline
    return if deadline.blank?
    return t('homepage.upcoming_training.registration_closed') unless deadline.future?

    t('homepage.upcoming_training.apply_by', date: deadline.strftime('%b %-d, %Y'))
  end
end
