job "care-redis" {
  datacenters = ["dc1"]
  type        = "service"
  priority    = 100

  meta {
    owner = "platform"
    env   = "production"
  }

  group "redis" {
    count = 1

    restart {
      attempts = 3
      interval = "5m"
      delay    = "10s"
      mode     = "fail"
    }

    network {
      mode = "bridge"
      port "redis" {
        static = 6379
        to     = 6379
      }
    }

    task "redis" {
      driver = "docker"

      config {
        image = "redis:8-alpine"
        ports = ["redis"]
        args  = ["--appendonly", "yes"]
        volumes = [
          "local/redis_data:/data"
        ]
      }

      service {
        name = "care-redis"
        port = "redis"
        tags = ["cache", "redis"]

        check {
          name     = "redis-check"
          type     = "tcp"
          interval = "10s"
          timeout  = "5s"
          success_before_passing = 2
          failures_before_critical = 3
        }
      }

      resources {
        cpu    = 250
        memory = 512
      }
    }
  }
}
