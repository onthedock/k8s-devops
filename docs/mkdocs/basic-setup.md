# Mkdocs y mkdocs-material

Del documento inicial `index.md` creado al inicializar el *site*:

Para consultar la documentación completa, visita: [mkdocs.org](https://www.mkdocs.org).

## Comandos

* `mkdocs new [dir-name]` - Crea un nuevo proyecto.
* `mkdocs serve` - Arranca el servidor de desarrollo (con auto-recarga).
* `mkdocs build` - Construye el *site* estático con la documentación.
* `mkdocs -h` - Muestra el comando de ayuda y finaliza.

## Estructura del proyecto

```ini
mkdocs.yml    # Es el fichero de configuración
docs/
  index.md    # Página inicial de la documentación.
    ...       # Otras páginas en markdown, imágenes y otros ficheros.
```

## mkdocs-material

[Material para MkDocs](https://squidfunk.github.io/mkdocs-material/) es un *tema* para MkDocs orientado a la creación de documentación técnica. El *tema* es personalizable, buscable, *mobile-friendly*, etc.

### Configuración mínima

Para minimizar el mantenimiento de la documentación, realizo la menor configuración posible de MkDocs. También limito todo lo posible el uso de extensiones.
 
```yaml
nav:
  ...

theme:
  name: 'material'
  palette:
    primary: 'blue'
    accent: 'red'
  features:
    - navigation.tabs

markdown_extensions:
  - markdown.extensions.codehilite:
      guess_lang: false
      linenums: true
  - markdown.extensions.footnotes
```