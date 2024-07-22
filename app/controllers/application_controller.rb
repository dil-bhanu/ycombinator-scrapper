class ApplicationController < ActionController::API
  def scrape
    error_message = invalid_filters_message
    if request.get?
      error_message = "Please use POST request"
    end
    return render json: { error: error_message}, status: :bad_request if error_message
    companies_details = CompanyDetailsScrapper.scrape(params)
    render json: companies_details
  end

  def invalid_filters_message
    error_message = nil
    return error_message unless params[:filters]
    if (params[:filters].keys - CompanyDetailsScrapper::FACETS).present?
      error_message = "these are the valid filters #{CompanyDetailsScrapper::FACETS.join(', ')}"
    end
    (CompanyDetailsScrapper::FACETS[0..5] & params[:filters].keys).each do |bool_filter|
      unless ['true', 'false', true, false].include?(params[:filters][bool_filter])
        error_message = "(Top Companies, Is Hiring, Nonprofit, Black-founded, Hispanic & Latino-founded, Women-founded) are boolean filters"
        return error_message
      end
    end
    error_message
  end
end
