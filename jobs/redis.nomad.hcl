job "care-redis" {

  datacenters = ["dc1"]
  type        = "service"

  group "redis" {

    count = 1

    network {

      mode = "bridge"

      port "redis" {

        to = 6379
      }
    }

    service {

      name = "redis"
      port = "redis"

      connect {

        sidecar_service {}
      }
    }

    task "redis" {

      driver = "docker"

      config {

        image = "redis:7-alpine"

        ports = ["redis"]
      }

      resources {

        cpu    = 200
        memory = 256
      }
    }
  }
}
