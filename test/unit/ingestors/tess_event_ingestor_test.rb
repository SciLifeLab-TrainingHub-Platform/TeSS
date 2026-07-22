require 'test_helper'

class TessEventIngestorTest < ActiveSupport::TestCase
  setup do
    skip 'Skipping all the ingestors tests'
    @user = users(:regular_user)
    @content_provider = content_providers(:another_content_provider)
    mock_ingestions
    mock_timezone # System time zone should not affect test result
  end

  teardown do
    reset_timezone
  end

  test 'can ingest events from elixir tess' do
    user = users(:regular_user)
    source = @content_provider.sources.build(
      url: 'https://tess.elixir-europe.org/events?content_provider=ELIXIR+Luxembourg&include_expired=false',
      method: 'tess_event',
      enabled: true,
      user: user
    )

    ingestor = Ingestors::TessEventIngestor.new

    # check event doesn't
    new_title = 'Data processing with R tidyverse'
    new_url = 'https://elixir-luxembourg.org/events/2025_02_10_rtidyverse'
    refute Event.where(title: new_title, url: new_url).any?

    # run task
    assert_difference 'Event.count', 2 do
      freeze_time(2019) do
        ingestor.read(source.url)
        ingestor.write(@user, @content_provider)
      end
    end

    assert_equal 2, ingestor.events.count
    assert ingestor.materials.empty?
    assert_equal 2, ingestor.stats[:events][:added]
    assert_equal 0, ingestor.stats[:events][:updated]
    assert_equal 0, ingestor.stats[:events][:rejected]

    # check event does exist
    event = Event.where(title: new_title, url: new_url).first
    assert event
    assert_equal new_title, event.title
    assert_equal new_url, event.url

    # check other fields
    assert_equal @content_provider.title, event.content_providers[0].title
    assert_equal 'UTC', event.timezone
    assert_nil event.contact
    assert_equal 0, event.eligibility.size, 'event eligibility size not matched!'
    assert_equal 0, event.host_institutions.size
    assert_equal 0, event.keywords.size
    assert_not event.online?
    assert_equal '', event.city
    assert_nil event.country
    assert_equal 'Belval Campus, Luxembourg', event.venue

    # check another event does exist
    other_title = 'Introduction to Research Data Management - Getting started with Data Management and Data Stewardship'
    other_url = 'https://elixir-luxembourg.org/events/2025_02_24_research_data_management'
    events = Event.where(title: other_title, url: other_url)
    assert !events.nil?, 'Post-task: other event search error.'
    assert_equal 1, events.size, "Post-task: other event search title[#{other_title}] found nothing"
    event = events.first
    assert !event.nil?
    # noinspection RubyNilAnalysis
    assert_equal other_title, event.title
    assert_equal other_url, event.url
  end
end
