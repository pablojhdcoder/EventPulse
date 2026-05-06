# Imagen de producción para demo distribuida (réplicas + Director vía nginx).
FROM hexpm/elixir:1.17.3-erlang-27.1.2-alpine-3.20.3 AS build

RUN apk add --no-cache build-base git

WORKDIR /app

ENV MIX_ENV=prod

COPY mix.exs mix.lock ./
RUN mix local.hex --force && mix local.rebar --force && mix deps.get --only prod

COPY config config
COPY lib lib
COPY priv priv
COPY rel rel

RUN find rel -type f \( -name "*.eex" -o -name "*.sh" \) -exec sed -i 's/\r$//' {} \;

ARG RELEASE_HOSTNAME=localhost
ENV HOSTNAME=${RELEASE_HOSTNAME}

RUN mix compile
RUN mix release

FROM alpine:3.20 AS app

RUN apk add --no-cache openssl ncurses-libs libstdc++ wget

RUN adduser -D -s /bin/sh app
USER app
WORKDIR /app

COPY --from=build --chown=app:app /app/_build/prod/rel/event_pulse ./
COPY deploy/docker-entrypoint.sh /entrypoint.sh

USER root
RUN tr -d '\r' < /entrypoint.sh > /entrypoint.tmp && mv /entrypoint.tmp /entrypoint.sh \
    && chmod +x /entrypoint.sh && chown app:app /entrypoint.sh
USER app

ENV HOME=/app
ENV PHX_SERVER=true

ENTRYPOINT ["/entrypoint.sh"]
