# Uso de `mc` (el cliente de MinIO)

## Definir un *alias*

`mc`, el cliente de MinIO es un ejecutable independiente, por lo que no requiere instalación.

Para comunicar con el servidor de MinIO, se define un *alias*. El *alias* agrupa la URL de acceso de MinIO y las credenciales del usuario.

> Las credenciales del cliente de MinIO `mc` se almacenan en texto plano en el fichero `~/.mc/config.json`.

Inicialmente sólo disponemos del usuario `root` para acceder a MinIO; configuramos el cliente con estas credenciales hasta que creemos un usuario con permisos restringidos.

```bash
$ ./mc alias set minio http://api.minio.dev.lab 3ba782dd-5f00-4f95-a5ab-437793eef4a1 3e034b1aa511b5857c76ed21cf58c5afd3fccb42eab47ce3638d5c76822d0c57dcbf5ad548ede52b
Added `minio` successfully.
```

## Crear grupos de usuarios

Vamos a crear dos grupos de usuarios; `developers` y `managers` con los siguientes permisos:

| Bucket | Grupo | Permisos |
| ------ | ----- | -------- |
| `dev-bucket` | `developers` | `RW` |
| `dev-bucket` | `managers` | `R` |
| `mngrs-bucket` | `developers` | `-` |
| `mngrs-bucket` | `managers` | `RW` |

## Crear una política

MinIO permite definir políticas de acceso para restringir el acceso de un usuario o grupo a los *buckets* desplegados.

MinIO proporciona unas políticas predefinidas `writeonly`, `readonly` y `readwrite` que aplican a todos los recursos en el servidor. Si queremos aplicar políticas restringidas a determinados buckets, por ejemplo, debemos crear nuestras propias políticas mediante `mc admin policy`.

> Las políticas son equivalentes a las *IAM policies* de AWS.

El equipo de `developers` sólo tiene acceso al bucket `dev-bucket`; creamos una política específica:

> Podemos consultar las políticas existentes como referencia mediante el comando `mc admin policy info <serverAlias> <nombrePolicy>`

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "s3:*"
      ],
      "Effect": "Allow",
      "Resource": [
        "arn:aws:s3:::dev-bucket/*"
      ],
      "Sid": "FullAccess to dev-bucket"
    }
  ]
}
```

El equipo de `managers` tiene acceso sólo de lectura al bucket `dev-bucket`:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "s3:ListBucket"
      ],
      "Effect": "Allow",
      "Resource": [
        "arn:aws:s3:::dev-bucket",
        "arn:aws:s3:::mngrs-bucket"
      ]
    },
    {
      "Action": [
        "s3:GetObject"
      ],
      "Effect": "Allow",
      "Resource": [
        "arn:aws:s3:::dev-bucket/*"
      ]
    },
    {
      "Action": [
        "s3:*"
      ],
      "Effect": "Allow",
      "Resource": [
        "arn:aws:s3:::mngrs-bucket/*"
      ],
      "Sid": "FullAccess to mngrs-bucket"
    }
  ]
}

```

Para crear las políticas:

```bash
$./mc admin policy add minio developers-policy developers-policy.json
Added policy `developers-policy` successfully.
$ ./mc admin policy add minio managers-policy managers-policy.json
Added policy `managers-policy` successfully.
```

Validamos que las políticas se han creado:

```bash
$ ./mc admin policy info minio managers-policy
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "s3:ListBucket"
      ],
      "Effect": "Allow",
      "Resource": [
        "arn:aws:s3:::dev-bucket",
        "arn:aws:s3:::mngrs-bucket"
      ]
    },
    {
      "Action": [
        "s3:GetObject"
      ],
      "Effect": "Allow",
      "Resource": [
        "arn:aws:s3:::dev-bucket/*"
      ]
    },
    {
      "Action": [
        "s3:*"
      ],
      "Effect": "Allow",
      "Resource": [
        
        "arn:aws:s3:::mngrs-bucket/*"
      ],
      "Sid": "FullAccess to mngrs-bucket"
    }
  ]
}
```

## Creamos los grupos

Para crear el grupo de `developers` y `managers`, debemos añadir un usuario al grupo (el grupo se crea si no existe).

Creamos el usuario `ana` en el servidor con *alias*  `minio` y password `07f635ff0675472dbe476483d3ca4674`:

```bash
$ ./mc admin user add minio ana 07f635ff0675472dbe476483d3ca4674
Added user `ana` successfully.
```

Del mismo modo, repetimos el proceso para crear el usuario para `bea`:

```bash
$ ./mc admin user add minio bea 8db415404e20460f8f990343d45e611f
Added user `bea` successfully.
```

Añadimos `ana` al grupo de `developers` y `bea` al de `managers`:

```bash
$ ./mc admin group add minio developers ana
Added members {ana} to group developers successfully.
$ ./mc admin group add minio managers bea
Added members {bea} to group managers successfully.
```

Con los grupos creados (y los usuarios dentro de los grupos), aplicamos las políticas específicas creadas:

```bash
$ ./mc admin policy set minio developers-policy group=developers
Policy `developers-policy` is set on group `developers`
$ ./mc admin policy set minio managers-policy group=managers
Policy `managers-policy` is set on group `managers`
```

Creamos los *buckets*:

```bash
$ ./mc mb minio/dev-bucket
Bucket created successfully `minio/dev-bucket`.
$ ./mc mb minio/mngrs-bucket
Bucket created successfully `minio/mngrs-bucket`.
```

Y ahora verificamos que los permisos funcionan como esperamos...

## Como el usuario `ana`

`ana` define un alias en su equipo para conectar con el servidor:

```bash
./mc alias set minio http://api.minio.dev.lab ana 07f635ff0675472dbe476483d3ca4674
```

Al listar los *buckets*, sólo obtiene el `dev-bucket` (el único al que su usaurio tiene acceso con la política aplicada):

```bash
$ ./mc ls minio
[2021-12-26 14:20:39 CET]     0B dev-bucket/
$ ./mc cp ~/Pictures/156331.jpg minio/dev-bucket
...vi/Pictures/156331.jpg:  745.57 KiB / 745.57 KiB ┃▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓┃ 7.06 MiB/s 0s
```

## Como el usuario `bea`

`bea` define el alias en su equipo:

```bash
$ ./mc alias set minio http://api.minio.dev.lab bea 8db415404e20460f8f990343d45e611f
Added `minio` successfully.
$ ./mc ls minio
[2021-12-26 14:20:39 CET]     0B dev-bucket/
[2021-12-26 14:21:00 CET]     0B mngrs-bucket/
```
