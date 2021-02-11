# Comandos útiles

## Establecer un *namespace* por defecto

Establece un *namespace* por defecto en los comandos `kubectl` de manera que no sea necesario especificarlo mediante la opción `-n ${nombre-namespace}` mediante:

```bash
kubectl config set-context --current --namespace=${nombre-namespace}
```

Valida el cambio con:

```bash
kubectl config view | grep namespace
```
