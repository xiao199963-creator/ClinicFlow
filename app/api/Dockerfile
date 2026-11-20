FROM python:3.12.16-alpine3.24@sha256:c5ba3deef00c7758561a0f03c26f44f10589263d40e732b8748e0d1f38f6dd89
WORKDIR /app
ENV PORT=5000 PYTHONDONTWRITEBYTECODE=1
COPY app/api/requirements.txt .
RUN apk add --no-cache krb5-libs=1.22.3-r0 \
    && pip install --no-cache-dir -r requirements.txt \
    && mkdir -m 0755 /app/certs
COPY app/api/app.py app/api/init_db.py ./
COPY db/schema.sql /app/schema.sql
ADD --chmod=0444 https://truststore.pki.rds.amazonaws.com/global/global-bundle.pem /app/certs/global-bundle.pem
USER 10001:10001
RUN python -c "import ssl; ssl.create_default_context(cafile='/app/certs/global-bundle.pem')"
VOLUME /tmp
EXPOSE 5000
CMD ["sh", "-c", "exec gunicorn --bind \"0.0.0.0:$PORT\" --worker-tmp-dir /tmp --workers 2 app:app"]
