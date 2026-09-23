#!/usr/bin/env bash
set -euo pipefail

repo_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)
work=$(mktemp -d "${TMPDIR:-/tmp}/saml-cert-test.XXXXXX")
trap 'rm -rf -- "$work"' EXIT
mkdir -p "$work/repo/bin"
cp "$repo_dir/bin/saml-cert" "$work/repo/bin/saml-cert"
script="$work/repo/bin/saml-cert"
cert="$work/repo/.saml-local/cert"

fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }
expect_failure() {
    if "$@" >"$work/expected-failure.log" 2>&1; then fail "Expected command to fail: $*"; fi
}
validate_pair() {
    openssl pkey -in "$cert/server.pem" -check -noout >/dev/null
    openssl x509 -in "$cert/server.crt" -checkend 31449600 -noout >/dev/null
    local key_public cert_public
    key_public=$(openssl pkey -in "$cert/server.pem" -pubout -outform DER | openssl dgst -sha256)
    cert_public=$(openssl x509 -in "$cert/server.crt" -pubkey -noout | openssl pkey -pubin -outform DER | openssl dgst -sha256)
    [[ "$key_public" == "$cert_public" ]] || fail 'Key and certificate differ'
}

expect_failure bash "$script" --renew
bash "$script" >"$work/init.log"
validate_pair
cp "$cert/server.pem" "$work/original.pem"
cp "$cert/server.crt" "$work/original.crt"
expect_failure bash "$script"
cmp "$cert/server.pem" "$work/original.pem"
cmp "$cert/server.crt" "$work/original.crt"

bash "$script" --renew >"$work/renew.log"
validate_pair
if cmp -s "$cert/server.pem" "$work/original.pem"; then fail 'Renewal reused the old private key'; fi
if cmp -s "$cert/server.crt" "$work/original.crt"; then fail 'Renewal reused the old certificate'; fi
backups=("$work/repo/.saml-local/cert-backups/"*/cert)
[[ ${#backups[@]} == 1 ]] || fail 'Expected exactly one backup'
cmp "${backups[0]}/server.pem" "$work/original.pem"
cmp "${backups[0]}/server.crt" "$work/original.crt"

# A failed OpenSSL invocation must not replace either installed file.
cp "$cert/server.pem" "$work/current.pem"
cp "$cert/server.crt" "$work/current.crt"
mkdir "$work/failing-bin"
printf '#!/usr/bin/env bash\nexit 1\n' >"$work/failing-bin/openssl"
chmod +x "$work/failing-bin/openssl"
expect_failure env PATH="$work/failing-bin:$PATH" bash "$script" --renew
cmp "$cert/server.pem" "$work/current.pem"
cmp "$cert/server.crt" "$work/current.crt"
[[ ! -e "$work/repo/.saml-local/.cert-lock" ]] || fail 'Lock leaked after failure'

# A failed installation must restore the previous directory from its backup.
real_mv=$(command -v mv)
mkdir "$work/failing-install-bin"
cat >"$work/failing-install-bin/mv" <<'SH'
#!/usr/bin/env bash
for arg in "$@"; do
    case "$arg" in */.cert-new.*) exit 1 ;; esac
done
exec "$SAML_TEST_REAL_MV" "$@"
SH
chmod +x "$work/failing-install-bin/mv"
expect_failure env PATH="$work/failing-install-bin:$PATH" SAML_TEST_REAL_MV="$real_mv" bash "$script" --renew
cmp "$cert/server.pem" "$work/current.pem"
cmp "$cert/server.crt" "$work/current.crt"
[[ ! -e "$work/repo/.saml-local/.cert-lock" ]] || fail 'Lock leaked after rollback'

# An existing lock must reject a second operation without deleting that lock.
mkdir "$work/repo/.saml-local/.cert-lock"
expect_failure bash "$script" --renew
[[ -d "$work/repo/.saml-local/.cert-lock" ]] || fail 'Removed another operation lock'
cmp "$cert/server.pem" "$work/current.pem"
cmp "$cert/server.crt" "$work/current.crt"
rmdir "$work/repo/.saml-local/.cert-lock"

printf 'PASS: initial generation, overwrite protection, renewal, exact backups, generation failure, installation rollback, and concurrent-operation guard.\n'
