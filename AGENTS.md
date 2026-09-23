# Working in this repository

## Local SAML setup

For requests to set up or renew a local SAML IdP, read [SIMPLESAMLPHP.md](SIMPLESAMLPHP.md)
first. Use the SimpleSAMLphp Compose setup unless the user specifically requests
the original Rails implementation.

- Inspect `.env`, `authsources.php`, `.saml-local/cert/`, and the running container
  before changing an existing setup. Preserve working users, URLs, and certificates.
- For a fresh checkout, copy `.env.example` and `authsources.example.php` only when
  their local counterparts are absent. Ask for missing SP entity ID, ACS URL, IdP
  public URL, and test identity details instead of inventing production values.
- Generate the initial certificate with `bash bin/saml-cert`. For requested renewal
  or replacement of an expired signing certificate, use `bash bin/saml-cert --renew`.
  This creates a new key and certificate and backs up the previous pair. Do not
  rotate an unexpired certificate just because someone asks to start the service.
- After renewal, run `docker compose up -d --force-recreate idp`. Individual file
  bind mounts can retain the old files after replacement; a restart is insufficient.
- Download the SAML 2.0 metadata from the configured public base URL plus
  `saml2/idp/metadata.php?output=xml`. Have the SP import the new metadata after
  changing the issuer or certificate. If the SP cannot be accessed, clearly state
  that the metadata import and end-to-end login are still pending.

## Configuration and verification

- Behind an HTTPS tunnel, set `SIMPLESAMLPHP_IDP_BASE_URL` to the external HTTPS URL
  including `/simplesaml/` and the trailing slash. Preserve the exact SP entity ID
  and ACS URL supplied by the application.
- Use `/saml2/` endpoints, not the legacy `/shib13/` endpoints.
- Keep the NameID format exactly
  `urn:oasis:names:tc:SAML:1.1:nameid-format:emailAddress`, populated from `email`.
  The `1.1` in this identifier is correct with the SAML 2.0 protocol.
- Keep response and assertion signing enabled. Never disable signature or issuer
  validation to make a failed login pass. XML namespace and signature algorithm
  identifiers may legitimately start with `http://`; do not blanket-replace them.
- Verify `docker compose config --quiet`, certificate validity, the advertised
  signing certificate, issuer, SSO URL, and NameID format in the served metadata.
  After SP import, start a fresh login and verify the return to the application.
  Distinguish a successful metadata/signature check from a completed browser login.

## Changes and publishing

- Never commit `.env`, `authsources.php`, `.saml-local/`, private keys, or local user
  credentials. Keep only dummy values in committed example files.
- Run `bash tests/saml-cert.sh` when changing certificate management. It exercises
  disposable copies and must not rotate the active developer certificate.
- Use semantic commits, for example `feat(saml): add certificate renewal`.
- Write documentation in English. Push to the personal fork's `origin`, keep the
  original repository as `upstream`, and use `git push -u origin <branch>`.
