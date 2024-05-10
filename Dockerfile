################### Web Server
# hadolint ignore=DL3007
FROM metacpan/metacpan-base:latest AS server
SHELL [ "/bin/bash", "-euo", "pipefail", "-c" ]

WORKDIR /app

COPY cpanfile cpanfile.snapshot ./
RUN \
    --mount=type=cache,target=/root/.perl-cpm,sharing=private \
<<EOT
    cpm install --show-build-log-on-failure --resolver=snapshot
EOT

ENV PERL5LIB="/app/lib:/app/local/lib/perl5"
ENV PATH="/app/local/bin:${PATH}"

COPY app.psgi *.conf ./
COPY lib lib

CMD [ \
    "/uwsgi.sh", \
    "--http-socket", ":5001" \
]

EXPOSE 5001

################### Development Server
FROM server AS develop

ENV COLUMNS="${COLUMNS:-120}"
ENV PLACK_ENV=development

USER root

COPY t t

RUN \
    --mount=type=cache,target=/root/.perl-cpm \
<<EOT
    cpm install --show-build-log-on-failure --resolver=snapshot --with-develop --with-test
    chown -R metacpan:users ./
EOT

USER metacpan

################### Production Server
FROM develop AS test

CMD [ "prove", "-r", "-l", "-j", "2", "t" ]

################### Production Server
FROM server AS production

USER metacpan
