import datetime
import json
import logging
import os
import sys

import pymysql
from flask import Flask, jsonify, request

APP_ENV = os.environ.get("APP_ENV", "local")
LOG_LEVEL = os.environ.get("LOG_LEVEL", "INFO").upper()
SLOT_HOURS = list(range(9, 17))
STATUSES = ("booked", "attended", "cancelled")


class JsonFormatter(logging.Formatter):
    def format(self, record):
        payload = {
            "time": datetime.datetime.utcnow().isoformat() + "Z",
            "level": record.levelname,
            "env": APP_ENV,
            "message": record.getMessage(),
        }
        extra = getattr(record, "extra_fields", None)
        if extra:
            payload.update(extra)
        return json.dumps(payload)


handler = logging.StreamHandler(sys.stdout)
handler.setFormatter(JsonFormatter())
logger = logging.getLogger("clinicflow")
logger.handlers = [handler]
logger.setLevel(LOG_LEVEL)
logger.propagate = False

app = Flask(__name__)


def get_conn():
    ca = os.environ.get("DB_SSL_CA")
    ssl_options = {"ca": ca} if ca else None
    return pymysql.connect(
        host=os.environ["DB_HOST"],
        port=int(os.environ.get("DB_PORT", "3306")),
        user=os.environ["DB_USER"],
        password=os.environ["DB_PASSWORD"],
        database=os.environ.get("DB_NAME", "clinicflow"),
        cursorclass=pymysql.cursors.DictCursor,
        autocommit=True,
        connect_timeout=5,
        ssl=ssl_options,
    )


def query(sql, args=None, fetch=True):
    conn = get_conn()
    try:
        with conn.cursor() as cur:
            cur.execute(sql, args or ())
            if fetch:
                return cur.fetchall()
            return cur.lastrowid
    finally:
        conn.close()


def clean_booking(row):
    return {
        "id": row["id"],
        "clinic_id": row["clinic_id"],
        "patient_name": row["patient_name"],
        "mobile": row["mobile"],
        "slot_date": row["slot_date"].isoformat(),
        "slot_hour": row["slot_hour"],
        "status": row["status"],
    }


def parse_date(value):
    try:
        return datetime.date.fromisoformat(value)
    except (TypeError, ValueError):
        return None


@app.after_request
def log_request(response):
    logger.info(
        "request",
        extra={"extra_fields": {"method": request.method, "path": request.path, "status": response.status_code}},
    )
    return response


@app.get("/health")
def health():
    try:
        query("SELECT 1")
    except Exception as exc:
        logger.error("health check failed", extra={"extra_fields": {"error": str(exc)}})
        return jsonify({"status": "unhealthy"}), 503
    return jsonify({"status": "ok", "env": APP_ENV})


@app.get("/api/clinics")
def clinics():
    return jsonify(query("SELECT id, name, suburb FROM clinics ORDER BY id"))


@app.get("/api/slots")
def slots():
    clinic_id = request.args.get("clinic_id", type=int)
    slot_date = parse_date(request.args.get("date"))
    if not clinic_id or not slot_date:
        return jsonify({"error": "clinic_id and date (YYYY-MM-DD) are required"}), 400
    rows = query(
        "SELECT slot_hour FROM bookings WHERE clinic_id = %s AND slot_date = %s AND status <> 'cancelled'",
        (clinic_id, slot_date),
    )
    taken = {row["slot_hour"] for row in rows}
    return jsonify([{"hour": h, "available": h not in taken} for h in SLOT_HOURS])


@app.post("/api/bookings")
def create_booking():
    body = request.get_json(silent=True) or {}
    slot_date = parse_date(body.get("slot_date"))
    clinic_id = body.get("clinic_id")
    hour = body.get("slot_hour")
    name = (body.get("patient_name") or "").strip()
    mobile = (body.get("mobile") or "").strip()
    if not slot_date or not isinstance(clinic_id, int) or hour not in SLOT_HOURS or not name or not mobile:
        return jsonify({"error": "clinic_id, slot_date, slot_hour, patient_name and mobile are required"}), 400
    try:
        new_id = query(
            "INSERT INTO bookings (clinic_id, patient_name, mobile, slot_date, slot_hour) VALUES (%s, %s, %s, %s, %s)",
            (clinic_id, name, mobile, slot_date, hour),
            fetch=False,
        )
    except pymysql.err.IntegrityError as exc:
        if exc.args and exc.args[0] == 1062:
            return jsonify({"error": "slot already taken"}), 409
        return jsonify({"error": "invalid clinic"}), 400
    return jsonify({"id": new_id}), 201


@app.get("/api/bookings")
def list_bookings():
    clinic_id = request.args.get("clinic_id", type=int)
    slot_date = parse_date(request.args.get("date"))
    if not clinic_id or not slot_date:
        return jsonify({"error": "clinic_id and date (YYYY-MM-DD) are required"}), 400
    rows = query(
        "SELECT id, clinic_id, patient_name, mobile, slot_date, slot_hour, status "
        "FROM bookings WHERE clinic_id = %s AND slot_date = %s ORDER BY slot_hour",
        (clinic_id, slot_date),
    )
    return jsonify([clean_booking(row) for row in rows])


@app.patch("/api/bookings/<int:booking_id>")
def update_booking(booking_id):
    body = request.get_json(silent=True) or {}
    status = body.get("status")
    if status not in STATUSES:
        return jsonify({"error": "status must be one of booked, attended, cancelled"}), 400
    query("UPDATE bookings SET status = %s WHERE id = %s", (status, booking_id), fetch=False)
    return jsonify({"id": booking_id, "status": status})


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)
