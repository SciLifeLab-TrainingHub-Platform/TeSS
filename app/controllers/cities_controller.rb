class CitiesController < ApplicationController
  # POST /cities_by_country
  def cities_by_country
    country_code = params[:country_code].to_s.strip

    if country_code.blank?
      # 400 Bad Request: Missing country code
      respond_to do |format|
        format.json { render json: { error: "Country code is required" }, status: 400 }
      end
      return
    end

    cities = City.where(country_code: country_code).select(:id, :name)
                 .or(City.online.select(:id, :name))
                 .order(:name)

    # 200 OK: Cities found
    respond_to do |format|
      format.json { render json: { cities: cities }, status: 200 }
    end
  rescue StandardError => e
    # 500 Internal Server Error: Unexpected issue
    Rails.logger.error("CitiesController#cities_by_country error: #{e.class}: #{e.message}")
    respond_to do |format|
      format.json { render json: { error: "Internal server error" }, status: 500 }
    end
  end
end
