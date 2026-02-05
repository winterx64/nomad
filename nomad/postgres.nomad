job "care-postgres" {
  datacenters = ["dc1"]
  type        = "service"
  priority    = 100

  meta {
    owner = "platform"
    env   = "production"
  }

  group "postgres" {
    count = 1

    restart {
      attempts = 3
      interval = "5m"
      delay    = "10s"
      mode     = "fail"
    }

    network {
      mode = "bridge"
      port "db" {
        static = 5432
        to     = 5432
      }
    }

    service {
      name = "care-postgres"
      port = "db"
      tags = ["database", "postgres"]

      check {
        name     = "postgres-check"
        type     = "tcp"
        interval = "10s"
        timeout  = "5s"
        success_before_passing = 2
        failures_before_critical = 3
      }
    }

    task "postgres" {
      driver = "docker"

      config {
        image = "postgres:16-alpine"
        ports = ["db"]
        volumes = [
          "local/postgres_data:/var/lib/postgresql/data"
        ]
      }

      env {
        POSTGRES_DB       = "care"
        POSTGRES_USER     = "postgres"
        POSTGRES_PASSWORD = "postgres"
        PGDATA            = "/var/lib/postgresql/data/pgdata"
      }

      resources {
        cpu    = 500
        memory = 1024
      }
    }
  }
}