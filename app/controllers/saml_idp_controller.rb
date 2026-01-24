class SamlIdpController < ApplicationController
  include SamlIdp::Controller

  def new
    if params[:SAMLRequest].blank?
      render ::Views::ErrorPage.new(
        title: "Missing SAML Request",
        message: "No SAMLRequest parameter was provided. This endpoint expects a SAML AuthnRequest."
      )
      return
    end

    # Temporarily override configuration with request-based URLs
    base = SamlIdpConfig.base_url(request)
    original_entity_id = SamlIdp.config.entity_id
    original_base_location = SamlIdp.config.base_saml_location
    original_sso_location = SamlIdp.config.single_service_post_location

    begin
      SamlIdp.config.entity_id = SamlIdpConfig.entity_id(request)
      SamlIdp.config.base_saml_location = base
      SamlIdp.config.single_service_post_location = "#{base}/saml/auth"

      decode_request(params[:SAMLRequest], params[:Signature], params[:SigAlg], params[:RelayState])

      render ::Views::LoginPage.new(
        sp_entity_id: saml_request&.issuer,
        acs_url: saml_acs_url,
        relay_state: params[:RelayState],
        saml_request: params[:SAMLRequest],
        default_name_id: SamlIdpConfig.default_name_id,
        default_name: SamlIdpConfig.default_name
      )
    rescue => e
      render ::Views::ErrorPage.new(
        title: "Invalid SAML Request",
        message: "Could not decode SAML request: #{e.message}"
      )
    ensure
      # Restore original configuration
      SamlIdp.config.entity_id = original_entity_id
      SamlIdp.config.base_saml_location = original_base_location
      SamlIdp.config.single_service_post_location = original_sso_location
    end
  end

  def create
    # Temporarily override configuration with request-based URLs
    base = SamlIdpConfig.base_url(request)
    original_entity_id = SamlIdp.config.entity_id
    original_base_location = SamlIdp.config.base_saml_location
    original_sso_location = SamlIdp.config.single_service_post_location

    begin
      SamlIdp.config.entity_id = SamlIdpConfig.entity_id(request)
      SamlIdp.config.base_saml_location = base
      SamlIdp.config.single_service_post_location = "#{base}/saml/auth"

      decode_request(params[:saml_request], nil, nil, params[:relay_state])

      name_id = params[:name_id].presence || SamlIdpConfig.default_name_id

      if params[:response_type] == "success"
        principal = { email: name_id, id: name_id, name: params[:name] }
        saml_response = encode_response(
          principal,
          audience_uri: saml_request.issuer,
          acs_url: params[:acs_url]
        )

        render ::Views::SamlResponseForm.new(
          acs_url: params[:acs_url],
          saml_response: saml_response,
          relay_state: params[:relay_state]
        )
      else
        # Generate a failure response
        saml_response = encode_authn_failed_response(
          saml_request.issuer,
          params[:acs_url]
        )

        render ::Views::SamlResponseForm.new(
          acs_url: params[:acs_url],
          saml_response: saml_response,
          relay_state: params[:relay_state],
          is_failure: true
        )
      end
    ensure
      # Restore original configuration
      SamlIdp.config.entity_id = original_entity_id
      SamlIdp.config.base_saml_location = original_base_location
      SamlIdp.config.single_service_post_location = original_sso_location
    end
  end

  private

  def encode_authn_failed_response(audience_uri, acs_url)
    response_id = SecureRandom.uuid
    issue_instant = Time.now.utc.iso8601

    # Build a SAML Response with AuthnFailed status
    response = <<~XML
      <samlp:Response xmlns:samlp="urn:oasis:names:tc:SAML:2.0:protocol"
                      xmlns:saml="urn:oasis:names:tc:SAML:2.0:assertion"
                      ID="_#{response_id}"
                      Version="2.0"
                      IssueInstant="#{issue_instant}"
                      Destination="#{acs_url}">
        <saml:Issuer>#{SamlIdpConfig.entity_id(request)}</saml:Issuer>
        <samlp:Status>
          <samlp:StatusCode Value="urn:oasis:names:tc:SAML:2.0:status:Responder">
            <samlp:StatusCode Value="urn:oasis:names:tc:SAML:2.0:status:AuthnFailed"/>
          </samlp:StatusCode>
          <samlp:StatusMessage>Authentication was denied by user</samlp:StatusMessage>
        </samlp:Status>
      </samlp:Response>
    XML

    Base64.strict_encode64(response)
  end
end
