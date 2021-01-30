# Combinar *commits*

Las buenas prácticas de Git recomiendan que los cambios sean lo más atómicos posibles. Además, este desarrollo debería realizarse en una rama específica de *feature*.

Durante el desarrollo, se realizan gran cantidad de cambios *menores* o que no generan más que "ruido" al revisar la historia del repositorio.

> Hay quien prefiere mantener la historia del desarrollo y ver los pasos seguidos en la generación de una nueva funcionalidad o avance.

Podemos modificar la historia del repositorio con el comando `git rebase -i` y así mantener únicamente los cambios significativos.

> `git rebase -i` reescribe la historia de Git, por lo que es aconsejable realizar estas modificaciones sólo sobre cambios que no se hayan compartido con otras personas.

## Cambiar la historia del repositorio

El comando para realizar la reescritura de la historia del repositorio es `git rebase -i` seguido del identificador del último *commit* que queremos mantener si modificar. Podemos indicar el *sha* del *commit* o usar una referencia relativa (como `HEAD~3`).

Suponemos que hemos estado realizando modificaciones en la rama `test-squash`, por lo que tenemos una historia como:

```bash
f90ef86 (HEAD -> test-squash) Aviso de que git squash reescribe la historia
42fb6ac git squash: por qué es útil usar git squash
8da3fcd Añadimos título de la sección sobre git squash
5488b91 (master) Objetivo del documento
```

Si ahora queremos *comprimir* los *commits* posteriores al `5488b91`, podemos lanzar:

```bash
git rebase -i 5488b91
# Equivalente al anterior
git rebase -i HEAD~3
```

Git abre el editor predeterminado mostrando los identificadores de los *commits* afectados por el comando. El identificador de cada *commit* está precedido por la acción que se realizará sobre el *commit* (por defecto, `pick`, que conserva el *commit*). También se muestra el *commimt message*, aunque sólo de forma informativa, para que sea más sencillo identificar cada *commit*:

> Los *commits* se muestran en orden inverso a como se muestran en la salida del comando `git log`: primero el más antiguo seguidos por los *commits* posteriores.
> Tras la lista de *commits* Git proporciona ayuda con las acciones disponibles durante `git rebase`.

```bash
pick 8da3fcd Añadimos título de la sección sobre git squash
pick 42fb6ac git squash: por qué es útil usar git squash
pick f90ef86 aviso de que git squash reescribe la historia
```

Vamos a mantener el *commit* `8da3fcd` y vamos a comprimir los cambios posteriores en éste.

Modificamos `pick` por `squash` (o `s`, para abreviar) frente a los *commits* que queremos comprimir:

```bash
pick 8da3fcd Añadimos título de la sección sobre git squash
squash 42fb6ac git squash: por qué es útil usar git squash
squash f90ef86 git squash reescribe la historia
```

Guardamos para aplicar los cambios y automáticamente se abre un nuevo editor donde podemos editar el mensaje de *commit* de la acción de *squasheado* de la historia del repositorio. Al guardar el mensaje, la historia queda alterada:

```bash
25be076 (HEAD -> test-squash) Cómo combinar varios commits en uno solo usando git rebase -i
5488b91 (master) Objetivo del documento
```

> La primera aparición de una acción de `squash` debe ir precedida de un `pick`. Es decir, no podríamos mantener (`pick`) el `f90ef86` y *squashear* los otros dos.

```bash
# NO FUNCIONARÁ
squash 8da3fcd Añadimos título de la sección sobre git squash
squash 42fb6ac git squash: por qué es útil usar git squash
pick f90ef86 git squash reescribe la historia
```
