class Views::SamlResponseForm < Views::Base
  def initialize(acs_url:, saml_response:, relay_state:, is_failure: false)
    @acs_url = acs_url
    @saml_response = saml_response
    @relay_state = relay_state
    @is_failure = is_failure
  end

  def view_template
    doctype
    html do
      head do
        title { "Redirecting..." }
      end
      body do
        form(action: @acs_url, method: "post") do
          input(type: "hidden", name: "SAMLResponse", value: @saml_response)
          input(type: "hidden", name: "RelayState", value: @relay_state) if @relay_state.present?
          noscript do
            p { "Redirecting to Service Provider..." }
            button(type: "submit") { "Click here to continue" }
          end
        end
        script do
          plain "document.forms[0].submit();"
        end
      end
    end
  end
end
