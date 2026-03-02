job "care-postgres" {

  datacenters = ["dc1"]
  type        = "service"

  group "postgres" {

    count = 1

    network {

      mode = "bridge"

      port "db" {

        to = 5432
      }
    }

    service {

      name = "postgres"
      port = "db"

      connect {

        sidecar_service {

          proxy {

            config {}

          }
        }
      }
    }

    task "postgres" {

      driver = "docker"

      config {

        image = "postgres:16-alpine"

        ports = ["db"]

        volumes = [
          "local/postgres:/var/lib/postgresql/data"
        ]
      }

      env {

        POSTGRES_DB       = "care"
        POSTGRES_USER     = "postgres"
        POSTGRES_PASSWORD = "postgres"
      }

      resources {

        cpu    = 500
        memory = 1024
      }
    }
  }
}
