# frozen_string_literal: true

require "test_helper"

class LinesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @line = lines(:one)
  end

  test "should show line" do
    get line_url(@line), as: :json
    assert_response :success
  end
end
