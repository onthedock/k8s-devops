
# Validar k3d *registry*

En la configuración de despliegue de k3d hemos incluido un *registry*:

```bash
$ docker ps | grep -i 'registry'
8ce590b73979   registry:2    "/entrypoint.sh /etc…"   40 minutes ago   Up 28 minutes   0.0.0.0:5000->5000/tcp   registry.localhost
```

> Como no hemos configurado certificados para el *registry* desplegado en k3d, debemos incluirlo en Docker como *registro inseguro*: [Test an insecure registry
](https://docs.docker.com/registry/insecure/)

Desplegamos un contenedor con [nginx](https://docs.nginx.com/nginx/admin-guide/installing-nginx/installing-nginx-docker/) localmente:

```bash
$ docker run --name test-nginx -p 80:80 -d nginx
Unable to find image 'nginx:latest' locally
latest: Pulling from library/nginx
f1f26f570256: Pull complete
84181e80d10e: Pull complete
1ff0f94a8007: Pull complete
d776269cad10: Pull complete
e9427fcfa864: Pull complete
d4ceccbfc269: Pull complete
Digest: sha256:f4e3b6489888647ce1834b601c6c06b9f8c03dee6e097e13ed3e28c01ea3ac8c
Status: Downloaded newer image for nginx:latest
da29a0c11411227d8de5e142172d72093c8f668bb83844d67a93f04dc8cb336f
```

Validamos que se ha desplegado y que está sirviendo la página por defecto:

```bash
$ docker ps | grep 'test-nginx'
da29a0c11411   nginx     "/docker-entrypoint.…"   2 minutes ago    Up 2 minutes    0.0.0.0:80->80/tcp, :::80->80/tcp   test-nginx

$ curl -s localhost:80 | grep -i 'welcome'
<title>Welcome to nginx!</title>
<h1>Welcome to nginx!</h1>
```

Tenemos la imagen de `nginx` descargada localmente:

```bash
$ docker images | grep 'nginx'
nginx   latest   ac232364af84   2 days ago     142MB
```

Etiquetamos la imagen para que referencie el *registry* desplegado en k3d (al que hemos llamado `registry`):

```bash
$ docker tag nginx:latest registry.localhost:5000/xaviaznar/nginx:v1.23
$ docker images | grep -i 'nginx'
nginx                                     latest   ac232364af84   2 days ago     142MB
registry.localhost:5000/xaviaznar/nginx   v1.23    ac232364af84   2 days ago     142MB
```

Subimos la imagen al *registry* en k3d:

```bash
$ docker push registry.localhost:5000/xaviaznar/nginx:v1.23
The push refers to repository [registry.localhost:5000/xaviaznar/nginx]
a1bd4a5c5a79: Pushed 
597a12cbab02: Pushed 
8820623d95b7: Pushed 
338a545766ba: Pushed 
e65242c66bbe: Pushed 
3af14c9a24c9: Pushed 
v1.23: digest: sha256:557c9ede65655e5a70e4a32f1651638ea3bfb0802edd982810884602f700ba25 size: 1570
```

Creamos un *deployment* (usando como referencia [Creating and exploring an nginx deployment
](https://kubernetes.io/docs/tasks/run-application/run-stateless-application-deployment/#creating-and-exploring-an-nginx-deployment)), pero **haciendo referencia a la imagen local**:

```yaml
kind: Deployment
metadata:
  name: nginx
spec:
  selector:
    matchLabels:
      app: nginx
  replicas: 2 # tells deployment to run 2 pods matching the template
  template:
    metadata:
      labels:
        app: nginx
    spec:
      containers:
      - name: nginx
        image: registry.localhost:5000/xaviaznar/nginx:v1.23
        ports:
        - containerPort: 80
```

Y lo aplicamos:

```bash
$ kubectl apply -f nginx/deployment.yaml
deployment.apps/nginx created
```

Para validar que está funcionando, usamos [port-forward](https://kubernetes.io/docs/tasks/access-application-cluster/port-forward-access-application-cluster/):

```bash
$ kubectl get pods
NAME                        READY   STATUS    RESTARTS   AGE
helloweb-85bc5c5556-jch9p   1/1     Running   0          26m
nginx-785dc69d4f-kk8md      1/1     Running   0          2m45s
nginx-785dc69d4f-pv9db      1/1     Running   0          2m45s
$ kubectl port-forward pod/nginx-785dc69d4f-kk8md 8080:80
Forwarding from 127.0.0.1:8080 -> 80
Forwarding from [::1]:8080 -> 80
```

En otra terminal:

```bash
$ curl -s localhost:8080 | grep -i 'welcome'
<title>Welcome to nginx!</title>
<h1>Welcome to nginx!</h1>
```

Finalmente, validamos que los *pods* se han desplegado usando la imagen desde el *registry* en k3d:

```bash
$ kubectl describe pod nginx-785dc69d4f-kk8md | grep -i 'image'
    Image:          registry.localhost:5000/xaviaznar/nginx:v1.23
    Image ID:       registry.localhost:5000/xaviaznar/nginx@sha256:557c9ede65655e5a70e4a32f1651638ea3bfb0802edd982810884602f700ba25
  Normal  Pulling    9m38s  kubelet   Pulling image "registry.localhost:5000/xaviaznar/nginx:v1.23"
  Normal  Pulled     9m29s  kubelet   Successfully pulled image "registry.localhost:5000/xaviaznar/nginx:v1.23" in 9.187628895s (9.188175627s including waiting)
```
