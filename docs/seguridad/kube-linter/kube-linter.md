# Kube-linter

> La documentación oficial se refiere a la herramienta como *KubeLinter*, mientras que el repositorio y la herramienta en sí se denominan `kube-linter`.

## Versiones

La documentación oficial [^1] indica que [KubeLinter](https://docs.kubelinter.io) se encuentra en una etapa muy temprana de desarrollo, por lo que puede haber cambios no retro-compatibles en el futuro.

- `kube-linter` versión 0.1.6

```bash
$ kube-linter version
0.1.6
```

## Ejemplo de uso

El objetivo de KubeLinter es validar la sintaxis y adhesión a las buenas prácticas en los ficheros de definición de recursos en Kubernetes.

Para ello, usa `kube-linter lint ${ruta/al/fichero/yaml}`.

```bash
$ kube-linter lint docs/monitoring/deploy/grafana.yaml 
docs/monitoring/deploy/grafana.yaml: (object: monitoring/grafana apps/v1, Kind=Deployment) container "grafana" does not have a read-only root file system (check: no-read-only-root-fs, remediation: Set readOnlyRootFilesystem to true in your container's securityContext.)

docs/monitoring/deploy/grafana.yaml: (object: monitoring/grafana apps/v1, Kind=Deployment) container "grafana" is not set to runAsNonRoot (check: run-as-non-root, remediation: Set runAsUser to a non-zero number, and runAsNonRoot to true, in your pod or container securityContext. See https://kubernetes.io/docs/tasks/configure-pod-container/security-context/ for more details.)

Error: found 2 lint errors
```

KubeLinter identifica dos configuraciones que no siguen *buenas prácticas* relacionadas con la seguridad del despliegue en el fichero para Grafana (en el *Deployment*), proporcionando indicaciones para corregirlas.

KubeLinter ha identificado errores, por lo que la ejecución devuelve un código diferente a 0:

```bash
$ echo $?
1
```

Este comportamiento permite integrarlo en un proceso de integración continua.

## Alias para `kube-linter`

Debido a que `kube-linter` comienza como `kubectl`, al intentar autocompletar `kube + (Tab)`, se obtiene `kubectl`; para evitar tener que escribir `kube-linter` se puede crear un *alias* como:

```bash
alias klint="kube-linter lint"
```

## Referencias

- Repositorio para [kube-linter](https://github.com/stackrox/kube-linter) en GitHub
- Documentación oficial [KubeLinter](https://docs.kubelinter.io/)

[^1]: Documentación oficial [KubeLinter](https://docs.kubelinter.io/)
