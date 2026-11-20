FROM python:3.12-slim
WORKDIR /app
ENV PORT=5000 PYTHONDONTWRITEBYTECODE=1
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt && mkdir -m 0755 /app/certs
COPY app.py init_db.py ./
ADD --chmod=0444 https://truststore.pki.rds.amazonaws.com/global/global-bundle.pem /app/certs/global-bundle.pem
USER 10001:10001
RUN python -c "import ssl; ssl.create_default_context(cafile='/app/certs/global-bundle.pem')"
VOLUME /tmp
EXPOSE 5000
CMD ["sh", "-c", "exec gunicorn --bind \"0.0.0.0:$PORT\" --worker-tmp-dir /tmp --workers 2 app:app"]
