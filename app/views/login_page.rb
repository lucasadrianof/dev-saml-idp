class Views::LoginPage < Views::Base
  include Phlex::Rails::Helpers::FormAuthenticityToken
  def initialize(sp_entity_id:, acs_url:, relay_state:, saml_request:, default_name_id:, default_name:)
    @sp_entity_id = sp_entity_id
    @acs_url = acs_url
    @relay_state = relay_state
    @saml_request = saml_request
    @default_name_id = default_name_id
    @default_name = default_name
  end

  def view_template
    render Views::ApplicationLayout.new(title: "Login - Dev SAML IDP") do
      div do
        div do
          h1 { "SAML Authentication Request" }

          div do
            h2 { "Service Provider" }
            p { @sp_entity_id || "Unknown" }

            if @acs_url.present?
              h2 { "Return URL" }
              p { @acs_url }
            end
          end

          form(action: "/saml/respond", method: "post") do
            input(type: "hidden", name: "authenticity_token", value: form_authenticity_token)
            input(type: "hidden", name: "saml_request", value: @saml_request)
            input(type: "hidden", name: "acs_url", value: @acs_url)
            input(type: "hidden", name: "relay_state", value: @relay_state)

            div do
              label(for: "name_id") { "Name ID (User Identifier)" }
              input(type: "text", id: "name_id", name: "name_id", value: @default_name_id)
            end

            div do
              label(for: "name") { "Display Name" }
              input(type: "text", id: "name", name: "name", value: @default_name)
            end

            div do
              button(type: "submit", name: "response_type", value: "success") do
                "Authenticate Successfully"
              end

              button(type: "submit", name: "response_type", value: "failure") do
                "Fail Authentication"
              end
            end
          end
        </div>
      end
    end
  end
end
