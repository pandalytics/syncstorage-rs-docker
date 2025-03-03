FROM rust:latest

WORKDIR /app

RUN apt-get update && apt-get install -y \
    python3-virtualenv \
    python3-pip \
    default-mysql-client \
    && rm -rf /var/lib/apt/lists/*

RUN git clone https://github.com/mozilla-services/syncstorage-rs ./ \
    && cargo install --path ./syncserver --no-default-features --features=syncstorage-db/mysql --locked \
    && cargo install diesel_cli --no-default-features --features 'mysql'

RUN virtualenv venv \
    && venv/bin/pip install -r requirements.txt \
    && venv/bin/pip install -r tools/tokenserver/requirements.txt \
    && venv/bin/pip install pyopenssl==22.1.0

COPY entrypoint.sh /
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
