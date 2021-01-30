
# Ejemplo realista de edición de *commits*

Partiendo de la rama `master`, creamos una nueva rama `feature-1` y vamos *commiteando* cambios:

```bash
$ git status
On branch master
nothing to commit, working tree clean
$ git log --oneline
429c084 (HEAD -> master) Documenta cómo funciona git rebase -i para comprimir commits
5488b91 Objetivo del documento
$ git co -b feature-1
Switched to a new branch 'feature-1'

$ git log --oneline
429c084 (HEAD -> feature-1, master) Documenta cómo funciona git rebase -i para comprimir commits
5488b91 Objetivo del documento

$ vim readme.md
$ git add readme.md
$ git commit -m "Primer cambio tras crear la rama"
[feature-1 b185d06] Primer cambio tras crear la rama
 1 file changed, 1 insertion(+)

$ vim readme.md
$ git add readme.md
$ git commit -m "Segundo cambio"
[feature-1 da2045b] Segundo cambio
 1 file changed, 1 insertion(+)

$ git log --oneline
da2045b (HEAD -> feature-1) Segundo cambio
b185d06 Primer cambio tras crear la rama
429c084 (master) Documenta cómo funciona git rebase -i para comprimir commits
5488b91 Objetivo del documento

$ vim readme.md
$ git add readme.md
$ git commit -m "Cambio basado en la frustación. Eliminar!!"
git commit -m "Cambio basado en la frustación. Eliminargit add readme.md "
[feature-1 529b7bc] Cambio basado en la frustación. Eliminargit add readme.md
 1 file changed, 1 insertion(+)

# !! se ha interpretado como un comando de shell para ejecutar el último comando en "history"
$ git log --oneline
529b7bc (HEAD -> feature-1) Cambio basado en la frustación. Eliminargit add readme.md
da2045b Segundo cambio
b185d06 Primer cambio tras crear la rama
429c084 (master) Documenta cómo funciona git rebase -i para comprimir commits
5488b91 Objetivo del documento

$ vim readme.md
$ git add readme.md
$ git commit -m "Corrige cambios debidos a la frustacion"
[feature-1 28506fa] Corrige cambios debidos a la frustacion
 1 file changed, 1 deletion(-)

$ vim readme.md
$ git add readme.md
$ git commit -m "Nueva funcionalidad"
[feature-1 150c964] Nueva funcionalidad
 1 file changed, 3 insertions(+), 2 deletions(-)

$ vim readme.md
$ git add readme.md
$ git commit -m "Fix: warning del linter: el fichero debe acabar con línea en blanco"
[feature-1 ba06e7a] Fix: warning del linter: el fichero debe acabar con línea en blanco
 1 file changed, 1 insertion(+)
```

Tras finalizar el desarrollo y validación de la nueva funcionalidad, revisamos la historia del repositorio:

```bash
# Esta es la historia que refleja qué ha pasado durante el desarrollo
$ git log --oneline
ba06e7a (HEAD -> feature-1) Fix: warning del linter: el fichero debe acabar con línea en blanco
150c964 Nueva funcionalidad
28506fa Corrige cambios debidos a la frustacion
529b7bc Cambio basado en la frustación. Eliminargit add readme.md
da2045b Segundo cambio
b185d06 Primer cambio tras crear la rama
429c084 (master) Documenta cómo funciona git rebase -i para comprimir commits
5488b91 Objetivo del documento
```

## Uso de `reword` para corregir un mensaje de *commit*

Vemos que el mensaje de *commit* para `529b7bc` contiene un error: al usar `!!` en el mensaje de *commit*, el *shell* lo ha interpretado como "volver a ejecutar el último comando en **history**", lo que ha insertado `git add readme.md` como parte del mensaje de *commit*.

Lanzamos `git rebase -i 429c084` manteniendo todos los *commits* (con `pick`) y usando `reword` para modificar el mensaje de *commit* para `529b7bc`:

```bash
# Usammos reword para corregir un mensaje de commit antiguo (529b7bc)
$ git rebase -i 429c084
[detached HEAD 22c4bad] Cambio basado en la frustación. Eliminar
 Date: Sat Jan 30 20:25:51 2021 +0100
 1 file changed, 1 insertion(+)
Successfully rebased and updated refs/heads/feature-1.
```

