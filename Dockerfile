FROM dart:3.10.4 AS build
WORKDIR /app
COPY deploy/origin/pubspec.yaml pubspec.yaml
RUN dart pub get
COPY bin/ bin/
COPY lib/ lib/
RUN dart compile exe bin/solar_rankings_site.dart -o /app/solar-site

FROM debian:trixie-slim
RUN apt-get update && apt-get install -y --no-install-recommends ca-certificates \
    && rm -rf /var/lib/apt/lists/* \
    && useradd --system --uid 10001 solar \
    && install -d -o solar -g solar /var/cache/solar
WORKDIR /app
COPY --from=build /app/solar-site /app/solar-site
COPY site/ /app/site/
COPY deploy/ /app/deploy/
ENV SOLAR_SITE_CACHE_DIR=/var/cache/solar
ENV SOLAR_SITE_SEED_DIR=/app/deploy/seed
USER solar
EXPOSE 8787
ENTRYPOINT ["/app/solar-site", "--host", "0.0.0.0", "--port", "8787"]
