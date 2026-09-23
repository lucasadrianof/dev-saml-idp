# SimpleSAMLphp test IdP

This Compose setup runs a separate SimpleSAMLphp IdP for SAML 2.0 browser SSO.
It uses an emailAddress NameID and a signing certificate generated on your machine.
The Docker image is pinned to the version used to verify this setup.

## First-time setup

Run these commands from the repository root. Docker Compose and OpenSSL are required.

1. Create your local settings and test users:

   ```sh
   cp .env.example .env
   cp authsources.example.php authsources.php
   ```

   Edit `.env` with your IdP's public base URL and the exact SP entity ID and ACS
   URL from your application. For a tunnel, the base URL must be
   `https://YOUR-TUNNEL-HOST/simplesaml/`, including the path and trailing slash.
   For direct local HTTP testing, use `http://localhost:8080/simplesaml/`.

   Edit the `username:password` entry and its `email` attribute in `authsources.php`.
   The email must match the user your application expects. Both files are ignored
   by Git; the committed example contains dummy credentials only.

2. Generate a signing certificate and private key. Run this only on first setup;
   replacing an existing key requires updating the metadata in your SP:

   ```sh
   mkdir -p .saml-local/cert
   chmod 700 .saml-local .saml-local/cert
   test ! -e .saml-local/cert/server.pem &&
   test ! -e .saml-local/cert/server.crt &&
   openssl req -x509 -newkey rsa:3072 -sha256 -nodes -days 365 \
     -subj '/CN=Local SAML Test IdP' \
     -keyout .saml-local/cert/server.pem \
     -out .saml-local/cert/server.crt
   chmod 644 .saml-local/cert/server.pem .saml-local/cert/server.crt
   ```

   The host directories are private. Individual read-only file mounts let Apache
   read the certificate and key inside the container. `.saml-local/`, including
   keys and any rollback copies, is ignored by Git.

3. Start the IdP:

   ```sh
   docker compose up -d
   ```

   Port 8080 is bound to the host loopback interface. Point a host-side tunnel at
   `http://localhost:8080` when testing with a public HTTPS hostname. If a previous
   standalone `docker run` container named `test-saml-idp` exists, back up its
   configuration and remove that container before starting Compose.

4. Download the **SAML 2.0** IdP metadata and import it into your SP:

   ```text
   https://YOUR-TUNNEL-HOST/simplesaml/saml2/idp/metadata.php?output=xml
   ```

   Start a fresh login from the SP. The IdP SSO endpoint is
   `/simplesaml/saml2/idp/SSOService.php`. Do not use the legacy `/shib13/` metadata
   or SSO endpoint; it speaks a different protocol and can fail with
   `Missing providerId parameter` when sent a SAML 2.0 request.

## Assertion settings

`saml20-idp-hosted.php` reads the NameID value from the user's `email` attribute
and advertises only:

```text
urn:oasis:names:tc:SAML:1.1:nameid-format:emailAddress
```

The `1.1` in this identifier is correct for an emailAddress NameID used with
SAML 2.0. The pinned image signs responses and assertions by default.

The IdP derives its entity ID and endpoint URLs from `SIMPLESAMLPHP_IDP_BASE_URL`.
For HTTPS tunnels, this prevents the internal HTTP connection from producing an
HTTP issuer that differs from the one trusted by the SP. `saml20-sp-remote.php`
reads the SP entity ID and ACS URL from the two corresponding environment settings.

## Updating local settings

After changing the tunnel hostname or another `.env` value, run
`docker compose up -d` to recreate the container with the new environment.
Re-import the generated metadata into the SP whenever the IdP URL or signing
certificate changes, then begin a fresh login from the SP.

The signing certificate lasts 365 days. Inspect its dates with:

```sh
openssl x509 -in .saml-local/cert/server.crt -noout -dates
```

Use this setup for development and testing only.
