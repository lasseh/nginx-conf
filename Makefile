COMPOSE := docker compose -f tests/runtime/compose.yaml

.PHONY: test validate test-runtime lint

## test: syntax-check every template, then run the behaviour tests
test: validate test-runtime

## validate: nginx -t on each template and the combined entrypoint (local nginx)
validate:
	scripts/validate.sh

## test-runtime: all templates enabled together in nginx:mainline, curl assertions
test-runtime:
	@$(COMPOSE) up -d --wait --force-recreate || { $(COMPOSE) logs nginx; $(COMPOSE) down -v; exit 1; }
	@$(COMPOSE) exec -T nginx bash /src/tests/runtime/run.sh; rc=$$?; $(COMPOSE) down -v; exit $$rc

## lint: shellcheck the scripts
lint:
	shellcheck scripts/*.sh tests/runtime/*.sh
