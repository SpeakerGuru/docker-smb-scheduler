.PHONY: build up down logs ps

build:
\tdocker compose build --no-cache

up:
\tdocker compose up -d

down:
\tdocker compose down -v

logs:
\tdocker compose logs -f --tail=200

ps:
\tdocker compose ps
