# OpenLDAP

La *Helm Chart* de instalación de OpenLDAP fue desaconsejada (*deprecated*) al mismo tiempo que el soporte para el repositorio `stable` de *charts* de Helm. Existe otra *chart* que permite desplegar OpenLDAP con alta disponibilidad, PhpLdapAdmin y Ltb-Passwd: [jp-gouin
/helm-openldap](https://github.com/jp-gouin/helm-openldap).

Sin embargo, el objetivo es desplegar sólo OpenLDAP, por lo que seguiremos una vía alternativa.

En Docker Hub hay varias imágenes que podemos usar como imagen base para desplegar OpenLDAP en Kubernetes, siendo las de [osixia/openldap](https://hub.docker.com/r/osixia/openldap) la más popular.

La [página en GitHub sobre esta imagen `osixia/docker-openldap`](https://github.com/osixia/docker-openldap) contiene toda la información necesaria para desplegar OpenLDAP usando Docker. En la carpeta `example/kubernetes` encontramos los ficheros de definición del *Deployment* y el *Service* *mínimos* que usaremos para desplegar la aplicación en el clúster.

## Despliegue de OpenLDAP

Partimos de los ficheros proporcionados por `osixia` como base sobre la que definir los recursos para desplegar OpenLDAP en Kubernetes.

### Namespace

Empezamos con la definición del *Namespace*; como mi intención es desplegar también *KeyCloak* o *dex*, usaremos el nombre genérico `identity`:

```yaml
---
kind: Namespace
apiVersion: v1
metadata:
  name: identity
```

### Deployment

Usamos el *Deployment* que proporciona `osixia` en la carpeta [`example/kubernetes/simple/`](https://github.com/osixia/docker-openldap/blob/master/example/kubernetes/simple/ldap-deployment.yaml) con algunas modificaciones menores (indicamos el *Namespace*, cambiamos el nombre de la organización, etc..)

```yaml
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: openldap
  namespace: identity
  labels:
    app: openldap
spec:
  selector:
    matchLabels:
      app: openldap
  replicas: 1
  template:
    metadata:
      labels:
        app: openldap
    spec:
      containers:
        - name: openldap
          image: osixia/openldap:1.5.0
          volumeMounts:
            - name: ldap-data
              mountPath: /var/lib/ldap
            - name: ldap-config
              mountPath: /etc/ldap/slapd.d
            - name: ldap-certs
              mountPath: /container/service/slapd/assets/certs
          ports:
            - containerPort: 389
              name: openldap
          env:
            - name: LDAP_LOG_LEVEL
              value: "256"
            - name: LDAP_ORGANISATION
              value: "Ameisin"
            - name: LDAP_DOMAIN
              value: "ameisin.lab"
            - name: LDAP_ADMIN_PASSWORD
              value: "admin"
            - name: LDAP_CONFIG_PASSWORD
              value: "config"
            - name: LDAP_READONLY_USER
              value: "false"
            - name: LDAP_READONLY_USER_USERNAME
              value: "readonly"
            - name: LDAP_READONLY_USER_PASSWORD
              value: "readonly"
            - name: LDAP_RFC2307BIS_SCHEMA
              value: "false"
            - name: LDAP_BACKEND
              value: "mdb"
            - name: LDAP_TLS
              value: "true"
            - name: LDAP_TLS_CRT_FILENAME
              value: "ldap.crt"
            - name: LDAP_TLS_KEY_FILENAME
              value: "ldap.key"
            - name: LDAP_TLS_DH_PARAM_FILENAME
              value: "dhparam.pem"
            - name: LDAP_TLS_CA_CRT_FILENAME
              value: "ca.crt"
            - name: LDAP_TLS_ENFORCE
              value: "false"
            - name: LDAP_TLS_CIPHER_SUITE
              value: "SECURE256:+SECURE128:-VERS-TLS-ALL:+VERS-TLS1.2:-RSA:-DHE-DSS:-CAMELLIA-128-CBC:-CAMELLIA-256-CBC"
            - name: LDAP_TLS_VERIFY_CLIENT
              value: "demand"
            - name: LDAP_REPLICATION
              value: "false"
            - name: LDAP_REPLICATION_CONFIG_SYNCPROV
              value: "binddn=\"cn=admin,cn=config\" bindmethod=simple credentials=$LDAP_CONFIG_PASSWORD searchbase=\"cn=config\" type=refreshAndPersist retry=\"60 +\" timeout=1 starttls=critical"
            - name: LDAP_REPLICATION_DB_SYNCPROV
              value: "binddn=\"cn=admin,$LDAP_BASE_DN\" bindmethod=simple credentials=$LDAP_ADMIN_PASSWORD searchbase=\"$LDAP_BASE_DN\" type=refreshAndPersist interval=00:00:00:10 retry=\"60 +\" timeout=1 starttls=critical"
            - name: LDAP_REPLICATION_HOSTS
              value: "#PYTHON2BASH:['ldap://ldap-one-service', 'ldap://ldap-two-service']"
            - name: KEEP_EXISTING_CONFIG
              value: "false"
            - name: LDAP_REMOVE_CONFIG_AFTER_SETUP
              value: "true"
            - name: LDAP_SSL_HELPER_PREFIX
              value: "ldap"
      volumes:
        - name: ldap-data
          hostPath:
            path: "/data/ldap/db"
        - name: ldap-config
          hostPath:
            path: "/data/ldap/config"
        - name: ldap-certs
          hostPath:
            path: "/data/ldap/certs"
```

Comprobamos que se ha desplegado correctamente.

## Mejoras sobre el despliegue de referencia

Este despliegue nos sirve como prueba de concepto, pero usa volúmenes de tipo `hostPath` y la contraseña del administrador se pasa como una variable de entorno.

Vamos a eliminar todos los usuarios y passwords del fichero de despliegue para obtenerlos de un *Secret*.

### *Secret* para las credenciales del usuario **admin**

Para generar el *Secret*, usamos la opción `--dry-run=client` que nos proporciona el YAML con las contraseñas ya *ofuscadas* en base64:

> Añadimos la etiqueta `app: openldap`

```bash
$ kubectl -n identity create secret generic ldap-secret \
> --from-literal=admin-password=admin \
> --from-literal=config-password=config \
> --from-literal=readonly-user=readonly \
> --from-literal=readonly-password=readonly \
> --dry-run=client -o yaml | tee openldap-secret.yaml
apiVersion: v1
data:
  admin-password: YWRtaW4=
  config-password: Y29uZmln
  readonly-password: cmVhZG9ubHk=
  readonly-user: cmVhZG9ubHk=
kind: Secret
metadata:
  creationTimestamp: null
  name: ldap-secret
  namespace: identity
  labels:
    app: openldap
```

Actualizamos las líneas correspondientes a las variables de entorno del *Deployment* para que obtengan el valor del *Secret*:

```yaml
...
- name: LDAP_ADMIN_PASSWORD
  valueFrom:
    secretKeyRef:
      name: ldap-secret
      key : admin-password
- name: LDAP_CONFIG_PASSWORD
  valueFrom:
    secretKeyRef:
      name: ldap-secret
      key: config-password
- name: LDAP_READONLY_USER
  value: "false"
- name: LDAP_READONLY_USER_USERNAME
  valueFrom:
    secretKeyRef:
      name: ldap-secret
      key: readonly-user
- name: LDAP_READONLY_USER_PASSWORD
  valueFrom:
    secretKeyRef:
      name: ldap-secret
      key: readonly-password
...
```

> Los valores obtenidos de un *Secret* en una variable de entorno no se actualizan automáticamente si se modifica el *Secret*.

A diferencia de lo que sucedía con la configuración anterior, ahora las credenciales no se muestran al ejecutar un `describe` del *Deployment*, por ejemplo:

```bash
...
Environment:
  LDAP_LOG_LEVEL:               256
  LDAP_ORGANISATION:            Ameisin
  LDAP_DOMAIN:                  ameisin.lab
  LDAP_ADMIN_PASSWORD:          <set to the key 'admin-password' in secret 'ldap-secret'>   Optional: false
  LDAP_CONFIG_PASSWORD:         <set to the key 'config-password' in secret 'ldap-secret'>  Optional: false
  LDAP_READONLY_USER:           false
  LDAP_READONLY_USER_USERNAME:  <set to the key 'readonly-user' in secret 'ldap-secret'>      Optional: false
  LDAP_READONLY_USER_PASSWORD:  <set to the key 'readonly-password' in secret 'ldap-secret'>  Optional: false
...
```

### Volúmenes

El fichero de *Deployment* proporcionado por `osixia` monta volúmenes para persistir los datos, la configuración y los certificados autogenerados por OpenLDAP.

En vez de usar `hostPath`, generamos ficheros de definición para los volúmenes usando la *Storage Class* por defecto del clúster.

```yaml
---
# Persistent Volume Claim ldap-data
kind: PersistentVolumeClaim
apiVersion: v1
metadata:
  namespace: identity
  name: ldap-data
  labels:
    app: openldap
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 2Gi
```

```yaml
---
# Persistent Volume Claim ldap-config
kind: PersistentVolumeClaim
apiVersion: v1
metadata:
  namespace: identity
  name: ldap-config
  labels:
    app: openldap
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi
```

```yaml
---
# Persistent Volume Claim ldap-certs
kind: PersistentVolumeClaim
apiVersion: v1
metadata:
  namespace: identity
  name: ldap-certs
  labels:
    app: openldap
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi
```

### Actualización del *Deployment* para montar los volúmenes

En el apartado `spec.template.containers[i].volumes`:

```yaml
...
volumes:
  - name: ldap-data
    persistentVolumeClaim:
      claimName: ldap-data
  - name: ldap-config
    persistentVolumeClaim:
      claimName: ldap-config
  - name: ldap-certs
    persistentVolumeClaim:
      claimName: ldap-certs
```

## Servicio `openldap`

Partimos del *Service* proporcionado por `osixia`; al margen de añadir la etiqueta `app: openldap` lo dejamos tal cual:

```yaml
---
apiVersion: v1
kind: Service
metadata:
  namespace: identity
  labels:
    app: openldap
  name: openldap
spec:
  ports:
    - port: 389
  selector:
    app: openldap
```

## Validación del despliegue

### Buscar un usuario usando `ldapsearch` desde un *Job*

Con las modificaciones realizadas tenemos la misma configuración que hemos validado previamente en Docker.

Validamos que OpenLDAP se ha desplegado correctamente realizando la búsqueda del usuario  `admin`. Para ello, lanzamos un *Job*:

```yaml
---
kind: Job
apiVersion:  batch/v1
metadata:
  namespace: identity
  labels:
    app: openldap
  generateName: ldap-search-
spec:
  template:
    metadata:
      labels:
        app: openldap
    spec:
      restartPolicy: Never
      containers:
        - name: openldap-search
          image: osixia/openldap:1.5.0
          env:
            - name: LDAP_BASE
              value: "dc=ameisin,dc=lab"
            - name: LDAP_BIND_USER
              value: "cn=admin,dc=ameisin,dc=lab"
            - name: LDAP_BIND_PASSWORD
              valueFrom:
                secretKeyRef:
                  name: ldap-secret
                  key: admin-password
          command: ["/bin/bash"]
          args:
            - "-c"
            - "ldapsearch -x -H ldap://openldap.identity.svc -b $LDAP_BASE -D $LDAP_BIND_USER -w $LDAP_BIND_PASSWORD"
```

Revisando los logs del *Job* comprobamos que OpenLDAP funciona correctamente:

```bash
$ kubectl -n identity logs ldap-search-mjc6z-xlvsg
# extended LDIF
#
# LDAPv3
# base <dc=ameisin,dc=lab> with scope subtree
# filter: (objectclass=*)
# requesting: ALL
#
# ameisin.lab
dn: dc=ameisin,dc=lab
objectClass: top
objectClass: dcObject
objectClass: organization
o: Ameisin
dc: ameisin

# search result
search: 2
result: 0 Success

# numResponses: 2
# numEntries: 1
```

### Crear Unidades Organizativas (*OU*s)

Aunque no son necesarias, lo habitual es crear cierta estructura que nos permita organizar los usuarios en el LDAP.

En el siguiente *Job* generamos dos unidades organizativas (OUs) `users` y `groups`:

```ini
dn: ou=groups,dc=ameisin,dc=lab
objectClass: organizationalUnit
objectClass: top
ou: groups

dn: ou=users,dc=ameisin,dc=lab
objectClass: organizationalUnit
objectClass: top
ou: users
```

```yaml
---
kind: Job
apiVersion:  batch/v1
metadata:
  namespace: identity
  labels:
    app: openldap
  generateName: ldap-add-ou-
spec:
  template:
    metadata:
      labels:
        app: openldap
    spec:
      restartPolicy: Never
      containers:
        - name: openldap-add-ou
          image: osixia/openldap:1.5.0
          env:
            - name: LDAP_URL
              value: "ldap://openldap.identity.svc"
            - name: LDAP_BASE
              value: "dc=ameisin,dc=lab"
            - name: LDAP_BIND_DN
              value: "cn=admin,dc=ameisin,dc=lab"
            - name: LDAP_BIND_PASSWORD
              valueFrom:
                secretKeyRef:
                  name: ldap-secret
                  key: admin-password
          command: ["/bin/bash"]
          args:
            - "-c"
            - |
              cat <<EOF>>/tmp/ous.ldif
              dn: ou=groups,dc=ameisin,dc=lab
              objectClass: organizationalUnit
              objectClass: top
              ou: groups

              dn: ou=users,dc=ameisin,dc=lab
              objectClass: organizationalUnit
              objectClass: top
              ou: users
              EOF
              ldapadd -x -D $LDAP_BIND_DN -w $LDAP_BIND_PASSWORD -f /tmp/ous.ldif -H $LDAP_URL
```

### Crear nuevo usuario en LDAP

Creamos un *Job* genérico para la añadir un usuario en OpenLDAP.
Para ello, definimos los valores relativos al usuario en el fichero `nombre-usuario.ldif`:

> Este fichero `ldif` define un usuario en la `ou=users`, por lo que es necesario que la OU se haya generado previamente.

```ini
dn: uid=marysun,ou=users,dc=ameisin,dc=lab
objectClass: top
objectClass: person
objectClass: organizationalPerson
objectClass: inetOrgPerson
cn: Mary Sun
uid: marysun
givenName: Mary Sun
sn: marysun
userPassword: Ch@ngeM3!
```

Para crear el usuario tenemos que ejecutar el comando `ldapadd` [^IBM]:

```bash
ldapadd -x -D $LDAP_BIND_DN -w $LDAP_BIND_PWD \
 -f nombre-usuario.ldif -H ldap://openldap.identity.svc
```

- `-x` *Use simple authentication instead of SASL*
- `-D` *Use the _Distinguished Name_ `binddn` to bind to the LDAP directory*
- `$LDAP_BIND_DN` es un objeto en LDAP que puede tener asociado una contraseña, por ejemplo `cn=admin,dc=ameisin,dc=lab`
- `-w` *Password*
- `$LDAP_BIND_PASSWORD` es la contraseña del usuario del usuario  `$LDAP_BIND_DN`

En este caso, en vez de crear un *ConfigMap* con el fichero de definición del usuario, generamos el fichero directamente en el *Job* de creación del usuario.

```yaml
---                                                                                           
kind: Job 
apiVersion:  batch/v1
metadata:
  namespace: identity
  labels:
    app: openldap
  generateName: ldap-adduser-
spec:
  template:
    metadata:
      labels:
        app: openldap
    spec:
      restartPolicy: Never
      containers:
        - name: openldap-adduser
          image: osixia/openldap:1.5.0
          env:
            - name: LDAP_URL
              value: "ldap://openldap.identity.svc"
            - name: LDAP_BASE
              value: "dc=ameisin,dc=lab"
            - name: LDAP_BIND_DN
              value: "cn=admin,dc=ameisin,dc=lab"
            - name: LDAP_BIND_PASSWORD
              valueFrom:
                secretKeyRef:
                  name: ldap-secret
                  key: admin-password
          command: ["/bin/bash"]
          args:
            - "-c"
            - |
              cat <<EOF>>/tmp/new-user.ldif
              dn: cn=marysun,ou=users,dc=ameisin,dc=lab
              objectClass: top
              objectClass: person
              objectClass: organizationalPerson
              objectClass: inetOrgPerson
              cn: Mary Sun
              uid: marysun
              givenName: Mary Sun
              sn: marysun
              userPassword: Ch@ngeM3
              EOF
              # Should check if user already exists or will fail
              ldapadd -x -D $LDAP_BIND_DN -w $LDAP_BIND_PASSWORD -c -f /tmp/new-user.ldif -H $LDAP_URL           
```

## Referencias

- GitHub: [osixia/docker-openldap](https://github.com/osixia/docker-openldap)
- [Create An OpenLDAP server with Bitnami Containers on Kubernetes](https://docs.bitnami.com/tutorials/create-openldap-server-kubernetes/#useful-links)
- [Installing OpenLDAP on Kubernetes with Helm](https://www.talkingquickly.co.uk/installing-openldap-kubernetes-helm)
- [Adding Custom Schema for OpenLDAP Running on Kubernetes](https://zhimin-wen.medium.com/adding-custom-schema-for-openldap-running-on-kubernetes-f79e9af7f2b)
- [Step by step guide to integrate LDAP with Kubernetes](https://medium.com/@pmvk/step-by-step-guide-to-integrate-ldap-with-kubernetes-1f3fe1ec644e)
- [Implementing LDAP authentication for Kubernetes](https://itnext.io/implementing-ldap-authentication-for-kubernetes-732178ec2155)
- [LDAP for Rocket Scientists](https://www.zytrax.com/books/ldap/)
- [Keeping your sanity while designing OpenLDAP ACLs](https://medium.com/@moep/keeping-your-sanity-while-designing-openldap-acls-9132068ed55c)

[^IBM]: [Creating a user and adding a user to a group](https://www.ibm.com/docs/en/noi/1.6.3?topic=ldap-creating-user-adding-user-group)

## Versiones

- OpenLDAP: [`osixia/openldap:1.5.0`](https://hub.docker.com/layers/osixia/openldap/1.5.0/images/sha256-ca664138d9265fa16d208adcaa36b3cb67f5e00ea4f07a95dfe7ec7abb391b73?context=explore) ([OpenLDAP 2.4.57](https://www.openldap.org/software/release/changes.html))
- **kubectl** 1.20.4
- Kubernetes (k3s): v1.20.4+k3s1
