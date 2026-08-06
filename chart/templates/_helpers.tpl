{{/*
Expand the name of the chart.
*/}}
{{- define "keycloak.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "keycloak.fullname" -}}
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
Chart name and version label.
*/}}
{{- define "keycloak.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels.
*/}}
{{- define "keycloak.labels" -}}
helm.sh/chart: {{ include "keycloak.chart" . }}
{{ include "keycloak.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels.
*/}}
{{- define "keycloak.selectorLabels" -}}
app.kubernetes.io/name: {{ include "keycloak.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Name of the Secret holding POSTGRES_PASSWORD.
*/}}
{{- define "postgres.secretName" -}}
{{- if .Values.postgres.existingSecret }}
{{- .Values.postgres.existingSecret }}
{{- else }}
{{- include "keycloak.fullname" . }}
{{- end }}
{{- end }}

{{/*
Key within the Secret holding POSTGRES_PASSWORD.
*/}}
{{- define "postgres.secretKey" -}}
{{- if .Values.postgres.existingSecret }}
{{- .Values.postgres.existingSecretKey | default "POSTGRES_PASSWORD" }}
{{- else }}
{{- "POSTGRES_PASSWORD" }}
{{- end }}
{{- end }}

{{/*
Name of the Secret holding KEYCLOAK_PASSWORD.
*/}}
{{- define "keycloak.secretName" -}}
{{- if .Values.keycloak.existingSecret }}
{{- .Values.keycloak.existingSecret }}
{{- else }}
{{- include "keycloak.fullname" . }}
{{- end }}
{{- end }}

{{/*
Key within the Secret holding KEYCLOAK_PASSWORD.
*/}}
{{- define "keycloak.secretKey" -}}
{{- if .Values.keycloak.existingSecret }}
{{- .Values.keycloak.existingSecretKey | default "KEYCLOAK_PASSWORD" }}
{{- else }}
{{- "KEYCLOAK_PASSWORD" }}
{{- end }}
{{- end }}

{{/*
Claim name for a given persistence volume (etc).
*/}}
{{- define "keycloak.claimName" -}}
{{- $root := index . 0 }}
{{- $vol := index . 1 }}
{{- $cfg := index $root.Values.persistence $vol }}
{{- if $cfg.existingClaim }}
{{- $cfg.existingClaim }}
{{- else }}
{{- printf "%s-%s" (include "keycloak.fullname" $root) $vol }}
{{- end }}
{{- end }}