.PHONY: new help

.DEFAULT_GOAL := help

new:
	@scripts/new "$(DEST)" $(NAME)

help:
	@echo 'make new DEST=<dir> [NAME=<name>]  — create a new yeet script'
	@echo 'scripts/new <dir> [name]           — same, without make'
