# SSO Configuration

This chart integrates Keycloak (via `keycloakx` sub-chart) for OIDC-based Single Sign-On with Open WebUI.

## How it works

1. On install/upgrade, a post-hook Job (`keycloak-config-cli`) imports `llm-stack-realm.json` into Keycloak.
2. The realm contains a pre-configured `open-webui` OIDC client.
3. The OIDC client secret is generated once (stable across upgrades) and stored in `{fullname}-secrets`.
4. Open WebUI reads this secret and the issuer URL to enable SSO login.

## Prerequisites

- An Ingress controller (e.g., nginx) with DNS pointing `auth.{domain}` at your cluster.
- cert-manager (optional, for TLS).
- Enough resources: Keycloak needs ~512Mi RAM.

## Production deployment

```yaml
# values.yaml overrides
global:
  domain: example.com

keycloak:
  enabled: true
  realmImport:
    enabled: true
  # adminPassword: ""   # leave empty — uses auto-generated secret

keycloakx:
  extraEnv: |
    - name: KEYCLOAK_ADMIN
      value: admin
    - name: KEYCLOAK_ADMIN_PASSWORD
      valueFrom:
        secretKeyRef:
          name: <fullname>-secrets     # e.g. llm-stack-secrets
          key: keycloakAdminPassword
    - name: KC_PROXY
      value: "edge"

open-webui:
  sso:
    enabled: true
    enableSignup: true
    oidc:
      enabled: true
      clientId: "open-webui"
      clientExistingSecret: "<fullname>-secrets"   # e.g. llm-stack-secrets
      clientExistingSecretKey: "oidcClientSecret"
      providerUrl: "https://auth.example.com/auth/realms/llm-stack"
      providerName: "Keycloak"
      scopes: "openid email profile"

ingress:
  enabled: true
  className: nginx
  tls:
    issuer: letsencrypt-prod
```

> **Note**: Replace `<fullname>` with `{releaseName}` if the release name contains `llm-stack`, otherwise `{releaseName}-llm-stack`.

## URL requirements

Open WebUI uses `providerUrl` for **both** server-side OIDC discovery and browser redirects. Therefore, this URL must be reachable from:

- Inside the cluster (Open WebUI pod → Keycloak)
- The user's browser (for the login redirect)

This means `providerUrl` must be the public, Ingress-exposed URL of Keycloak (`https://auth.{domain}/auth/realms/llm-stack`). **Without Ingress, the browser redirect will fail.**

## Realm structure

The auto-imported `llm-stack` realm contains:

| Object | Name | Purpose |
|--------|------|---------|
| Client | `open-webui` | OIDC client for Open WebUI |
| Role | `llm-user` | Granted to regular users |
| Role | `llm-admin` | Granted to administrators |
| Group | `llm-users` | Map users to `llm-user` role |
| Group | `llm-admins` | Map users to `llm-admin` role |

## Adding users

After install, log into the Keycloak admin console at `https://auth.{domain}/auth/admin`:

1. Select the `llm-stack` realm.
2. Go to **Users** → **Add user**.
3. Set username/email, go to **Credentials** tab, set a password.
4. Go to **Groups** tab, assign `llm-users` or `llm-admins`.

## External OIDC (no Keycloak)

To use an external identity provider instead:

```yaml
keycloak:
  enabled: false

oidc:
  external:
    enabled: true
    issuerUrl: "https://your-idp.example.com/realms/your-realm"
    clientId: "open-webui"
    clientSecret: "your-client-secret"
```

## Secret stability

The `oidcClientSecret` and `keycloakAdminPassword` are generated once on the first install and preserved across all subsequent upgrades via a Helm `lookup` in `secret.yaml`. You can also pin them explicitly:

```yaml
secrets:
  oidcClientSecret: "your-32-char-secret"
  keycloakAdminPassword: "your-admin-password"
```

## CI / local testing

In `ci/kind-values.yaml`, Keycloak and Open WebUI are configured with the internal cluster URL as `providerUrl`. The realm import job succeeds (tested), but the browser SSO redirect cannot complete without Ingress — this is expected for local kind clusters.
