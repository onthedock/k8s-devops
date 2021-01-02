# Deshacer el último *commit* local:  `git reset`

Para deshacer el último *commit* usa `git reset`.

```bash
git reset --soft HEAD~1
```

El comando `reset` *rebobina* el puntero `HEAD` a la versión del repositorio especificada; en este caso, la versión *anterior* a la apuntada por `HEAD`:  `HEAD~1`, lo que *deshace* el último cambio realizado.

Al incluir la opción `--soft` los cambios realizados en la revisión anterior se mantienen en la *carpeta de trabajo* (*working copy*).

Si no quieres matener los cambios realizados, usa `--hard` para descartarlos. Esta opción no es reversible, por lo que hay que usarla **sólo si estás seguro de que no quieres mantener los cambios realizados**.

En vez de especificar una revisión *relativa* al último cambio -como hemos hecho en `HEAD~1`- puedes especificar el *sha* de un *commit* específico. Esto **deshace todos los *commits* intermedios**.
