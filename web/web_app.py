import logging
import os
import socket

import mysql.connector
from flask import Flask, Response

app = Flask(__name__)
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s %(levelname)s %(message)s",
)

STUDENT_ID = os.environ["STUDENT_ID"]
DB_HOST = os.environ["DB_HOST"]
DB_PORT = int(os.getenv("DB_PORT", "3306"))
APP_PORT = int(os.getenv("APP_PORT", "8080"))
DB_NAME = os.environ["DB_NAME"]
DB_USER = os.environ["DB_USER"]
DB_PASSWORD = os.environ["DB_PASSWORD"]

def query_database():
    connection = None
    cursor = None

    try:
        # Confirm that the Kubernetes Service DNS name resolves.
        socket.getaddrinfo(DB_HOST, DB_PORT, type=socket.SOCK_STREAM)

        connection = mysql.connector.connect(
            host=DB_HOST,
            port=DB_PORT,
            database=DB_NAME,
            user=DB_USER,
            password=DB_PASSWORD,
            connection_timeout=3,
        )

        cursor = connection.cursor()


        cursor.execute("""
            SELECT id, item_name, student_id
            FROM clinic_items
            ORDER BY RAND()
            LIMIT 1
            """
        )

        row = cursor.fetchone()

        if row is None:
            raise RuntimeError("The clinic_items table contains no seeded rows")

        return row

    finally:
        if cursor is not None:
            cursor.close()

        if connection is not None and connection.is_connected():
            connection.close()


@app.get("/")
def index():
    try:
        row = query_database()

        body = (
            f"student_id={STUDENT_ID}\n"
            f"db_service={DB_HOST}\n"
            f"seeded_row_id={row[0]}\n"
            f"seeded_item={row[1]}\n"
            f"seeded_student_id={row[2]}\n"
        )

        app.logger.info("Successful database query: %s", body.strip())

        return Response(
            body,
            status=200,
            mimetype="text/plain",
        )

    except socket.gaierror as exc:
        message = (
            f"student_id={STUDENT_ID}\n"
            f"db_service={DB_HOST}\n"
            f"dns_error={type(exc).__name__}: {exc}\n"
        )

        app.logger.exception(message.strip())

        return Response(
            message,
            status=503,
            mimetype="text/plain",
        )

    except mysql.connector.Error as exc:
        message = (
            f"student_id={STUDENT_ID}\n"
            f"db_service={DB_HOST}\n"
            f"database_error={type(exc).__name__}: {exc}\n"
        )

        app.logger.exception(message.strip())

        return Response(
            message,
            status=503,
            mimetype="text/plain",
        )

    except Exception as exc:
        message = (
            f"student_id={STUDENT_ID}\n"
            f"db_service={DB_HOST}\n"
            f"application_error={type(exc).__name__}: {exc}\n"
        )

        app.logger.exception(message.strip())

        return Response(
            message,
            status=503,
            mimetype="text/plain",
        )


@app.get("/ready")
def ready():
    try:
        query_database()

        return Response(
            f"student_id={STUDENT_ID}\nstatus=ready\n",
            status=200,
            mimetype="text/plain",
        )

    except Exception as exc:
        message = (
            f"student_id={STUDENT_ID}\n"
            f"status=not_ready\n"
            f"error={type(exc).__name__}: {exc}\n"
        )

        app.logger.exception(message.strip())

        return Response(
            message,
            status=503,
            mimetype="text/plain",
        )


@app.get("/live")
def live():
    return Response(
        f"student_id={STUDENT_ID}\nstatus=alive\n",
        status=200,
        mimetype="text/plain",
    )


if __name__ == "__main__":
    app.run(
        host="0.0.0.0",
        port=APP_PORT,
    )
