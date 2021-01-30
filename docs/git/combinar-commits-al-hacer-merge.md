# Usando *squash* al hacer *merge*

Git proporciona la opción de *squashear* todos los *commits* de una rama al realizar el *merge*.

El comando `git merge --squash ${target_branch_name}`

Por ejemplo, tras realizar cambios en la rama `test-squash`, la historia del repositorio es:

```bash
50f991d (HEAD -> test-squash) explica el comando git merge --squash
5a13c16 git merge --squash
25be076 Cómo combinar varios commits en uno solo usando git rebase -i
5488b91 (master) Objetivo del documento
```

Una vez finalizados los cambios en esta rama, vamos a realizar el *merge* sobre la rama principal. Añadimos `--squash` para *comprimir* todos los cambios de la rama `test-squash`. Esto añade los cambios realizados en la rama `test-squash` al *staging* de la rama principal. Podemos integrar todos los cambios "importados" de la rama `test-quash` realizando `commit` en la rama principal (donde hemos realizado el *merge*).

```bash
# Historia inicial en la rama test-squash
$ git log --one-line
50f991d (HEAD -> test-squash) explica el comando git merge --squash
5a13c16 git merge --squash
25be076 Cómo combinar varios commits en uno solo usando git rebase -i
5488b91 (master) Objetivo del documento
# Cambiamos a la rama master para realizar el merge
$ git checkout master
Switched to branch 'master'
# Lanzamos el merge con --squash
$ git merge test-squash --squash
Updating 5488b91..50f991d
Fast-forward
Squash commit -- not updating HEAD
 readme.md | 11 +++++++++++
 1 file changed, 11 insertions(+)
# Los cambios de la rama se han comprimido e incorporado a los ficheros en master
# No se han guardado los cambios (la historia en master sigue igual)
$ git log --oneline
5488b91 (HEAD -> master) Objetivo del documento
# Los cambios "staged" provienen de la rama test-squash
$ git status
On branch master
Changes to be committed:
  (use "git restore --staged <file>..." to unstage)
    modified:   readme.md
# Guardamos los cambios en master
$ git commit -m "Cómo combinar varios commits en uno solo usando git rebase -i"
[master d7b3f51] Cómo combinar varios commits en uno solo usando git rebase -i
 1 file changed, 11 insertions(+)
# Todos los cambios de la rama squash se han incorporado a master como un solo commit
$ git log --oneline
d7b3f51 (HEAD -> master) Cómo combinar varios commits en uno solo usando git rebase -i
5488b91 Objetivo del documento
```

En la rama principal se incorporan todos los cambios realizados como un solo *commit*, pero a cambio conservamos la historia de cambios en la rama `squash`:

```bash
$ git checkout test-squash
Switched to branch 'test-squash'

$ git log --oneline
50f991d (HEAD -> test-squash) explica el comando git merge --squash
5a13c16 git merge --squash
25be076 Cómo combinar varios commits en uno solo usando git rebase -i
5488b91 Objetivo del documento
```
