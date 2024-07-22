require 'rails_helper'

RSpec.describe ApplicationController, type: :controller do
  describe "GET" do
    it "returns a successful response" do
      get :scrape
      expect(response).not_to be_successful
      expect(response).to have_http_status(400)
    end
  end

  describe "POST" do
    describe "filters" do
      context "valid filters" do
        it "returns a successful response with valid filters" do
          post :scrape, params: { filters: {batch: 'w21'}, n: 10 }
          expect(response).to be_successful
          expect(response).to have_http_status(200)
          expect(CSV.parse(response.body).size).to eq(11)#includes header
        end

        context "multiple filters" do
          it "returns a successful response with multiple valid filters" do
            post :scrape, params: { filters: {batch: 'w21', industries: 'Healthcare', highlight_women: true }, n: 10 }
            expect(response).to be_successful
            expect(response).to have_http_status(200)
            expect(CSV.parse(response.body).size).to eq(11)#includes header
          end
        end
      end

      context "invalid filters" do
        it "returns a bad request response with invalid filters" do
          post :scrape, params: { filters: {invalid_filter: 'w21'} }
          expect(response).not_to be_successful
          expect(response).to have_http_status(400)
        end

        context "invalid boolean filters" do
          it "returns bad request response for boolean filters with value other true/false" do
            post :scrape, params: { filters: {highlight_black: 'w21'} }
            expect(response).not_to be_successful
            expect(response).to have_http_status(400)
          end
        end
      end
    end

    context "pagination" do
      it "returns response based on page_no and per_page" do
        post :scrape, params: { filters: {batch: 'w21'}, page_no: 2, per_page: 11, max_values_per_facet: 10 }
        respone_array_2_11 = CSV.parse(response.body)
        expect(respone_array_2_11.size).to eq(12)
        post :scrape, params: { filters: {batch: 'w21'}, page_no: 3, per_page: 11, max_values_per_facet: 10 }
        respone_array_3_11 = CSV.parse(response.body)
        expect(respone_array_3_11.size).to eq(12)
        expect(respone_array_2_11).not_to eq(respone_array_3_11)
      end

      it "considers per_page and page_no over n" do
        post :scrape, params: { filters: {batch: 'w21'}, page_no: 2, per_page: 11, n: 5, max_values_per_facet: 10 }
        respone_array_2_11 = CSV.parse(response.body)
        expect(respone_array_2_11.size).to eq(12)
      end
    end
  end
end
