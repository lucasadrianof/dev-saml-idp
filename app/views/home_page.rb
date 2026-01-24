class Views::HomePage < Views::Base
  attr_reader :request

  def initialize(request:)
    @request = request
  end

  def view_template
    render Views::ApplicationLayout.new(title: "Dev SAML IDP") do
      div do
        div do
          h1 { "Dev SAML IDP" }
          p { "A development SAML Identity Provider for testing SSO integration." }

          div do
            h2 { "Configuration" }
            dl do
              dt { "Entity ID:" }
              dd { SamlIdpConfig.entity_id(request) }

              dt { "SSO URL:" }
              dd { SamlIdpConfig.sso_url(request) }

              dt { "Metadata URL:" }
              dd { SamlIdpConfig.metadata_url(request) }

              dt { "Default Name ID:" }
              dd { SamlIdpConfig.default_name_id }
            end
          end

          div do
            a(href: "/metadata") { "View Metadata" }
          end

          div do
            h2 { "Environment Variables" }
            div do
              p { "IDP_ENTITY_ID - Entity ID for this IDP" }
              p { "IDP_BASE_URL - Base URL for endpoints" }
              p { "IDP_CERTIFICATE - X.509 certificate (PEM)" }
              p { "IDP_PRIVATE_KEY - RSA private key (PEM)" }
              p { "DEFAULT_NAME_ID - Default user identifier" }
              p { "DEFAULT_NAME - Default user display name" }
              p { "ALLOWED_SERVICE_PROVIDERS - Comma-separated SP entity IDs (or * for all)" }
            end
          end
        end
      end
    end
  end
end
