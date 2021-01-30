# Nueva aplicación en Argo CD (WIP)

## Usando la interfaz gráfica

En la sección *General*:

1. Pulsa el botón *+ New App*
1. *Application Name* Debe ser un nombre DNS válido (todo minúsculas, etc)
1. *Project* El nombre del proyecto en Argo CD (por defecto, `default`)
1. *Sync policy* Si seleccionas `Automatic`, cada vez que Argo CD detecta que hay cambios, Argo CD redespliega el contenido del repositorio. De momento, dejamos `Manual`
1. *Sync options* Dejamos las opciones por defecto.

En la sección *Source*

1. *Repository URL* Elige el repositorio confiurado en la sección anterior del desplegable (o introduce uno nuevo). El repositorio puede ser de tipo `Git` (opción por defecto) o `Helm` (elige del desplegable a la derecha de la URL del repositorio)
1. *Revision* `HEAD` (por defecto). Podemos especificar un *tag* de versión en git o el SHA de un *commit*. (Ver [Tracking and Deployment Strategies](https://argoproj.github.io/argo-cd/user-guide/tracking_strategies/#git) en la documentación de Argo CD).
1. *Path* La ruta dentro del repositorio en la que se encuentran los ficheros YAML para desplegar los recursos asociados a la aplicación. Por ejemplo `maildev/src`.

En la sección *Destination*

1. *Cluster URL* Elige el clúster donde desplegar la aplicación del desplegable.
1. *Namespace* El *namespace* de destino donde desplegar la aplicación. Por ejemplo `toolbox`.

En la sección *Directory*

1. *Directory recurse* Si los ficheros YAML se encuentran en varios niveles anidados de carpetas, marca la casilla.

### Sincronización de la aplicación

Pulsando el botón *Sync* podemos forzar la sincronización entre el estado deseado descrito en los ficheros del repositorio y el estado actual en el clúster.

* *Prune* Elimina los recursos que no estén presentes en el repositorio
* *Dry run* Realiza una simulación, sin aplicar los cambios

Podemos aplicar la sincronización a todos los objetos, sólo a los que estén desincronizados o a ninguno.
