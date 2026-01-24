class Views::ErrorPage < Views::Base
  def initialize(title:, message:)
    @title = title
    @message = message
  end

  def view_template
    render Views::ApplicationLayout.new(title: "Error - Dev SAML IDP") do
      div do
        div do
          h1 { @title }
          p { @message }
          div do
            a(href: "/") { "Return to Home" }
          end
        end
      end
    end
  end
end
