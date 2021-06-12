# Mapa de herramientas

> "Work in progress"

En el siguiente cuadro, se muestran las herramientas que estoy considerando.

En la parte derecha, con las que todavía no he trabajado/documentado nada en el *site*.

Sería interesante indicar, para cada herramienta, qué tipo de *despliegue* he trabajado, por ejemplo:

1. Despliegue "manual", a partir de *manifests* y `kubectl apply`
1. Despliegue vía Helm Chart
1. Despliegue usando ArgoCD
1. Despliegue vía Operador

Para no complicar mucho el *mapa*, quizás incluir un *badge* o un color.

También había pensado en incluir *dependencias*, como que por ejemplo las herramientas que necesitan autenticación deben depender de `dex` o `OpenLDAP`, pero creo que no es demasiado realista.

## Mapa de herramientas [^1]

![Mapa de herramientas](map.svg)

[^1]: [source](source/map.drawio)
