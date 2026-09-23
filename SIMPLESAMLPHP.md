# SimpleSAMLphp test IdP

This Compose setup runs a separate SimpleSAMLphp IdP for SAML 2.0 browser SSO.
It uses an emailAddress NameID and a signing certificate generated on your machine.
The Docker image is pinned to the version used to verify this setup.

## First-time setup

Run these commands from the repository root. Docker Compose, Bash, and OpenSSL are required.

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

2. Generate the initial signing certificate and private key:

   ```sh
   bash bin/saml-cert
   ```

   This generates and verifies a new RSA-3072 key and a certificate valid for 365
   days. It refuses to overwrite an existing key or certificate. The host
   directories are private; individual read-only file mounts allow Apache to
   read the files. `.saml-local/`, including keys and backups, is ignored by Git.

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

## Renewing the signing certificate

Run the following from the repository root when the certificate expires or you
want to replace the signing key:

```sh
bash bin/saml-cert --renew
docker compose up -d --force-recreate idp
```

The script validates the replacement pair before touching the installed files.
It moves the previous pair into a unique directory under
`.saml-local/cert-backups/`, prints that location, and installs the new pair.
Generation failures leave the old pair untouched; an installation failure
restores it. Concurrent certificate operations are rejected with a lock.

Force-recreate the container after success: Docker's individual file bind mounts
can still reference the old files after replacement. A plain restart may continue
serving the old signing certificate.

Download the SAML 2.0 metadata again and replace the SP's imported metadata. Verify
that its signing certificate matches the new certificate, then initiate a fresh
login from the SP. The old imported certificate will not validate new signatures.

To roll back a completed renewal, use the exact backup directory printed by the
script. Stop the IdP, preserve the current pair, restore the backed-up `cert`
directory to `.saml-local/cert`, and force-recreate the container. Import matching
metadata in the SP if its trusted certificate was already updated.

## Checking certificate management changes

```sh
bash tests/saml-cert.sh
```

This test generates disposable certificates in a temporary directory. It checks
initial generation, refusal to overwrite, new key generation during renewal,
exact backups, failure recovery, and the concurrency guard. It never changes the
active developer certificate.

Use this setup for development and testing only.
