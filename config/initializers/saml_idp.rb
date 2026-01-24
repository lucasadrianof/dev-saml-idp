require "openssl"

module SamlIdpConfig
  class << self
    def certificate
      @certificate ||= ENV["IDP_CERTIFICATE"] || generated_certificate
    end

    def private_key
      @private_key ||= ENV["IDP_PRIVATE_KEY"] || generated_private_key
    end

    # Request-based methods that use the actual request to determine URLs
    def entity_id(request = nil)
      return ENV["IDP_ENTITY_ID"] if ENV["IDP_ENTITY_ID"].present?
      base_url(request)
    end

    def base_url(request = nil)
      return ENV["IDP_BASE_URL"] if ENV["IDP_BASE_URL"].present?
      return "http://localhost:3000" unless request

      "#{request.scheme}://#{request.host_with_port}"
    end

    def metadata_url(request = nil)
      "#{base_url(request)}/metadata"
    end

    def sso_url(request = nil)
      "#{base_url(request)}/saml/auth"
    end

    def default_name_id
      ENV.fetch("DEFAULT_NAME_ID", "user@example.com")
    end

    def default_name
      ENV.fetch("DEFAULT_NAME", "Test User")
    end

    def allowed_service_providers
      providers = ENV.fetch("ALLOWED_SERVICE_PROVIDERS", "*")
      return nil if providers == "*"
      providers.split(",").map(&:strip)
    end

    private

    def generated_certificate
      ensure_generated_keypair
      @generated_cert.to_pem
    end

    def generated_private_key
      ensure_generated_keypair
      @generated_key.to_pem
    end

    def ensure_generated_keypair
      return if @generated_key && @generated_cert

      @generated_key = OpenSSL::PKey::RSA.new(2048)

      cert = OpenSSL::X509::Certificate.new
      cert.version = 2
      cert.serial = rand(1..1_000_000)
      cert.subject = OpenSSL::X509::Name.parse("/CN=Dev SAML IDP/O=Development/C=US")
      cert.issuer = cert.subject
      cert.public_key = @generated_key.public_key
      cert.not_before = Time.now
      cert.not_after = Time.now + (365 * 24 * 60 * 60) # 1 year

      ef = OpenSSL::X509::ExtensionFactory.new
      ef.subject_certificate = cert
      ef.issuer_certificate = cert
      cert.add_extension(ef.create_extension("basicConstraints", "CA:TRUE", true))
      cert.add_extension(ef.create_extension("keyUsage", "keyCertSign, cRLSign, digitalSignature", true))
      cert.add_extension(ef.create_extension("subjectKeyIdentifier", "hash", false))

      cert.sign(@generated_key, OpenSSL::Digest::SHA256.new)
      @generated_cert = cert

      Rails.logger.info "Generated self-signed certificate for SAML IDP"
    end
  end
end

SamlIdp.configure do |config|
  config.x509_certificate = SamlIdpConfig.certificate
  config.secret_key = SamlIdpConfig.private_key

  base = SamlIdpConfig.base_url
  config.base_saml_location = base
  config.entity_id = SamlIdpConfig.entity_id
  config.single_service_post_location = "#{base}/saml/auth"

  config.name_id.formats = {
    "1.1" => {
      email_address: ->(principal) { principal[:email] }
    },
    "2.0" => {
      transient: ->(principal) { principal[:id] },
      persistent: ->(principal) { principal[:id] }
    }
  }

  allowed = SamlIdpConfig.allowed_service_providers
  if allowed
    config.service_provider.finder = ->(entity_id) do
      if allowed.include?(entity_id)
        {
          response_hosts: [URI.parse(entity_id).host].compact,
          acs_url: nil # Will use the ACS URL from the request
        }
      end
    end
  else
    # Allow all service providers in dev mode
    config.service_provider.finder = ->(entity_id) do
      {
        response_hosts: [],
        acs_url: nil
      }
    end
  end

  config.algorithm = :sha256
end
