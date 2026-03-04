job "care-backend" {
  datacenters = ["dc1"]
  type        = "service"

  group "backend" {
    count = 1

    network {
      mode = "bridge"
      port "http" {
        static = 9000
        to     = 9000
      }

      dns {
        servers = ["172.17.0.1"]
      }
    }

    service {
      name     = "care-backend"
      port     = "http"
      provider = "consul"

      connect {
        sidecar_service {
          proxy {
            upstreams {
              destination_name = "postgres"
              local_bind_port  = 5432
            }
            upstreams {
              destination_name = "redis"
              local_bind_port  = 6379
            }
          }
        }
      }

      check {
        type     = "http"
        path     = "/health/"
        interval = "15s"
        timeout  = "5s"
      }
    }

    task "api" {
      driver = "docker"

      config {
        image = "ghcr.io/ohcnetwork/care:latest"
        ports = ["http"]

        command = "bash"
        args = ["-c", <<EOF
echo "Waiting for REAL Postgres readiness..."

python3 - <<'END'
import time
import psycopg

while True:
    try:
        conn = psycopg.connect(
            host="127.0.0.1",
            port=5432,
            user="postgres",
            password="postgres",
            dbname="care",
            connect_timeout=3
        )
        conn.close()
        print("Postgres fully ready!")
        break
    except Exception as e:
        print("Waiting for DB...", e)
        time.sleep(2)
END

echo "Running migrations..."
python manage.py migrate --noinput

echo "Collecting static files..."
python manage.py collectstatic --noinput --clear

echo "Starting Gunicorn..."
gunicorn config.wsgi:application \
  --bind=0.0.0.0:9000 \
  --workers=2 \
  --threads=2 \
  --timeout=120
EOF
        ]
      }

      env {
        DJANGO_SETTINGS_MODULE = "config.settings.production"

        DATABASE_URL      = "postgresql://postgres:postgres@127.0.0.1:5432/care"
        REDIS_URL         = "redis://127.0.0.1:6379/0"
        CELERY_BROKER_URL = "redis://127.0.0.1:6379/0"

        DEBUG         = "true"
        SECRET_KEY    = "insecure-dev-key"
        SECURE_SSL_REDIRECT          = "false"
        DJANGO_SECURE_SSL_REDIRECT   = "false"
        SESSION_COOKIE_SECURE        = "false"
        CSRF_COOKIE_SECURE           = "false"
        SECURE_HSTS_SECONDS          = "0"
        ACCOUNT_DEFAULT_HTTP_PROTOCOL = "http"


        # CORS
        CORS_ALLOW_ALL_ORIGINS = "true"
        SECURE_HSTS_INCLUDE_SUBDOMAINS = "false"
        SECURE_HSTS_PRELOAD = "false"
      }

      resources {
        cpu    = 600
        memory = 1024
      }
    }
  }
}
