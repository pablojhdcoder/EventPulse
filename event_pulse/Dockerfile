FROM hexpm/elixir:1.15-alpine

RUN apk add --no-cache build-base git bash openssl

WORKDIR /app

COPY mix.exs mix.lock ./
COPY config config
COPY lib lib

RUN mix local.hex --force && mix local.rebar --force
RUN mix deps.get
RUN MIX_ENV=prod mix deps.compile
RUN MIX_ENV=prod mix compile

EXPOSE 4000

ENV MIX_ENV=prod
CMD ["sh", "-c", "export NODE_NAME=event_pulse_$(hostname); elixir --name $NODE_NAME --cookie ${ERL_COOKIE:-event_pulse_cookie} -S mix phx.server"]
