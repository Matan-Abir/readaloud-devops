{{- define "readaloud.name" -}}{{ .Chart.Name }}{{- end -}}

{{- define "readaloud.fullname" -}}
{{- if contains .Chart.Name .Release.Name -}}
{{ .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else -}}
{{ printf "%s-%s" .Release.Name .Chart.Name | trunc 63 | trimSuffix "-" }}
{{- end -}}
{{- end -}}

{{- define "readaloud.labels" -}}
helm.sh/chart: {{ .Chart.Name }}-{{ .Chart.Version }}
app.kubernetes.io/part-of: readaloud
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/version: {{ .Values.backend.image.tag | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end -}}

{{- define "readaloud.backendSelector" -}}
app.kubernetes.io/name: {{ include "readaloud.name" . }}-backend
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

{{- define "readaloud.postgresSelector" -}}
app.kubernetes.io/name: {{ include "readaloud.name" . }}-postgres
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

{{- define "readaloud.secretName" -}}
{{- if .Values.secrets.existingSecret -}}
{{ .Values.secrets.existingSecret }}
{{- else -}}
{{ include "readaloud.fullname" . }}-secret
{{- end -}}
{{- end -}}

{{- define "readaloud.postgresHost" -}}{{ include "readaloud.fullname" . }}-postgres{{- end -}}

{{- /* Secret-backed env for the backend; DATABASE_URL is assembled from them. */ -}}
{{- define "readaloud.backendEnv" -}}
- name: POSTGRES_PASSWORD
  valueFrom:
    secretKeyRef:
      name: {{ include "readaloud.secretName" . }}
      key: POSTGRES_PASSWORD
- name: JWT_SECRET_KEY
  valueFrom:
    secretKeyRef:
      name: {{ include "readaloud.secretName" . }}
      key: JWT_SECRET_KEY
- name: GEMINI_API_KEY
  valueFrom:
    secretKeyRef:
      name: {{ include "readaloud.secretName" . }}
      key: GEMINI_API_KEY
      optional: true
- name: DATABASE_URL
  value: "postgresql://$(POSTGRES_USER):$(POSTGRES_PASSWORD)@$(POSTGRES_HOST):5432/$(POSTGRES_DB)"
{{- end -}}
