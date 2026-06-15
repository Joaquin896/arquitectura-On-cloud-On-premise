# ACME ERP — Arquitectura segura On-Cloud (PoC)

**Evaluación N°3 · CI3051 — Seguridad en la Nube · INACAP**
Auditoría, análisis de riesgos y rediseño de la infraestructura de **Ferreterías y Distribuidora ACME Ltda.** (empresa OIV).

Ruta de trabajo en el nodo: `/srv/acme-erp/` · Gestionado desde GitHub.

---

## 1. Arquitectura (modelo en capas)

| Capa | Componente | Servicio |
|------|-----------|----------|
| Cliente | Navegador del usuario (HTTPS) | — |
| Borde / Seguridad | Security Group + Fail2ban (mínima exposición) | EC2 SG |
| Aplicación (IaaS) | Frontend Node.js/Express, contenedor Docker, portal con JWT + MFA (AAA) | Amazon EC2 |
| Datos (PaaS) | PostgreSQL gestionado, subred privada, TLS | Amazon RDS |
| Objetos | Respaldos cifrados (SSE) + ACL + versionado | Amazon S3 |
| Gestión | Logs, IAM Roles, backups diarios | CloudWatch / IAM |

El diagrama en capas y el DDF están en `diagrams/` (editable en Excalidraw).

---

## 2. Estructura del proyecto

```
/srv/acme-erp/
├── docker-compose.yml          # Stack del frontend (req. 6)
├── .env.example                # Plantilla de variables (copiar a .env)
├── frontend/                   # Node.js + Express (req. 4)
│   ├── Dockerfile
│   ├── package.json
│   ├── src/{server.js, db.js}  # App, auth JWT+MFA, conexión a RDS
│   └── public/{login.html, dashboard.html}
├── db/init.sql                 # Esquema PostgreSQL (req. 3)
├── scripts/
│   ├── backup_rds_to_s3.sh     # Backup diario RDS → S3 (req. 5)
│   ├── restore_from_s3.sh
│   └── crontab.acme            # Programación 24h
├── infra/
│   ├── aws-cli/                # Despliegue paso a paso (req. 3,5,7)
│   ├── terraform/              # IaC alternativa
│   └── fail2ban/               # Fortificación (req. 7)
└── diagrams/                   # Excalidraw + DDF (req. 1)
```

---

## 3. Despliegue en AWS (resumen)

> Requiere: cuenta AWS, AWS CLI v2 configurado (`aws configure`), una VPC con 2 subredes privadas y 1 pública.

```bash
# 0) Clonar el repo en la instancia
sudo git clone https://github.com/<usuario>/acme-erp.git /srv/acme-erp
cd /srv/acme-erp

# 1) Security Groups (mínima exposición)
export VPC_ID=vpc-xxxx ADMIN_CIDR=<tu_ip>/32
bash infra/aws-cli/01-security-groups.sh        # devuelve FRONT_SG y RDS_SG

# 2) RDS PostgreSQL (PaaS)
export RDS_SG=sg-xxxx PRIV_SUBNET_1=subnet-a PRIV_SUBNET_2=subnet-b DB_PASSWORD='****'
bash infra/aws-cli/02-rds-postgres.sh           # devuelve RDS_ENDPOINT

# 3) Bucket S3 de respaldos
export S3_BACKUP_BUCKET=acme-erp-backups-2026
bash infra/aws-cli/03-s3-backup-bucket.sh

# 4) (opcional) Instancia EC2 frontend
export FRONT_SG=sg-xxxx PUB_SUBNET=subnet-pub KEY_NAME=mi-llave
bash infra/aws-cli/04-ec2-frontend.sh
```

Alternativa declarativa: `cd infra/terraform && terraform init && terraform apply`.

---

## 4. Configuración y carga de esquema

```bash
cp .env.example .env          # editar: DB_HOST=<RDS_ENDPOINT>, JWT_SECRET, etc.
# Descargar el bundle CA de RDS para TLS:
curl -o frontend/certs/rds-combined-ca-bundle.pem \
  https://truststore.pki.rds.amazonaws.com/global/global-bundle.pem
# Crear el esquema en RDS:
psql "host=$DB_HOST port=5432 dbname=acme_erp user=acme_app sslmode=require" -f db/init.sql
```

---

## 5. Ejecución del stack (Requerimiento 6)

```bash
docker compose up -d --build      # construcción y despliegue
docker compose ps                 # verificar contenedores activos
docker compose logs -f frontend   # revisar logs del frontend
curl -k https://localhost/health  # interacción / healthcheck
docker compose down               # detención de servicios
```

El portal queda accesible en `https://<IP_PUBLICA_EC2>/`.
Usuario demo: `admin@acme.cl` / `Acme2026!` (cambiar en producción).

---

## 6. Backups (Requerimiento 5)

```bash
bash scripts/backup_rds_to_s3.sh           # respaldo manual inmediato
crontab scripts/crontab.acme               # 1 respaldo diario (03:00)
aws s3 ls s3://acme-erp-backups-2026/rds-backups/ --recursive   # evidencia en S3
```

---

## 7. Seguridad aplicada
- **Acceso condicional (AAA)**: login + MFA (TOTP) → JWT firmado en cookie `httpOnly`/`secure`.
- **Security Groups**: RDS solo accesible desde el SG del frontend; SSH solo desde IP admin.
- **Fail2ban**: bloqueo por fuerza bruta en SSH y en el portal (`infra/fail2ban/`).
- **Cifrado**: TLS hacia RDS, almacenamiento RDS y S3 cifrados (SSE/AES-256).
- **Cabeceras**: Helmet + rate-limit en el login.

---

> Documento técnico-comercial completo (APA7) e instrucciones detalladas en `docs/`.
