module StaticHelper
  def homepage_event_date_range(event)
    start_date = event.start&.to_date
    end_date = event.end&.to_date

    return if start_date.blank?
    return start_date.strftime('%B %-d, %Y') if end_date.blank? || end_date == start_date

    if start_date.year != end_date.year
      "#{start_date.strftime('%B %-d, %Y')}-#{end_date.strftime('%B %-d, %Y')}"
    elsif start_date.month != end_date.month
      "#{start_date.strftime('%B %-d')}-#{end_date.strftime('%B %-d, %Y')}"
    else
      "#{start_date.strftime('%B %-d')}-#{end_date.strftime('%-d, %Y')}"
    end
  end

  def homepage_event_location(event)
    event.cities.map(&:name).join(', ').presence || event.country
  end
end
