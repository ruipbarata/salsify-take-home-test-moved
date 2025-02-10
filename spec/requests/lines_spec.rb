# frozen_string_literal: true

require "swagger_helper"

RSpec.describe("lines", type: :request) do
  path "/lines/{index}" do
    parameter name: "index", in: :path, type: :string, description: "Line index in the file", required: true

    # GET method to show a line
    get("Get a line from a remote file") do
      tags "Lines"
      response(200, "Line successfully retrieved") do
        let(:index) { "1" }

        after do |example|
          example.metadata[:response][:content] = {
            "application/json" => {
              example: JSON.parse(response.body, symbolize_names: true),
            },
          }
        end

        run_test!
      end

      response(413, "Index out of range") do
        let(:index) { "-1000" }

        after do |example|
          example.metadata[:response][:content] = {
            "text/plain" => {
              example: "Line index out of range",
            },
          }
        end

        run_test!
      end
    end
  end
end
