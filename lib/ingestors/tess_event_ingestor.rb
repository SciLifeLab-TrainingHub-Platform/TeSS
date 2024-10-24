require 'open-uri'
require 'csv'

module Ingestors
  class TessEventIngestor < Ingestor
    def self.config
      {
        key: 'tess_event',
        title: 'TeSS Events API',
        category: :events
      }
    end

    def read(url)
      begin
        process_elixir(url)
      rescue Exception => e
        @messages << "#{self.class.name} failed with: #{e.message}"
      end

      # finished
      nil
    end

    private

    def process_elixir(url)
      # execute REST request
      results = get_json_response url, 'application/vnd.api+json'
      data = results['data']

      # extract materials from results
      unless data.nil? or data.size < 1
        data.each do |item|
          # create new event
          event = OpenStruct.new

          # extract event details from
          attr = item['attributes']
          event.title = attr['title']
          event.url = attr['url'].strip unless attr['url'].nil?
          event.description = convert_description attr['description']
          event.start = attr['start']
          event.end = attr['end']
          event.timezone = 'UTC'
          event.contact = attr['contact']
          event.online = attr['online']
          event.city = attr['city']
          event.country = attr['country']
          event.venue = attr['venue']
          event.online = true if attr['venue'] == 'Online'

          # array fields
          event.keywords = []
          attr['keywords'].each { |keyword| event.keywords << keyword } unless attr['keywords'].nil?

          event.host_institutions = []
          attr['host-institutions'].each { |host| event.host_institutions << host } unless attr['host-institutions'].nil?

          # dictionary fields
          event.eligibility = []
          unless attr['eligibility'].nil?
            attr['eligibility'].each do |key|
              value = convert_eligibility(key)
              event.eligibility << value unless value.nil?
            end
          end
          event.event_types = []
          unless attr['event_types'].nil?
            attr['event_types'].each do |key|
              value = convert_event_types(key)
              event.event_types << value unless value.nil?
            end
          end

          # add event to events array
          add_event(event)
        rescue Exception => e
          @messages << "Extract event fields failed with: #{e.message}"
        end
      end
    end
  end
end
