# Comparar fichero entre dos ramas

Para comparar los cambios en el fichero `${ruta/al/nombre-fichero}` entre la rama `${nombre-rama}` y `main`, usa el comando:

```bash
git diff ${nombre-rama} main -- ${ruta/al/nombre-fichero}
```

> Para comparar el contenido del fichero entre `${rama-1}` y `${rama-2}`, sustituye `main` por el nombre de la segunda rama.

Hay que incluir la ruta relativa al nombre del fichero a comparar.

Los mismos argumentos se pueden pasar al comando `git difftool`, si se ha configurado una herramienta externa de diferencias.

## Referencias

- [How to compare files from two different branches?](https://stackoverflow.com/questions/4099742/how-to-compare-files-from-two-different-branches) en StackOverflow
- Documentación oficial de Git [`git diff`](https://git-scm.com/docs/git-diff)
