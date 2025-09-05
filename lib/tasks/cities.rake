require 'json'

# to execute this file run `rake city:import`
namespace :city do
  desc 'Import cities from local JSON file and save them to the database in batches of 5000'

  task import: :environment do
    # Ensure the "Online" city is added
    City.find_or_create_by(name: City::ONLINE_CITY, country_code: nil)

    file_path = Rails.root.join('config', 'data', 'cities.json')

    unless File.exist?(file_path)
      puts "Cities JSON file not found at #{file_path}"
      exit 1
    end

    puts "Reading city data from #{file_path}..."
    cities = JSON.parse(File.read(file_path))

    puts "Processing city data..."
    city_records = cities.map { |city|
      {
        name: city['name'],
        country_code: city['country'],
      }
    }.uniq

    city_records.each_slice(5000).with_index do |batch, batch_index|
      City.insert_all(batch)

      printed = [(batch_index + 1) * 5000, city_records.size].min
      print_progress(printed, city_records.size)
    end
    puts "\nCity import completed. #{City.count} cities in the database."
  end

  def print_progress(current, total)
    current = [current, total].min
    progress_width = 50
    progress = (current.to_f / total * progress_width).round
    percentage = (current.to_f / total * 100).round

    bar = "=" * progress + " " * (progress_width - progress)
    print "\r[#{bar}] #{percentage}% (#{current}/#{total})"
    $stdout.flush
  end
end
