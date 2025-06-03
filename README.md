About this Repo
===============

Dockerfile Image for Odoo v16, v17

# How create a new image

## v17> Needs python > 3.9

1) Duplicate one folder version and rename it with the new version
2) Change the version in the Dockerfile and in make.sh file
3) Build the Docker Image if It Doesn't Exist:
```
docker build -t docker-odoo:17.0 .
```
4) Tag Your Docker Image: Docker Hub identifies images by their repository name, which is usually formatted as username/repository:tag.
```
docker tag docker-odoo:17.0 gauchocode/docker-odoo:17.0
```
5) Log In to Docker Hub (If you don't have an account you should create a Docker Hub Account in https://hub.docker.com/)
```
docker login
```
6) Push the Image to Docker Hub:
```
docker push gauchocode/docker-odoo:17.0
```
7) Verify the Image on Docker Hub: After the push is complete, go to your Docker Hub account, and you should see the `docker-odoo` repository with the `17.0` tag listed.

# � docker-odoo

Scripts utilitarios para gestionar entornos Odoo en Docker.

---

## � Lista de scripts

| Script                  | Descripción                                                        |
|------------------------|--------------------------------------------------------------------|
| `git_pull_addons.sh`   | Hace `git pull` en cada carpeta dentro de `CUSTOM_ADDONS`          |
| `update_odoo_conf.sh`  | Genera o actualiza el `odoo.conf` con todas las rutas de addons    |
| `init_base.sh`         | Inicializa la base de datos instalando solo el módulo `base`       |
| `update_module.sh`     | Actualiza un módulo (o todos) dentro del contenedor Odoo activo    |
| `restart.sh`           | Reinicia el contenedor de Odoo                                     |

---

## ▶️ Orden recomendado de uso

1. **Actualizar código fuente de addons**
   ```bash
   ./git_pull_addons.sh
