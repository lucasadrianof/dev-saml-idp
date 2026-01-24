class MetadataController < ApplicationController
  include SamlIdp::Controller

  def show
    # Temporarily override configuration with request-based URLs
    base = SamlIdpConfig.base_url(request)

    original_entity_id = SamlIdp.config.entity_id
    original_base_location = SamlIdp.config.base_saml_location
    original_sso_location = SamlIdp.config.single_service_post_location

    begin
      SamlIdp.config.entity_id = SamlIdpConfig.entity_id(request)
      SamlIdp.config.base_saml_location = base
      SamlIdp.config.single_service_post_location = "#{base}/saml/auth"

      render xml: SamlIdp.metadata.signed
    ensure
      # Restore original configuration
      SamlIdp.config.entity_id = original_entity_id
      SamlIdp.config.base_saml_location = original_base_location
      SamlIdp.config.single_service_post_location = original_sso_location
    end
  end
end
