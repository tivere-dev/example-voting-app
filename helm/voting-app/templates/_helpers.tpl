{{/* Chart name and version, e.g. voting-app-0.1.0 */}}
{{- define "voting-app.chart" -}}
{{ printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Labels on every object. Call with (dict "root" $ "component" "vote").
*/}}
{{- define "voting-app.labels" -}}
helm.sh/chart: {{ include "voting-app.chart" .root }}
app.kubernetes.io/name: {{ .root.Chart.Name }}
app.kubernetes.io/instance: {{ .root.Release.Name }}
app.kubernetes.io/component: {{ .component }}
app.kubernetes.io/part-of: voting-app
app.kubernetes.io/managed-by: {{ .root.Release.Service }}
{{- end }}

{{/*
Labels a Service or Deployment uses to find its pods. These never change
between releases, because Kubernetes does not allow selectors to change.
*/}}
{{- define "voting-app.selectorLabels" -}}
app.kubernetes.io/name: {{ .root.Chart.Name }}
app.kubernetes.io/instance: {{ .root.Release.Name }}
app.kubernetes.io/component: {{ .component }}
{{- end }}

{{/*
Image for vote, result or worker. Call with (dict "root" $ "image" .Values.vote.image).
Uses the component's own tag if set, otherwise appImage.tag, and fails the
install if neither is set.
*/}}
{{- define "voting-app.appImage" -}}
{{- $tag := default .root.Values.appImage.tag .image.tag -}}
{{- $tag = required "appImage.tag is required (normally the git commit SHA)" $tag -}}
{{- if .root.Values.appImage.registry -}}
{{ printf "%s/%s:%s" .root.Values.appImage.registry .image.repository $tag }}
{{- else -}}
{{ printf "%s:%s" .image.repository $tag }}
{{- end -}}
{{- end }}

{{/*
Container security settings shared by every container: no privilege
escalation, no Linux capabilities, read-only root filesystem.
*/}}
{{- define "voting-app.containerSecurityContext" -}}
allowPrivilegeEscalation: false
readOnlyRootFilesystem: true
capabilities:
  drop: ["ALL"]
{{- end }}

{{/*
Pod security settings. Call with (dict "uid" 10001 "gid" 10001).
*/}}
{{- define "voting-app.podSecurityContext" -}}
runAsNonRoot: true
runAsUser: {{ .uid }}
runAsGroup: {{ .gid }}
{{- if .fsGroup }}
fsGroup: {{ .fsGroup }}
{{- end }}
seccompProfile:
  type: RuntimeDefault
{{- end }}
