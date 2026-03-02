job "care-backend" {

  datacenters = ["dc1"]
  type        = "service"

  group "backend" {

    count = 1

    network {

      mode = "bridge"

      port "http" {
        static = 9000
      }

    }

    service {

      name = "care-backend"

      port = "http"

      address_mode = "alloc"

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

    }

    task "api" {

      driver = "docker"

      config {

        image = "ghcr.io/ohcnetwork/care:latest"

        ports = ["http"]

        command = "bash"

        args = ["-c", <<EOF

echo "Waiting for Postgres..."

python - <<END
import socket, time
while True:
    try:
        socket.create_connection(("127.0.0.1", 5432), 2)
        break
    except:
        time.sleep(2)
END

echo "Postgres ready"

echo "Running migrations..."

python manage.py migrate --noinput

echo "Starting server..."

bash start.sh

EOF
        ]

      }

      env {

        DJANGO_SETTINGS_MODULE = "config.settings.deployment"


        POSTGRES_HOST     = "127.0.0.1"
        POSTGRES_PORT     = "5432"
        POSTGRES_DB       = "care"
        POSTGRES_USER     = "postgres"
        POSTGRES_PASSWORD = "postgres"


        REDIS_URL         = "redis://127.0.0.1:6379/0"
        CELERY_BROKER_URL = "redis://127.0.0.1:6379/0"

      }

      resources {

        cpu    = 400
        memory = 384

      }

    }

  }

}
