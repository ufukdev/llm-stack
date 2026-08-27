{{/*
Expand the name of the chart.
*/}}
{{- define "llm-stack.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "llm-stack.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "llm-stack.labels" -}}
helm.sh/chart: {{ include "llm-stack.chart" . }}
{{ include "llm-stack.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "llm-stack.selectorLabels" -}}
app.kubernetes.io/name: {{ include "llm-stack.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Chart label
*/}}
{{- define "llm-stack.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Keycloak internal service base URL (no context path).
The keycloakx chart produces a service named <release>-keycloakx-http.
Verified against keycloakx chart templates in T2.
*/}}
{{- define "llm-stack.keycloakInternalUrl" -}}
{{- printf "http://%s-keycloakx-http.%s.svc.cluster.local:80" (include "llm-stack.fullname" .) .Release.Namespace }}
{{- end }}

{{/*
Keycloak internal URL including the /auth context path.
keycloakx chart sets KC_HTTP_RELATIVE_PATH=/auth by default.
*/}}
{{- define "llm-stack.keycloakAuthUrl" -}}
{{- printf "%s/auth" (include "llm-stack.keycloakInternalUrl" .) }}
{{- end }}

{{/*
OIDC issuer URL — either external or Keycloak-managed.
For Keycloak, this is the realm URL (includes /auth context path).
Used only for INTERNAL backend-to-Keycloak calls (token exchange, JWKS).
*/}}
{{- define "llm-stack.oidcIssuerUrl" -}}
{{- if .Values.oidc.external.enabled }}
{{- .Values.oidc.external.issuerUrl }}
{{- else }}
{{- printf "%s/realms/llm-stack" (include "llm-stack.keycloakAuthUrl" .) }}
{{- end }}
{{- end }}

{{/*
Keycloak public-facing base URL (no /auth context path, no realm).
When global.domain is set, Keycloak is exposed at auth.<domain>.
This is set as KC_HOSTNAME_URL so Keycloak embeds this URL in its
discovery document regardless of the incoming Host header — which
allows the browser to follow the authorization_endpoint redirect even
when Open WebUI fetches discovery via the internal service address.
When global.domain is empty (local port-forward), returns empty string
and KC_HOSTNAME_URL is left unset (Keycloak falls back to request host).
*/}}
{{- define "llm-stack.keycloakFrontendUrl" -}}
{{- if .Values.global.domain }}
{{- $scheme := "http" }}
{{- if or .Values.ingress.tls.keycloakSecretName .Values.ingress.tls.issuer }}
{{- $scheme = "https" }}
{{- end }}
{{- printf "%s://auth.%s" $scheme .Values.global.domain }}
{{- end }}
{{- end }}

{{/*
Name of the shared secret object.
*/}}
{{- define "llm-stack.secretName" -}}
{{- printf "%s-secrets" (include "llm-stack.fullname" .) }}
{{- end }}

{{/*
Generate a random alphanumeric string and keep it stable across upgrades
by looking up any previously set value first.
Usage: {{ include "llm-stack.persistedSecret" (dict "root" . "key" "myKey" "length" 32) }}
*/}}
{{- define "llm-stack.persistedSecret" -}}
{{- $existing := lookup "v1" "Secret" .root.Release.Namespace (printf "%s-secrets" (include "llm-stack.fullname" .root)) }}
{{- if and $existing $existing.data (index $existing.data .key) }}
{{- index $existing.data .key | b64dec }}
{{- else }}
{{- randAlphaNum (.length | int) }}
{{- end }}
{{- end }}
