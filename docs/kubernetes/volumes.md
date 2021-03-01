# Volúmenes

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

Por tanto, el usuario siempre recibe como mínimo la cantidad requerida, aunque en el caso del provisionamiento estático, es posible que el volumen proporcione mayor cantidad de almacenaje.

El controlador asocia el PV y el PVC de forma exclusiva, de forma que existe una relación de uno a uno entre PV y PVC, independientemente de cómo se ha creado el PV.

Los *claims* permanecen sin vincular mientras no exista un PV que cumpla con la petición de recursos indicada en el PVC. Los PV se vinculan con los PVC a medida que se encuentran disponibles.

### Uso

Los Pods usan los *claims* como si fueran volúmenes. El clúster inspecciona el *claim* para encontrar el volumen vinculado (*bound*) y montarlo en el Pod. Para aquellos volúmenes que soportan diferentes modos de acceso, el usuario indica el deseado a través del *claim*.

En cuanto un usuario tiene un *claim* y el *claim* se vincula, el PV asociado pertenece al usuario mientras lo necesite. Los usuarios despliegan Pods y acceden a los PVs vinculados a través de la sección `persistenVolumeClaim` de la sección `volumes` de la definición del Pod.

## Referencia

- [Persistent Volumes](https://kubernetes.io/docs/concepts/storage/persistent-volumes/)
