class CitiesController < ApplicationController
  # POST /cities_by_country
  def cities_by_country
    country_code = params[:country_code]

    if country_code.blank?
      # 400 Bad Request: Missing country code
      respond_to do |format|
        format.json { render json: { error: "Country code is required" }, status: 400 }
      end
      return
    end

    cities = City.where(country_code: country_code).select("id, name")
                 .or(City.online).order(:name)
                 .order(:name)

    # 200 OK: Cities found
    respond_to do |format|
      format.json { render json: { cities: cities }, status: 200 }
    end
  rescue StandardError => e
    # 500 Internal Server Error: Unexpected issue
    respond_to do |format|
      format.json { render json: { error: "Internal server error", details: e.message }, status: 500 }
    end
  end
end
