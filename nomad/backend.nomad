job "care-backend" {
  datacenters = ["dc1"]
  type        = "service"
  priority    = 100

  meta {
    owner = "platform"
    env   = "production"
  }

  group "backend" {
    count = 1

    restart {
      attempts = 3
      interval = "5m"
      delay    = "25s"
      mode     = "fail"
    }

    network {
      mode = "bridge"
      port "http" {
        static = 9000
        to     = 9000
      }
    }

    service {
      name = "care-backend"
      port = "http"
      tags = ["urlprefix-/"]

      check {
        name     = "tcp-check"
        type     = "tcp"
        path     = "/health/"
        interval = "10s"
        timeout  = "2s"
        success_before_passing = 2
        failures_before_critical = 3
      }
    }

    task "api" {
      driver = "docker"

      config {
        image = "ghcr.io/ohcnetwork/care:latest"
        ports = ["http"]

        # Consul services as /etc/hosts entries
        extra_hosts = [
          "care-postgres.service.consul:192.168.1.41",
          "care-redis.service.consul:192.168.1.41"
        ]

        command = "/bin/sh"
        args = ["-c", <<EOF
/app/.venv/bin/python manage.py migrate --noinput
/app/.venv/bin/python manage.py collectstatic --noinput --clear
/app/.venv/bin/python -m gunicorn config.wsgi:application \
  --bind=0.0.0.0:9000 \
  --workers=4 \
  --threads=2 \
  --worker-class=gthread \
  --timeout=120 \
  --access-logfile - \
  --error-logfile -
EOF
        ]
      }

      env {
        DJANGO_SETTINGS_MODULE = "config.settings.production"
        DATABASE_URL = "postgresql://postgres:postgres@care-postgres.service.consul:5432/care"
        REDIS_URL    = "redis://care-redis.service.consul:6379/0"



        ALLOWED_HOSTS = "*"
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
        cpu    = 800
        memory = 1024
      }
    }
  }
}
