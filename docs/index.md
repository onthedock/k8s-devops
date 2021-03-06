# Kubernetes DevOps - Recomendaciones

## Una herramienta por *namespace*

Cada herramienta se despliega en su propio *namespace*.
El nombre del *namespace* no es relevante, aunque en general coincide con el nombre de la herramienta.

## Organización de la documentación

La documentación para cada herramienta se encuentra en una carpeta dentro de MkDocs. La documentación puede dividirse en múltiples ficheros si es necesario.

El fichero de despliegue de los recursos se encuentra en la subcarpeta `deploy/`.

Otros ficheros auxiliares o alternativos se pueden organizar en otras carpetas.

## Ramas

La rama `main` debe contener código comprobado y funcional (en la versión especificada en la documentación tanto de Kubernetes como de la herramienta específica).

Otras ramas contienen versiones en desarrollo, pruebas, etc.
