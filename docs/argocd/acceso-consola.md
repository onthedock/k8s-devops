# Acceso a la consola de Argo CD

## Primer acceso

El acceso a la consola de ArgoCD se puede realizar usando el nombre de usuario `admin` y el nombre del pod `argocd-server` como contraseña [^getting-started].

```bash
$ kubectl get pods -n toolbox-argocd -l app.kubernetes.io/name=argocd-server -o name | cut -d'/' -f 2
argocd-server-668b5b4974-pgwc9
```

Si el pod se reinicia, por ejemplo al hacer un *rollout* y cambia su nombre, el *secret* en el que se guardan las credenciales de acceso no se actualiza, por lo que este método de obtener la contraseña sólo es recomendable para el primer acceso tras el despliegue.

## Autenticación

La autenticación en el servidor API de Argo CD se realiza usando JSON Web Tokens (JWTs). Estos tokens se pueden obtener de forma general como se indica en la documentación oficial: [Security](https://argoproj.github.io/argo-cd/operator-manual/security/).

Para el usuario `admin` local, el token JWT es generado y firmado por el servidor de API de ArgoCD y no expira. Cuando se actualiza la contraseña del usuario `admin`, todos los tokens JWT existentes se revocan inmediatamente. La contraseña está almacenada encriptada con el *hash* `bcrypt` en el *Secret* `argocd-secret`.

`bcrypt` es una función de *hash* irreversible, por lo que no es posible recuperar la contraseña una vez se ha *hasheado*.

### Establecer una nueva contraseña para ArgoCD

En las [FAQ](https://argoproj.github.io/argo-cd/faq/) de ArgoCD se indica cómo restablecer el password en caso de olvido: [I forgot the admin password, how do I reset it?](https://argoproj.github.io/argo-cd/faq/#i-forgot-the-admin-password-how-do-i-reset-it)

En primer lugar hay que encriptar la contraseña seleccionada usando `bcrypt`.

> [Debian no proporciona capacidad de encriptar usando `bcrypt`](https://packages.debian.org/buster/bcrypt) debido a este [bug #700758 - bcrypt: Bcrypt exposes patterns in data, it is broken](https://bugs.debian.org/cgi-bin/bugreport.cgi?bug=700758).
>
> Puedes usar una herramienta online como [Bcrypt-Generator.com](https://bcrypt-generator.com/)

Para encriptar la contraseña usando `bcrypt` se puede usar una herramienta online como [Bcrypt password generator](https://www.browserling.com/tools/bcrypt).

Para usar una contraseña definida por el usuario para acceder a Argo CD, hay que *parchear* el *secret* `argocd-secret`:

> El valor en `admin.password` es directamente el *hash* de la contraseña; no es necesario codificarlo en base64.

```bash
$ kubectl -n argocd patch secret argocd-secret \
  -p '{"stringData": {
    "admin.password": "$2y$12$TStLsK2A1QHsZhlRgXQDWeNlhS4Ye4s7vqUYoHQlnMAf2CRunzQ9m",
    "admin.passwordMtime": "'$(date +%FT%T%Z)'"
  }}'
secret/argocd-secret patched
```

Para validar que la modificación ha funcionado, accede a Argo CD usando la contraseña actualizada.

[^getting-started]: [4. Login Using The CLI](https://argoproj.github.io/argo-cd/getting_started/#4-login-using-the-cli) en la página del *Getting Started* de la documentación de ArgoCD.
