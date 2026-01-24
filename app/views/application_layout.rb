class Views::ApplicationLayout < Views::Base
  def initialize(title: "Dev SAML IDP")
    @title = title
  end

  def view_template(&block)
    doctype
    html(lang: "en") do
      head do
        meta(charset: "utf-8")
        meta(name: "viewport", content: "width=device-width, initial-scale=1")
        title { @title }
      end
      body do
        main(&block)
      end
    end
  end
end
