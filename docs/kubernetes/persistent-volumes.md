# Volúmenes persistentes

El subsistema de *PersistentVolume* proporciona una API a usuarios y a administradores que les permite abstraerse de los detalles de cómo se provisiona el almacenamiento y cómo se consume.

Para ello, se proporcionan dos objetos: el *PersistentVolume* y el *PersistentVolumeClaim*.

Un *PersistenVolume* proporciona una determinada cantidad de almacenamiento. El volumen puede haber sido provisionado por un administrador o creado de forma dinámica usando *Storage Classes*. Es un recurso del clúster (no está asociado a un *namespace*) y tiene un ciclo de vida diferente al de cualquier pod que use el *PersistentVolume*. El objeto de la API captura los detalles de la implementación del almacenamiento.

El *PersistentVolumeClaim* (*PVC*) es una petición de almacenamiento por parte de un usuario. En la petición se indica el tamaño y el tipo de acceso  (`ReadWirteOnce`, `ReadWriteMany` o `ReadOnlyMany`).

Los usuarios pueden necesitar diferentes tipos de almacenamiento, con diferentes propiedades o rendimiento. En vez de exponer los detalles de implementación, se definen *StorageClasses*.

## Ciclo de vida de un volumen y un *claim*

Los PV son recursos del clúster. Los PVCs son peticiones de esos recursos y además actúan como una reserva del recursos. La interacción entre PVs y PVCs sigue el siguiente ciclo:

### Provisionado

Hay dos formas de provisionar los PVs: de forma estática o dinámica.

#### Provisionado estático

El administrador del clúster crea un determinado número de PVs. Los *PersistentVolume*s existen en la API de Kubernetes donde están disponibles para ser consumidos.

#### Provisionamiento dinámico

El clúster puede crear de forma dinámica un *PersistentVolume* si ninguno de los existentes permite satisfacer las necesidades indicadas en un *PersistentVolumeClaim*. La creación del volumen se realiza usando los detalles contenidos en la *StorageClass*; así, el PVC solicita un determinado tipo de almacenamiento indicando una *StorageClass*; el administrador crea la *StorageClass* para que se pueda provisionar el almacenamiento de forma dinámica. (Si el PVC indica una *StorageClass* "", se deshabilita el provisionado dinámico).

Si hay más de una *StorageClass* definida en el clúster, el administrador puede seleccionar una de ellas como la *DefaultStorageClass* en el *admission controller* del servidor de la API.

### *Binding* (asociación)

Cuando el usuario solicita una determinda cantidad de almacenamiento, el bucle de control que observa los PVCs busca un PV que satisfaga las necesidades del PVC (si es posible); si se ha habilitado el provisionamiento dinámico, se crea un PV que cumple los requerimientos del PVC.

Por tanto, el usuario siempre recibe como mínimo la cantidad requerida, aunque en el caso del provisionamiento estático, es posible que el volumen proporcione mayor cantidad de almacenaje de la requerida.

El controlador asocia el PV y el PVC de forma exclusiva, de forma que existe una relación de uno a uno entre PV y PVC, independientemente de cómo se ha creado el PV.

Los *claims* permanecen sin vincular mientras no exista un PV que cumpla con la petición de recursos indicada en el PVC. Los PV se vinculan con los PVC a medida que se encuentran disponibles.

### Uso

Los Pods usan los *claims* como si fueran volúmenes. El clúster inspecciona el *claim* para encontrar el volumen vinculado (*bound*) y montarlo en el Pod. Para aquellos volúmenes que soportan diferentes modos de acceso, el usuario indica el modo deseado a través del *claim*.

En cuanto un usuario tiene un *claim* y el *claim* se vincula, el PV asociado pertenece al usuario mientras lo necesite. Los usuarios despliegan Pods y acceden a los PVs vinculados a través de la sección `persistenVolumeClaim` de la sección `volumes` de la definición del Pod.

## Protección de los objetos de almacenamiento en uso

Esta protección evita que se eliminen los PVCs en uso por parte de un Pod o los PVs asociados a un PVC. Si un administrador elimina un PV asociado a un PVC, el *PersistentVolume* no se elimina inmediatamente; su eliminación se postpone hasta que el PV no está en uso por el PVC.

Para comprobar que el PVC está protegido cuando el estado del PVC es `Terminating` y en la lista de *Finalizers* aparece `kubernetes.io/pvc-protection`. Lo mismo ocurre para el PV cuando en estado `Terminating`, que muestra `kubernetes.io/pv-protection` en los *Finalizers*.

## Recuperando el espacio

Cuando un usuario ha dejado de usar un volumen, puede borrar el objeto PVC de la API, lo que permite recuperar el almacenamiento asociado al volumen. La política de recuperación en un *PersistentVolume* indica al clúster qué hacer con el volumen una vez que se ha liberado del *claim*.

Los volúmenes pueden conservarse (`Retained`), reciclarse (`Recycled`) o borrase (`Deleted`).