Observa que al corregir el mensaje de *commit*, no sólo se ha modificado el SHA del *commit* editado sino **TODOS los identificadores de los *commits* posteriores**:

```bash
$ git log --oneline
6960f77 (HEAD -> feature-1) Fix: warning del linter: el fichero debe acabar con línea en blanco
6973286 Nueva funcionalidad
146749c Corrige cambios debidos a la frustacion
22c4bad Cambio basado en la frustación. Eliminar
da2045b Segundo cambio
b185d06 Primer cambio tras crear la rama
429c084 (master) Documenta cómo funciona git rebase -i para comprimir commits
5488b91 Objetivo del documento
```

## Uso de `git rebase -i` para comprimir sólo algunos de los *commits*

En vez de comprimir todos los *commits*, puede ser interesante conservar algunos *commits* relevantes.

En este ejemplo, comprimimos en dos *commits* toda la historia del desarrollo de la nueva funcionalidad. Para ello, seleccionamos los *commits* que queremos conservar y *squasheamos* el resto. Para cada uno de los *commits* que conservamos, se abrirá el editor predefinido para establecer el mensaje del *commit* resultante del *squash*:

```bash
# Comprimimos los commits en sólo dos commits diferentes
$ git rebase -i 429c084
[detached HEAD 402e659] Primer cambio tras crear la rama
 Date: Sat Jan 30 20:23:52 2021 +0100
 1 file changed, 2 insertions(+)
[detached HEAD 392df56] Nueva funcionalidad
 Date: Sat Jan 30 20:28:11 2021 +0100
 1 file changed, 4 insertions(+), 2 deletions(-)
Successfully rebased and updated refs/heads/feature-1.
```

Podemos repetir el proceso de *squash* múltiples veces (aunque recuerda que cada vez se cambia la historia del repositorio).

Decidimos comprimir los dos *commits* restantes en uno solo:

```bash
$ git log --oneline
392df56 (HEAD -> feature-1) Nueva funcionalidad
402e659 Primer cambio tras crear la rama
429c084 (master) Documenta cómo funciona git rebase -i para comprimir commits
5488b91 Objetivo del documento

# Los squasheamos en un solo commit final (lo de primer cambio tras crear la rama no aporta nada)
$ git rebase -i 429c084
[detached HEAD 5652012] Nueva funcionalidad
 Date: Sat Jan 30 20:23:52 2021 +0100
 1 file changed, 4 insertions(+)
Successfully rebased and updated refs/heads/feature-1.

$ git log --oneline
5652012 (HEAD -> feature-1) Nueva funcionalidad
429c084 (master) Documenta cómo funciona git rebase -i para comprimir commits
5488b91 Objetivo del documento
```

Como vemos, hemos comprimido toda la historia del desarrollo de la *feature-1* en un sólo *commit* `5652012` (suponemos que este *commit* describe con detalle los cambios introducidos, etc).

De esta forma, cuando integramos rama `feature-1` en `master`, la historia del repositorio sólo contiene información relevante del desarrollo:

```bash
# Tras squashear, vamos a mergear a master
$ git co master
Switched to branch 'master'

$ git log --oneline
429c084 (HEAD -> master) Documenta cómo funciona git rebase -i para comprimir commits
5488b91 Objetivo del documento

$ git merge feature-1
Updating 429c084..5652012
Fast-forward
 readme.md | 4 ++++
 1 file changed, 4 insertions(+)

# Historia "limpia" final
$ git log --oneline
5652012 (HEAD -> master, feature-1) Nueva funcionalidad
429c084 Documenta cómo funciona git rebase -i para comprimir commits
5488b91 Objetivo del documento
```

Hemos incorporado los cambios realizados en la rama `feature-1` en `master` incorporando sólo los avances relevantes (aunque en el ejemplo finalmente lo hemos reducido todo a un sólo *commit*). Podemos borrar la rama:

```bash
$ git branch -d feature-1
Deleted branch feature-1 (was 5652012).

$ git log --oneline
5652012 (HEAD -> master) Nueva funcionalidad
429c084 Documenta cómo funciona git rebase -i para comprimir commits
5488b91 Objetivo del documento
```
