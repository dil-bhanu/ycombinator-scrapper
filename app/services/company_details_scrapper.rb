require 'uri'
require 'json'
require 'net/http'
require 'rack'
require 'nokogiri'
require 'open-uri'
require 'csv'

class CompanyDetailsScrapper

  FACETS = [
    "app_answers",
    "app_video_public",
    "demo_day_video_public",
    "highlight_black",
    "highlight_latinx",
    "highlight_women",
    "batch",
    "industries",
    "isHiring",
    "nonprofit",
    "question_answers",
    "regions",
    "subindustry",
    "tags",
    "top_company",
    "team_size",
    "query",
  ].freeze

  def self.scrape(params)
    new(*params).get_details
  end
  
  def initialize(params)
    @filter_and_values = params[:filters] || {}
    @count = params[:n] || 100
    @page = params[:page_no]
    @per_page = params[:per_page]
    @max_values_per_facet = params[:max_values_per_facet]
  end
  
  def get_details
    return "invalid filters applied #{invalid_filters}" if invalid_filters.present?

    https = Net::HTTP.new(url.host, url.port)
    https.use_ssl = true
  
    request = Net::HTTP::Post.new(url)
    set_headers(request)
    set_request_body(request)
    begin
      response = https.request(request)
    rescue => exception
      return "Didn't go as expected, #{exception}"
    end
    if response.code == '200'
      data = JSON.parse(response.read_body)
      companies_details = data['results'][0]["hits"]
      count = 0
      respone_array = companies_details.map do |company_details|
        count += 1
        nokogiri_doc = company_doc(company_details["slug"])
        {
          'name': company_details['name'],
          'location': company_details['all_locations'].split(', ').first,
          'description': company_details['one_liner'],
          'batch': company_details['batch'],
          'website': company_details['website'],
          'founders': get_founders(nokogiri_doc),
          'founders_linkedins': get_founders_linkedins(nokogiri_doc)
        }
      end
      generate_csv_data(respone_array)
    else
      return "Didn't go as expected, #{response.read_body}"
    end
  end

  def generate_csv_data(data)
    CSV.generate do |csv|
      csv << ['Name', 'Location', 'Description', 'Batch', 'Website', 'Founders', 'Founders Linkedins']
      data.each do |company|
        csv << [
          company[:name],
          company[:location],
          company[:description],
          company[:batch],
          company[:website],
          company[:founders],
          company[:founders_linkedins]
        ]
      end
    end
  end

  private

  def invalid_filters
    @invalid_keys = @filter_and_values.keys - facets
  end

  def url
    x_algolia_agent="Algolia%20for%20JavaScript%20(3.35.1)%3B%20Browser%3B%20JS%20Helper%20(3.4.4)"
    x_algolia_application_id="45BWZJ1SGC"
    x_algolia_api_key = 'Zjk5ZmFjMzg2NmQxNTA0NGM5OGNiNWY4MzQ0NDUyNTg0MDZjMzdmMWY1NTU2YzZkZGVmYjg1ZGZjMGJlYjhkN3Jlc3RyaWN0SW5kaWNlcz1ZQ0NvbXBhbnlfcHJvZHVjdGlvbiZ0YWdGaWx0ZXJzPSU1QiUyMnljZGNfcHVibGljJTIyJTVEJmFuYWx5dGljc1RhZ3M9JTVCJTIyeWNkYyUyMiU1RA%3D%3D'
    algolia_url = "https://45bwzj1sgc-dsn.algolia.net/1/indexes/*/queries?x-algolia-agent=#{x_algolia_agent}&x-algolia-application-id=#{x_algolia_application_id}&x-algolia-api-key=#{x_algolia_api_key}"
    URI(algolia_url)
  end
  
  def set_headers(request)
    {
      'Connection' => 'keep-alive',
      'accept' => 'application/json',
      'Origin' => 'https://www.ycombinator.com',
      'content-type' => 'application/x-www-form-urlencoded',
      'Referer' => 'https://www.ycombinator.com/',
      'Accept-Language' => 'en-GB,en-US;q=0.9,en;q=0.8'
    }.each do |header, value|
      request[header] = value
    end
  end
  
  def filters_applied
    filters_applied = {}
    (@filter_and_values.keys || FACETS).each do |facet|
      ['team_size', 'query'].include?(facet) ? next : filters_applied[facet] = @filter_and_values[facet]
    end
    filters_applied
  end

  def facets
    FACETS
  end

  def pagination_filters
    filters = (@page && @per_page) ? {'hitsPerPage': @per_page,'page': @page} : {'hitsPerPage': @count}
    filters['maxValuesPerFacet'] = @max_values_per_facet if @max_values_per_facet
    filters
  end
  
    
  def facetFilters
    filters_applied&.map do |facet, value|
      if value.is_a? Array
        value.map { |v| "#{facet}:#{v}" }
      elsif value
        ["#{facet}:#{value}"]
      end
    end
  end

  def team_size_filter
    if size = @filter_and_values[:team_size]
      size = size.split('-')[1]
      ["team_size<=#{size}"]
    end
  end
  
  def query_params
    pagination_filters.merge({
      facetFilters: facetFilters,
      clickAnalytics: false,
      query: @filter_and_values[:query],
      numericFilters: team_size_filter,
    })
  end
  
  def set_request_body(request)
    request.body = JSON.generate({
      'requests': [{
        'indexName': 'YCCompany_production',
        'params': Rack::Utils.build_query(query_params)
      }]
    })
  end
  
  def company_doc(slug)
    begin
      Nokogiri::HTML(URI.open("https://www.ycombinator.com/companies/#{slug}"))
    rescue
      nil
    end
  end
  
  def get_founders(nokogiri_doc)
    nokogiri_doc && nokogiri_doc.css('.shrink-0.rounded-md').css('div.font-bold').map do |element|
      element.text
    end.join(', ')
  end
  
  def get_founders_linkedins(nokogiri_doc)
    nokogiri_doc && nokogiri_doc.css('.shrink-0.rounded-md').css('a[title="LinkedIn profile"]').map do |link|
      link['href']
    end.join(', ')
  end
  
end