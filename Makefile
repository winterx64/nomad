.PHONY: logs reset-and-setup


DOCKER_VERSION := $(shell docker --version 2>/dev/null)

docker_config_file := 'docker-compose.local.yaml'

all:
ifndef DOCKER_VERSION
    $(error "command docker is not available, please install Docker")
endif


nomad-up:
	@./scripts/nomad-up.sh

nomad-down:
	@./scripts/nomad-down.sh

nomad-status:
	@nomad job status

%:
	docker compose exec backend bash -c "python manage.py $*"
