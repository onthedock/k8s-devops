# Conceptos generales de Kubernetes

El objetivo de esta sección es describir los diferentes objetos y el papel que juegan en un clúster de Kubernetes.

La mayoría de los ficheros de definición de los recursos en Kubernetes, en formato YAML, tienen 4 secciones generales:

- `kind` Especifica el tipo de recurso. Por ejemplo `Pod`, `Job`, `Deployment` o `Service`.
- `apiVersion` Versión de la API que gestiona el recurso.
- `metadata` En general contiene el nombre del recurso. Puede contener anotaciones, etiquetas, etc que proporcionan información adicional sobre el recurso.
- `spec` Contiene la definición y características del recurso.
