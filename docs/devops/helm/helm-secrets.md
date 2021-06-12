# Generar *Secrets* seguros usando Helm

Helm permite usar funciones, como por ejemplo, `randAlphaNum` que generan una cadena alfanumérica de la longitud indicada. En combinación con otras funciones como `b64enc` y `quote` podemos generar contraseñas seguras para la comunicación entre diferentes componentes de la aplicación (contraseñas que nadie más necesita conocer).

El problema es las funciones de las *Charts* de Helm se ejecutan no sólo cuando hacemos un despliegue de la aplicación, sino también cuando actualizamos...

En Helm 3.1 se introdujo la función `lookup` que permite consultar si un determinado recurso existe en el *Deployment* y devolver su valor si es así.

Usando la función `lookup` y basándome en el artículo de la sección de referencias, se puede definir un *Secret* que se genere dinámicamente durante la instalación de la *Chart* pero que no se modifique en las sucesivas actualizaciones:

```yaml
# Check if secret already exists and return it in the $secret variable
{{- $secret := (lookup "v1" "Secret" .Release.Namespace "{{ .Release.Name }}-secret") -}}
apiVersion: v1
kind: Secret
metadata:
  name: {{ .Release.Name }}-secret
type: Opaque

{{ if $secret -}}
data:
  admin_password: {{ $secret.data.admin_password }}
  config_password: {{ $secret.data.config_password }}
  readonly_user: {{ $secret.data.readonly_user }}
  readonly_password: {{ $secret.data.readonly_password }}
{{ else -}}
data:
  admin_password: {{ randAlphaNum 12 | b64enc | quote  }}
  config_password: {{ randAlphaNum 12 | b64enc | quote  }}
  readonly_user: {{ randAlphaNum 12 | b64enc | quote }}
  readonly_password: {{ randAlphaNum 12 | b64enc | quote }}
{{- end }}
```

## Validación

TBD

## Referencia

- [Auto-Generated Helm Secrets](https://wanderingdeveloper.medium.com/reusing-auto-generated-helm-secrets-a7426403d4bb), 15/04/2020
