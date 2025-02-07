# frozen_string_literal: true

Rails.application.routes.draw do
  root to: redirect("/api-docs")

  mount Rswag::Ui::Engine => "/api-docs"
  mount Rswag::Api::Engine => "/api-docs"

  get "/lines/:index", to: "lines#show"
  get "up" => "rails/health#show", as: :rails_health_check
end
