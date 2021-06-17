# Sealed Secrets

Uno de los problemas abiertos de Kubernetes es la gestión de los *secretos*; es decir, aquella información sensible que, al menos de momento, se guarda en texto plano y cuya única medida de "seguridad" consiste en *ofuscarla* en [base64](https://es.wikipedia.org/wiki/Base64).

Los *Secrets* son objetos limitados al *Namespace*. Esto limita la "visibilidad" que puede tener un usuario sobre los *Secrets* existentes en los *Namespaces* sobre los que tiene acceso.

Tal y como se indica en el `README.md` de [Sealed Secrets](https://github.com/bitnami-labs/sealed-secrets), **puedes gestionar toda la configuración de Kubernetes en Git... excepto los *Secrets***, precisamente porque los *Secrets* no son seguros...

Con el auge de metodologías como [GitOps](https://www.weave.works/technologies/gitops/), el problema es mayor, ya que los desarrolladores no tienen acceso directo al clúster y **todo** debe desplegarse automáticamente desde Git.

Una de las soluciones al problema viene del equipo de [Bitnami-Labs](https://github.com/bitnami-labs/).

La solución se compone de dos partes: un controlador en el clúster (o un operador) y una herramienta cliente `kubeseal`.

`kubeseal` usa criptografía asimétrica que sólo el controlador puede desencriptar. Esos secretos *cifrados* se almacenan en un objeto llamado `SealedSecret`, que se puede usar como una plantilla para crear un *Secret* que las aplicaciones pueden usar con normalidad.

El *SealedSecret* es similar a un *Deployment*, pero en vez de generar *Pods*, se generan *Secrets*. El *SealedSecret* tiene una sección `template:` en la que se almacena el *Secret* "sellado" (junto con las anotaciones, etiquetas, tipo, etc del *Secret*).

El *Secret* "depende" del *SealedSecret* y se actualiza (o borra) siempre que lo hace el *SealedSecret*.

## Certificado / clave pública

La parte pública de la clave se usa para *sellar* los *Secretos*, por lo que debe estar disponible siempre que `kubeseal` necesite usarla. Aunque la clave pública del certificado no es información secreta, es necesario asegurarse que se usa la clave correcta.

`kubeaseal` puede obtener el certificado desde el controlador en tiempo de ejecución (lo que requiere acceso seguro a la API de Kubernetes), lo que es conveniente para uso interactivo.

Otra opción es obtener la clave y almacenarla fuera del clúster `kubeseal --fetch-cert > mycert.pem` usarla de forma *offline* con `kubeseal --cert mycert.pem`.

Desde la versión v0.9.x los certificados se renuevan automáticamente cada 30 días, por lo que es necesario actualizar la copia *offline* periódicamente. Desde la versión v0.9.2 `kubeseal` puede usar URLs, por lo que es posible "publicar" la copia *offline* en algún sitio de confianza.

## Alcance

Desde el punto de vista de un usuario, un *SealedSecret* es un dispositivo de tipo *write once*, que sólo puede ser desencriptado por el *controller* (ni el propio usuario que lo ha creado lo puede desencriptar).

Los *SealedSecrets* han sido diseñados para que no se pueda obtener información sobre los *Secrets*. Esto incluye el hecho de que no se permite que un usuario use un *SealedSecret* destinado a un *namespace* (sobre el que no tenga acceso) y usarlo para crear el *Secret* en un *namespace* sobre el que sí que tiene acceso, de manera que podría obtener información que no debería ver... Para evitarlo, *Sealed Secrets* se comporta *cómo si* usara una clave diferente para cada *namespace*. En realidad, lo que se hace es que se usa el nombre del *namespace* al cifrar el *Secret*, de manera que, a la práctica, es como si se usara una clave diferente por *namespace*.

Aunque este es el comportamiento por defecto, se pueden proporcionar diferentes *scopes* para los *sealed secrets*:

- `strict` (por defecto) el secreto se sella con el mismo **nombre** y **namespace**. Estos dos atributos forman parte de los datos cifrados y por tanto, modificarlos resultaría en un *decription error*.
- `namespace-wide` permite renombrar el *sealed secret* en un *namespace* concreto.
- `cluster-wide` el *secret* puede "des-sellarse" en cualquier *namespce* y con cualquier *nombre*.

También se puede configurar el *scope* del *SealedSecret* a través de anotaciones que se pasan a `kubeseal`:

- `sealedsecrets.bitnami.com/namespace-wide: "true"` -> para `namespace-wide`
- `sealedsecrets.bitnami.com/cluster-wide: "true"` -> para `cluster-wide`

> En una versión futura, se pretende consolidar el alcance del *SealedSecret* en la anotación `sealedsecrets.bitnami.com/scope`.

Si no se especifica ninguna anotación, se asume `strict`.
