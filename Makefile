.PHONY: logs reset-and-setup

nomad-up:
	@./scripts/nomad-up.sh

nomad-down:
	@./scripts/nomad-down.sh

nomad-status:
	@nomad job status

%:
	docker compose exec backend bash -c "python manage.py $*"
