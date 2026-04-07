# The helper for Events classes

require 'rss'

module EventsHelper

  EVENTS_INFO = <<~INFO.freeze
  Fill in all required fields of this form for our training on the #{TeSS::Config.site['title_short']} portal. You can also watch our [video tutorial](https://www.youtube.com/watch?v=WDMJuH1kRoMs) on how training announcements work.

  Provide detailed information: people browsing need to know what they will learn and whom to contact with questions.

  Once you click 'Add Training', your submission will be sent for moderation. 
  You will see your training in your profile, and are able to edit it until it is approved or rejected by our moderators.
INFO

  def google_calendar_export_url(event)

    if event.all_day?
      # Need to add 1 day for all day events apparently
      dates = "#{event.start.strftime('%Y%m%d')}/#{event.end.tomorrow.strftime('%Y%m%d')}"
    else
      dates = "#{event.start_utc.strftime('%Y%m%dT%H%M00Z')}/#{event.end_utc.strftime('%Y%m%dT%H%M00Z')}"
    end

    if event.online?
      location = 'Online'
    else
      location = [event.venue, event.city, event.country].join(', ')
    end

    event_params = {
      text: event.title,
      dates: dates,
      ctz: event.timezone,
      details: "#{event_url(event)}",
      location: location,
      sf: true,
      output: 'xml'
    }

    "https://www.google.com/calendar/render?action=TEMPLATE&#{event_params.to_param}"
  end

  def ical_from_collection(events)
    cal = Icalendar::Calendar.new

    events.each do |event|
      cal.add_event(event.to_ical_event)
    end

    cal.to_ical
  end

  def rss_from_collection(events)
    RSS::Maker.make('0.91') do |maker|
      # see https://www.rssboard.org/rss-0-9-1-netscape
      # required fields
      maker.channel.description = "#{TeSS::Config.site['title_short']} #{describe_event_filters}"
      maker.channel.language = 'en'
      maker.channel.title = "#{TeSS::Config.site['title']} Event Feed"
      maker.channel.link = controller.request.url

      # optional fields
      # maker.channel.image = # to add later
      maker.channel.lastBuildDate = events.map(&:updated_at).max&.to_s
      maker.channel.webMaster = TeSS::Config.contact_email
      maker.channel.managingEditor = TeSS::Config.contact_email
      maker.image.url = image_url(TeSS::Config.site['logo'])
      maker.image.title = TeSS::Config.site['logo_alt']

      events.each do |event|
        maker.items.new_item do |item|
          # required fields
          item.title = [event.title].compact.join(' - ')
          item.link = event_url(event)

          # optional fields
          description = ''
          description += (neatly_printed_date_range(event.start, event.end) + "\n\n") if event.start.present?
          description += (event.description + "\n\n") if event.description.present?
          # commented as we have removed organizer field from event
          # description += event.organizer if event.organizer.present?
          item.description = description.to_s

          # we should think about our RSS feed updating rules. If a line of the event description
          # changes, do we repost it? I don't think so.
          # also this field is not in the specification...
          item.updated = event.updated_at.to_s
        end
      end
    end
  end

  def describe_event_filters
    if search_and_facet_params
      "Events filtered: #{search_and_facet_params.to_h.map { |k, v| "#{k}: #{v}" }.join(', ')}"
    else
      'Events'
    end
  end

  def csv_column_names
    return %w(Title Start End ContentProvider)
  end

  def csv_from_collection(events)
    CSV.generate do |csv|
      csv << csv_column_names
      events.each do |event|
        unless event.start.nil? or event.end.nil? or event.title.nil?
          csv << event.to_csv_event
        end
      end
    end
  end

  def google_maps_embed_api_tag(event)
    src = 'https://www.google.com/maps/embed/v1/place' +
      "?key=#{Rails.application.secrets.google_maps_api_key}" +
      "&q=#{event.latitude},#{event.longitude}"

    content_tag(:iframe, '', width: 400, height: 250, frameborder: 0, style: 'border: 0', class: 'google-map',
                src: src, allowfullscreen: true)
  end

  def google_maps_javascript_api_tag(event)
    content_tag(:div, 'Loading map...', id: 'map', class: 'google-map', data: {
      'map-latitude': event.latitude,
      'map-longitude': event.longitude,
      'map-suggested-latitude': event.suggested_latitude,
      'map-suggested-longitude': event.suggested_longitude,
      'map-marker-title': event.title,
      'map-suggested-marker-image': image_url('suggestion.png')
    })
  end

  def event_section_card(title, options = {}, &block)
    section_card(title, options, &block)
  end

  def event_detail_item(label, value = nil, &block)
    detail_item(label, value, &block)
  end

  def event_pill_list(values, variant: :accent)
    pill_list(values, variant: variant)

  end

  def event_cost_value(event)
    return "" if event.event_prices.blank?

    lines = event.event_prices.each_with_object([]) do |price, arr|
      next if price.cost.blank?

      formatted_value = number_with_precision(
        price.cost,
        precision: 2,
        strip_insignificant_zeros: true
      )

      currency_display = price.currency
      audience = price.audience_type.presence&.titleize

      # Only add audience part if present
      audience_part = audience.present? ? ": #{audience}" : ""

      arr << "#{formatted_value} #{currency_display} #{audience_part}"
    end

    # Join lines with <br> and mark HTML-safe
    lines.join("<br>").html_safe
  end

  def event_formatted_datetime(datetime)
    return if datetime.blank?

    l(datetime, format: :long)
  rescue StandardError
    datetime.to_s
  end

  DATE_STRF = '%-e %B %Y'
  TIME_STRF = '%H:%M'

  def neatly_printed_date_range(start, finish = nil, display_time = true)
    if start.blank?
      if finish.blank?
        return 'No date given'
      else
        return 'No start date'
      end
    else
      differing = []

      if finish.present?
        if finish.to_date != start.to_date
          differing << '%-e'
          if finish.month != start.month
            differing << '%B'
            if finish.year != start.year
              differing << '%Y'
            end
          end
        end
      end

      if finish.blank? || differing.empty?
        out = start.strftime(DATE_STRF)
        # Don't show time component if they are set to midnight since that is the default if no time specified.
        # Revisit this decision if any events start occurring at midnight (timezone issue?)!

        if display_time
          show_time = (start.hour != 0 || start.min != 0) || (finish.present? && (finish.hour != 0 || finish.min != 0))
          if show_time
            out << " @ #{start.strftime(TIME_STRF)}"
            out << " - #{finish.strftime(TIME_STRF)}" if finish && (finish.hour != start.hour || finish.min != start.min)
          end
        end
        out
      elsif differing.any?
        "#{start.strftime(differing.join(' '))} - #{finish.strftime(DATE_STRF)}"
      end
    end
  end

  def filter_events_by_status(events, user)
    return Event.none if events.blank?
    if user&.is_admin?
      events
    else
      if user
        # Show approved events and the user's events (excluding declined)
        events.where("event_status = ? OR (user_id = ? AND event_status != ?)",
                     Event.event_statuses[:approved], user.id, Event.event_statuses[:declined])
      else
        # Show only approved events for non-logged-in users
        events.where(event_status: Event.event_statuses[:approved])
      end
    end
  end

  def show_event_revision_notice?(event)
    event.event_status == Event.event_statuses.key(Event.event_statuses[:revisions_required])
  end

  def get_event_audience_types(current_user)
    default_options = EventPrice::DEFAULT_AUDIENCE_TYPES

    # get all events for the current user
    user_events = Event.where(user_id: current_user.id)

    # if the user has no other events, just return the default options
    return default_options if user_events.empty?

    # get distinct audience_type values from EventPrice
    # assuming EventPrice has columns: event_id, audience_type
    audience_types_from_user_events = EventPrice
                                        .where(event_id: user_events.select(:id))
                                        .distinct
                                        .pluck(:audience_type)

    # merge with default options, remove duplicates
    (default_options + audience_types_from_user_events).uniq
  end
end
