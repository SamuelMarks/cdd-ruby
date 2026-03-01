# Stage 1: Build
FROM ruby:3.4-alpine AS builder

WORKDIR /app
COPY . .

RUN apk add --no-cache build-base yaml-dev

RUN gem install bundler && \
    bundle install && \
    gem build cdd-ruby.gemspec

# Stage 2: Final
FROM ruby:3.4-alpine

WORKDIR /app

COPY --from=builder /app/cdd-ruby-0.0.1.gem /app/
COPY --from=builder /app/bin /app/bin
COPY --from=builder /app/src /app/src

RUN gem install ./cdd-ruby-0.0.1.gem --no-document

EXPOSE 8082

ENTRYPOINT ["cdd-ruby", "serve_json_rpc", "--port", "8082", "--listen", "0.0.0.0"]
