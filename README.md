# 🚀 docker-odoo

Scripts utilitarios para inicializar, configurar y administrar proyectos Odoo usando Docker Compose.

---

## 📜 Scripts disponibles

| Script              | Descripción                                                                 |
|---------------------|-----------------------------------------------------------------------------|
| `pull_addons.sh`    | Ejecuta `git pull` en cada subcarpeta de los addons personalizados          |
| `update_conf.sh`    | Genera o actualiza el archivo `odoo.conf` incluyendo rutas de addons        |
| `init_base.sh`      | Inicializa la base de datos instalando solo el módulo `base`                |
| `update_module.sh`  | Actualiza uno o todos los módulos dentro del contenedor Odoo                |
| `restart_odoo.sh`   | Reinicia el contenedor de Odoo                                               |
| `backup_restore.sh` | Gestiona backups y restauraciones de la base de datos                       |
| `clean_db.sh`       | Elimina o reinicia una base de datos                                         |
| `clone_repos.sh`    | Clona repositorios de addons desde una lista predefinida                    |
| `entrypoint.sh`     | Entrypoint personalizado para el arranque automatizado del contenedor       |
| `docker-compose.yml`| Define la configuración de los servicios Odoo y PostgreSQL                  |
| `env.example`       | Plantilla de variables necesarias para los scripts (`.env`)                 |

---

## ▶️ Orden recomendado de uso

1. **Clonar los repositorios de addons (si aplica)**  
   ```bash
   ./clone_repos.sh
   ```

2. **Actualizar los repositorios con cambios nuevos**  
   ```bash
   ./pull_addons.sh
   ```

3. **Actualizar el archivo de configuración `odoo.conf`**  
   ```bash
   ./update_conf.sh
   ```

4. **Inicializar base de datos con el módulo base (solo si es nuevo proyecto)**  
   ```bash
   ./init_base.sh
   ```

5. **Actualizar módulo principal (o todos)**  
   ```bash
   ./update_module.sh nombre_modulo nombre_db
   ./update_module.sh           # para actualizar todos en la db definida en el .env
   ```

6. **Reiniciar Odoo si es necesario**  
   ```bash
   ./restart_odoo.sh
   ```

---

## 🛠 Post-clonación

Después de clonar este repositorio, asegurate de dar permisos de ejecución a los scripts:

```bash
chmod +x *.sh
```

---

## 🧪 Archivo de entorno

Copiá `env.example` a `.env` y modificá las variables necesarias:

```bash
cp env.example .env
```

---

## 📂 Repositorio

[github.com/gauchocode/docker-odoo](https://github.com/gauchocode/docker-odoo)
