{{/*
Expand the name of the chart.
*/}}
{{- define "cloudcluster.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "cloudcluster.fullname" -}}
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
{{- define "cloudcluster.labels" -}}
helm.sh/chart: {{ include "cloudcluster.name" . }}-{{ .Chart.Version | replace "+" "_" }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/part-of: cloudcluster-stack
{{- end }}

{{/*
Format image name with optional global registry or individual repository
Usage:
  {{ include "cloudcluster.image" (dict "image" .Values.flink.image "global" .Values.global) }}
*/}}
{{- define "cloudcluster.image" -}}
{{- $registry := "" -}}
{{- if and .image .image.registry -}}
  {{- $registry = .image.registry -}}
{{- else if and .global .global.imageRegistry -}}
  {{- $registry = .global.imageRegistry -}}
{{- end -}}
{{- if and $registry (not (hasPrefix (printf "%s/" $registry) .image.repository)) -}}
  {{- printf "%s/%s:%s" (trimSuffix "/" $registry) .image.repository .image.tag -}}
{{- else -}}
  {{- printf "%s:%s" .image.repository .image.tag -}}
{{- end -}}
{{- end -}}
