.PHONY: bootstrap

bootstrap:
	@if [ -z "$(NAME)" ]; then \
		echo "usage: make bootstrap NAME=<project-name>" >&2; \
		exit 1; \
	fi
	./bootstrap.sh "$(NAME)" $(if $(FORCE),--force,)
