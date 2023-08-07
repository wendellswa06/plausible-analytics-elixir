.PHONY: help install server clickhouse clickhouse-prod clickhouse-stop postgres postgres-prod postgres-stop

help:
	@perl -nle'print $& if m{^[a-zA-Z_-]+:.*?## .*$$}' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'

install: ## Run the initial setup
	mix deps.get
	mix ecto.create
	mix ecto.migrate
	mix download_country_database
	npm install --prefix assets
	npm install --prefix tracker
	npm run deploy --prefix tracker

server: ## Start the web server
	mix phx.server

CH_FLAGS ?= --detach -p 8123:8123 -p 9000:9000 --ulimit nofile=262144:262144 --name plausible_clickhouse

clickhouse: ## Start a container with a recent version of clickhouse
	docker run $(CH_FLAGS) --volume=$$PWD/.clickhouse_db_vol:/var/lib/clickhouse clickhouse/clickhouse-server:22.9-alpine

clickhouse-prod: ## Start a container with the same version of clickhouse as the one in prod
	docker run $(CH_FLAGS) --volume=$$PWD/.clickhouse_db_vol_prod:/var/lib/clickhouse clickhouse/clickhouse-server:23.3.7.5-alpine

clickhouse-stop: ## Stop and remove the clickhouse container
	docker stop plausible_clickhouse && docker rm plausible_clickhouse

PG_FLAGS ?= --detach -e POSTGRES_PASSWORD="postgres" -p 5432:5432 --name plausible_db

postgres: ## Start a container with a recent version of postgres
	docker run $(PG_FLAGS) --volume=plausible_db:/var/lib/postgresql/data postgres:latest

postgres-prod: ## Start a container with the same version of postgres as the one in prod
	docker run $(PG_FLAGS) --volume=plausible_db_prod:/var/lib/postgresql/data postgres:15

postgres-stop: ## Stop and remove the postgres container
	docker stop plausible_db && docker rm plausible_db
