# Servidor de desarrollo

MkDocs proporciona el comando `mkdocs serve` que convierte los ficheros en formato markdown a HTML y los sirve usando un servidor web incustrado. Este servidor web usa por defecto `127.0.0.1:8000`.

Usando la opción `--dev-addr ${IP}:${PORT}` podemos especificar una dirección y puerto diferente al usado por defecto. La *opción corta* es `-a ${IP}:${PORT}`.

## Múltiples *sites* en desarrollo (previsualización)

Usa `--dev-addr` para lanzar múltples copias de `mkdocs serve` para otros *sites* diferente que quieras *previsualizar*; usa un puerto diferente para cada instancia del servidor de desarrollo:

```bash
mkdocs serve --dev_addr 127.0.0.1:8080
```

## Especifica un fichero de configuración

Cuando se ejecuta `mkdocs build` o `mkdocs serve`, MkDocs busca el fichero de configuración `mkdocs.yml` en la misma carpeta desde donde se ha lanzado. Para especificar un nombre de fichero -o una ubicación- diferente, usa la opción `--config-file` (o `-f` en la versión corta):

```bash
mkdocs server --config-file /path/to/config.yml
```

## Referencias

- Documentación de MkDocs, [`dev_addr`](https://www.mkdocs.org/user-guide/configuration/#dev_addr)
- Ayuda de MkDocs, `mkdocs build --help` o `mkdocs server --help`
