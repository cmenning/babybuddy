FROM node:20-slim AS assets

WORKDIR /build
COPY package.json package-lock.json gulpfile.js gulpfile.config.js ./
RUN npm install --ignore-scripts
COPY . .
RUN npx gulp build

FROM python:3.12-slim AS builder

RUN apt-get update && apt-get install -y --no-install-recommends     gcc pkg-config default-libmysqlclient-dev &&     rm -rf /var/lib/apt/lists/*

RUN python -m venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt mysqlclient==2.2.7

FROM python:3.12-slim

ENV PYTHONDONTWRITEBYTECODE=1     PYTHONUNBUFFERED=1     DJANGO_SETTINGS_MODULE=babybuddy.settings.base     PATH="/opt/venv/bin:$PATH"

WORKDIR /app

RUN apt-get update && apt-get install -y --no-install-recommends     libmariadb3 &&     rm -rf /var/lib/apt/lists/*

COPY --from=builder /opt/venv /opt/venv

COPY . .
COPY --from=assets /build/babybuddy/static/babybuddy/ /app/babybuddy/static/babybuddy/

RUN python manage.py collectstatic --noinput

VOLUME ["/app/data", "/app/media"]

EXPOSE 80

CMD ["bash", "-c", "python manage.py migrate && gunicorn babybuddy.wsgi:application --bind 0.0.0.0:80 --timeout 30 --log-file -"]
