# Monitorización con el operador de Prometheus

Referencia: [Introduction to the Prometheus Operator on Kubernetes](https://youtu.be/LQpmeb7idt8)

La manera tradicional de desplegar Prometheus es crear un *namespace*, desplegar Prometheus mediante un *deployment*, que desplega un *pod* de Prometheus (porque especificamos `1` como número de réplicas).

Prometheus se configura a través de un *configMap* en el que se *apunta* a todos los recursos que queremos monitorizar. Esto significa que el fichero de configuración de Prometheus crece rápidamente y de forma monolítica. Esto lleva a que el pod de monitorización de Prometheus requiera una gran cantidad de recursos para poder realizar el monitorizado de todos los recursos en los que estamos interesados, llegando a convertirse en un *cuello de botella*.

Sin embargo, Prometheus se diseñó como una herramienta de monitorización distribuida, por lo que no sería descabellado incluso desplegar un Prometheus por *namespace*, o quizás uno para monitorizar los recursos del clúster y otro para los microservicios desplegados, etc...

El problema en este caso es la gestión de los múltiples ficheros de configuración de todas las instancias de Prometheus.

## Prometheus Operator

Aquí es donde aparece el **operador* de Prometheus, que se encarga de gestionar los *configMaps* de las diferentes instancias de Prometheus desplegadas en el clúster.

Al desplegar el operador de Prometheus, se generan en el clúster un *CRD* (*custom resource definitions*) de tipo `Prometheus`.

De esta forma, cuando creamos un *namespace*, podemos indicar que queremos una instancia de Prometheus y el operador se encarga de desplegar un *service account*, la instancia de Prometheus, etc. En este caso, en vez de configurar los *endpoints* que queremos monitorizar unos determinados servicios (por ejemplo, la API de Kubernetes, etc)

Otro componente que se introduce es el *Service Monitor*; definimos un *service monitor* para cada grupo de servicios que queremos monitorizar. Estos grupos se definen usando los selectores típicos de Kubernetes, mediante etiquetas para identifican los servicios monitorizados por el *service monitor*.

De esta forma, la configuración de Prometheus consiste en identificar de qué *service monitors* debe obtener información (usando *selectors* basados en etiquetas) que a su vez seleccionan los servicios a monitorizar (también usando etiquetas).

Así, cuando desplegamos un microservicio, podemos etiquetarlo para indicar que debe ser monitorizado por un *service monitor* y por una determinada instancia de Prometheus que se va a encargar de monitorizarlo. De esta forma podemos gestionar la monitorización de un gran número de microservicios de forma sencilla.

