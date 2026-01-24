Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  root "home#index"

  get  "metadata" => "metadata#show"
  get  "saml/auth" => "saml_idp#new"
  post "saml/auth" => "saml_idp#new"
  post "saml/respond" => "saml_idp#create"
end
