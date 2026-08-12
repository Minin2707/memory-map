# Infrastructure

Инфраструктура проекта Memory Map.

Локальная разработка использует Docker Compose только для инфраструктурных сервисов.

Сервисы:

- PostgreSQL + PostGIS
- MinIO

## Local MinIO for backend media

Docker Compose starts MinIO for local object storage. The backend is started
from the host with Gradle, so it reaches MinIO through the host-mapped port:

```text
http://localhost:9000
```

Local media endpoints are enabled only when the private backend config contains
the MinIO section. Create or update `backend/config/application-local.yml` from
`backend/config/application-local.example.yml` and keep these values aligned:

```yaml
app:
  storage:
    minio:
      enabled: true
      endpoint: http://localhost:9000
      access-key: <MINIO_ROOT_USER from infrastructure/.env>
      secret-key: <MINIO_ROOT_PASSWORD from infrastructure/.env>
      bucket: <MINIO_BUCKET from infrastructure/.env>
```

Do not commit `backend/config/application-local.yml` or `infrastructure/.env`.
