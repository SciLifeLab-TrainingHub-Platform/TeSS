require 'json'
require 'httparty'

namespace :city do
  desc 'Import cities from external JSON file and save them to the database'

  task import: :environment do
    url = 'https://raw.githubusercontent.com/lutangar/cities.json/master/cities.json'

    puts "Fetching city data from #{url}..."
    response = HTTParty.get(url)

    if response.code == 200
      cities = JSON.parse(response.body)

      puts "Processing city data..."

      #  ["Insiza", "ZW"],
      city_names_and_countries = cities.map { |city| [city['name'], city['country']] }.uniq

      total = city_names_and_countries.size
      puts "Saving #{total} cities to the database..."

      city_names_and_countries.each_with_index do |city_info, index|
        City.find_or_create_by(name: city_info[0], country_code: city_info[1])

        # Update progress bar
        print_progress(index + 1, total)
      end

      puts "\nCity import completed. #{City.count} cities in the database."
    else
      puts "Failed to fetch city data. HTTP Response Code: #{response.code}"
    end
  end

  def print_progress(current, total)
    progress_width = 50
    progress = (current.to_f / total * progress_width).round
    percentage = (current.to_f / total * 100).round

    bar = "=" * progress + " " * (progress_width - progress)
    print "\r[#{bar}] #{percentage}% (#{current}/#{total})"
    $stdout.flush
  end
end