### `Retain`

La *reclaim policy* `Retain` permite la recuperación del almacenamiento de forma manual. Cuando el PVC se borra, el PV todavía existe y el volumen se considera *released*. Pero todavía no está disponible para que se asocie a otro *claim* porque los datos del anterior *claim* todavía se encuentran en el volumen. Un administrador puede reclamar manualmente el volumen siguiendo los pasos:

1. Borrar el *PersistentVolume*. El almacenamiento asociado todavía existe como un elemento de la infraestructura externa (por ejemplo, un volumen EBS) cuando se borra el *PersistentVolume*.
1. Eliminar manualmente los datos en el elemento de almacenamiento correspondiente.
1. Eliminar manualmente el elemento de almacenamiento, o si queremos reutilizarlo, crear un nuevo *PersistentVolume* que haga referencia al mismo elemento de almacenamiento.

### `Delete`

Para aquellos *plugins* que soporte la política `Delete`, el borrado elimina tanto el objeto *PersistentVolume* de Kubernetes como el elemento de almacenamiento asociado en la infraestructura externa. Los volúmenes que se han provisionado de manera dinámica heredan la *reclaim policy* de la *StorageClass* a la que pertenecen, que por defecto es `Delete`.

### `Recycle`

Esta *reclaim policy* está **deprecated**.

## Reservando un *PersistentVolume*

El *Control Plane* asocia los *PersistentVolumeClaim* con el *PersistentVolume* en el clúster. Si queremos asociar un PVC a un PV específico, tenemos que *pre-asociarlos* (*pre-bind*).

Al especificar un *PersistentVolume* en un *PersistentVolumeClaim* declaras el *binding* entre el PV y el PVC. Si el PV existe y no está reservado por un PVC en su campo `claimRef`, entonces el PV y el PVC se *enlazan*.

Este *binding* se realiza pese a que no coincidan algunos criterios, como el *node affinity*. El *Control Plane* sí revisa que la *storage class*, el *access mode* y la cantidad de almacenamiento sean adecuados.

Este método no garantiza ningún privilegio sobre el *PersistentVolume*. Si otro PVC puede usar el PV que especificas, es necesario reservar el volumen, especificando el nombre del PVC en el campo `claimRef` del PV para evitar que se asocie a otro PVC.

```yaml
apiVersion: v1
kind: PersistentVolume
metadata:
  name: foo-pv
spec:
  storageClassName: ""
  claimRef:
    name: foo-pvc
    namespace: foo
  ...
```

## Expandir *Persistent Volume Claims*

> Kubernetes v1.11 [beta]

Si el volumen incluye la opción `allowVolumeExpansion: true`, para los *plugins* que lo soportan, es posible editar el PVC y especificar un tamaño mayor. Esto lanza el cambio de tamaño del volume que soporta el *PersistentVolume*. En vez de crear un nuevo PV, se cambia el tamaño del PV existente.

## *Persistent Volumes*

Cada objeto *PersistentVolume* contiene una sección *spec* y *status*. El nombre del objeto *PersistentVolume* debe ser un nombre de subdominio DNS válido.

### Capacidad

En general, un PV proporciona una capacidad de almacenamiento específica según se especifica en el atributo `capacity`. En general, este atributo es el único que puede solicitarse. En el futuro se podrá especificar el número de IOPS, *throughput*, etc.

### *Volume Mode*

> Kubernetes 1.18 [stable]

Kubernetes soporta dos tipos de *volumeModes* `Filesystem` y `Block`. `volumeMode` es un parámetro opcional de la PAI. Por defecto, si no se especifica, se asume `Filesystem` por defecto.

Un volumen con el `volumeMode: Filesystem` se *monta* como una carpeta dentro del Pod. Si el volumen está respaldado por un dispositivo de bloque y el dispositivo está vacío, Kubernetes crea un sistema de ficheros en el dispositivo antes de montarlo por primera vez.

Si se especifica como `Block`, Kubernetes presenta el volumen en el Pod sin sistema de ficheros, por lo que la aplicación corriendo en el Pod tiene que saber cómo gestionar el dispositivo *raw*.

### *AccessModes*

Los *access modes* son:

- `ReadWriteOnce` el volumen puede montarse como RW por un solo nodo
- `ReadOnlyMany` el volumen puede montarse como RO por múltiples nodos
- `ReadWriteMany` el vollumen puede ser montado como RW por múltiples nodos

> Diferentes proveedores proporionan volúmenes que soportan todos o alguno de los modos permitidos.

### Clase

Un *PersistentVolume* tiene una "clase" definida en el atributo `storageClass`. Un PV de una clase particular sólo puede asociarse a un PVC que solicite este tipo de almacenamiento. Un PV sin el atributo `storageClass` no define una "clase", por lo que sólo puede ser asociado a un PVC que no especifique el atributo `storageClass`.

## Referencia

- [Persistent Volumes](https://kubernetes.io/docs/concepts/storage/persistent-volumes/)
