# Dev SAML IdP

A SAML Identity Provider for local development. Lets you test SAML authentication without setting up Okta, Auth0, or Azure AD.

## Why

When you're building or testing SAML integration, you need an IdP that:
- Runs locally without configuration
- Lets you choose success or failure responses
- Works offline
- Doesn't require accounts or API keys

That's this.

## Quick Start

### Option 1: Docker (Recommended)

```bash
docker run -p 3000:3000 loomio/dev-saml-idp:latest
```

The IdP will be available at `http://localhost:3000`.

With environment variables:
```bash
docker run -p 3000:3000 \
  -e DEFAULT_NAME_ID=test@example.com \
  -e DEFAULT_NAME="Test User" \
  loomio/dev-saml-idp:latest
```

### Option 2: Local Development

```bash
bundle install
rails server
```

The IdP will be available at `http://localhost:3000`.

### Configure Your Application

Point your SAML Service Provider (the app you're developing/testing) to these endpoints:

- **Entity ID:** `http://localhost:3000`
- **SSO URL:** `http://localhost:3000/saml/auth`
- **Metadata URL:** `http://localhost:3000/metadata`

### 3. Test the Flow

1. **Initiate login** from your application (trigger SAML authentication)
2. **You'll be redirected** to the IdP login page
3. **Choose your outcome:**
   - Optionally edit the **Name ID** (user identifier, defaults to `user@example.com`)
   - Optionally edit the **Display Name** (defaults to `Test User`)
   - Click **Authenticate Successfully** (green button) for a successful SAML response
   - Click **Fail Authentication** (red button) for an authentication failure
4. **Automatically redirected** back to your application with the SAML response

That's it! No configuration files, no environment variables, no database setup.

## How It Works

The IdP auto-detects its entity ID from incoming requests. If you run it on `http://localhost:3000`, that's the entity ID. If you run it on `http://localhost:4444` or behind ngrok, it adapts automatically.

When your app initiates SAML authentication:
1. You're redirected to the IdP login page
2. You choose "Authenticate Successfully" or "Fail Authentication"
3. Optionally edit the Name ID (user email) and display name
4. The IdP generates a signed SAML response
5. You're auto-redirected back to your app with the response

## Configuration

You don't need any. It works out of the box.

Optional environment variables:

| Variable | Description | Default |
|----------|-------------|---------|
| `DEFAULT_NAME_ID` | Default user email on login form | `user@example.com` |
| `DEFAULT_NAME` | Default user name on login form | `Test User` |
| `ALLOWED_SERVICE_PROVIDERS` | Comma-separated SP entity IDs to accept | `*` (all) |
| `IDP_ENTITY_ID` | Override auto-detected entity ID | Auto-detected |
| `IDP_BASE_URL` | Override auto-detected base URL | Auto-detected |
| `IDP_CERTIFICATE` | Custom X.509 certificate (PEM) | Auto-generated |
| `IDP_PRIVATE_KEY` | Custom RSA private key (PEM) | Auto-generated |

## Use Cases

**Local development** - Building SAML support into your app? Point it at this instead of a production IdP.

**Testing failures** - Most test IdPs only return success. This one lets you click a button to test your error handling.

**CI/CD** - Spin it up in your test suite without external dependencies:
```bash
# With Docker
docker run -d -p 3001:3000 loomio/dev-saml-idp:latest
# Run your integration tests

# Or with Rails
rails server -p 3001 -d
# Run your integration tests
```

**Offline work** - No internet required. No accounts, no API keys, no external services.

## API Reference

### Endpoints

| Method | Path | Description |
|--------|------|-------------|
| GET | `/` | Home page showing current configuration |
| GET | `/metadata` | SAML metadata XML (auto-generated based on request) |
| GET/POST | `/saml/auth` | Receive SAML AuthnRequest, show interactive login page |
| POST | `/saml/respond` | Generate and return SAML Response |

## Testing the IdP

### Quick Test with a SAML Tool

Verify the IdP works using online SAML testing tools (like samltest.id):

1. Visit `http://localhost:3000/metadata`
2. Copy the metadata XML
3. Configure the test tool with this metadata
4. Initiate a login from the test tool
5. You'll be redirected to the IdP login page
6. Click "Authenticate Successfully"
7. You'll be returned to the test tool with a valid SAML response

### Test with Your Own App

If you're developing a Rails app with the `ruby-saml` gem:

```ruby
# config/initializers/saml.rb
settings = OneLogin::RubySaml::Settings.new
settings.idp_entity_id = "http://localhost:3000"
settings.idp_sso_service_url = "http://localhost:3000/saml/auth"
settings.idp_cert_fingerprint_algorithm = XMLSecurity::Document::SHA256
# ... rest of your SAML config
```

Then trigger SAML authentication from your app and you'll be redirected to the IdP.

### Generate a SAML Request Manually

For testing or debugging, generate a SAML request:

```ruby
# In Rails console or a Ruby script
require 'base64'
require 'cgi'
require 'time'

request_xml = <<~XML
  <samlp:AuthnRequest xmlns:samlp="urn:oasis:names:tc:SAML:2.0:protocol"
                       ID="_#{SecureRandom.uuid}"
                       Version="2.0"
                       IssueInstant="#{Time.now.utc.iso8601}"
                       Destination="http://localhost:3000/saml/auth"
                       AssertionConsumerServiceURL="http://localhost:4000/saml/acs">
    <saml:Issuer xmlns:saml="urn:oasis:names:tc:SAML:2.0:assertion">http://localhost:4000</saml:Issuer>
  </samlp:AuthnRequest>
XML

encoded = CGI.escape(Base64.strict_encode64(request_xml))
puts "http://localhost:3000/saml/auth?SAMLRequest=#{encoded}"
```

Visit the URL in your browser to test the IdP directly.

## Technical Details

Built with Rails 8, the `saml_idp` gem, and Phlex views. No database, no JavaScript (except auto-submit), completely stateless.

Key files:
- `config/initializers/saml_idp.rb` - SAML configuration and request-based URL detection
- `app/controllers/saml_idp_controller.rb` - Handles AuthnRequest and generates responses
- `app/controllers/metadata_controller.rb` - Serves SAML metadata XML
- `app/views/login_page.rb` - Login form with success/failure buttons
- `app/views/saml_response_form.rb` - Auto-submit form that POSTs response back to SP

To add custom SAML attributes, edit the `create` action in `SamlIdpController`:

```ruby
principal = {
  email: name_id,
  id: name_id,
  name: params[:name],
  department: "Engineering",  # Add custom attributes
  role: "Developer"
}
```

## Security

This is a development tool. Don't use it in production. It accepts requests from any service provider, auto-generates certificates, and has no authentication.

## License

MIT
