import sqlite3

DB_NAME = "bloom_buddy.db"

METRIC_LABELS = {
    "ph": "pH",
    "moisture": "Soil Moisture (%)",
    "temperature": "Soil Temperature (C)",
    "lux": "Light (lux)",
    "nitrogen": "Nitrogen (mg/kg)",
    "phosphorus": "Phosphorous (mg/kg)",
    "potassium": "Potassium (mg/kg)",
    "ec": "EC (uS/cm)",
}


def get_connection():
    conn = sqlite3.connect(DB_NAME)
    conn.row_factory = sqlite3.Row
    return conn


def initialize_database():
    conn = get_connection()
    cur = conn.cursor()

    cur.execute("""
        CREATE TABLE IF NOT EXISTS plants (
            plant_id    INTEGER PRIMARY KEY AUTOINCREMENT,
            name        TEXT NOT NULL,
            species     TEXT,
            location    TEXT,
            created_at  TEXT NOT NULL DEFAULT (datetime('now'))
        )
    """)

    cur.execute("""
        CREATE TABLE IF NOT EXISTS ideal_ranges (
            metric TEXT PRIMARY KEY,
            label  TEXT NOT NULL
        )
    """)

    cur.execute("""
        CREATE TABLE IF NOT EXISTS sensor_readings (
            reading_id    INTEGER PRIMARY KEY AUTOINCREMENT,
            plant_id      INTEGER NOT NULL,
            recorded_at   TEXT NOT NULL DEFAULT (datetime('now')),
            moisture      REAL,
            temperature   REAL,
            ec            REAL,
            ph            REAL,
            nitrogen      REAL,
            phosphorus    REAL,
            potassium     REAL,
            lux           REAL,
            FOREIGN KEY (plant_id) REFERENCES plants(plant_id)
        )
    """)

    for metric, label in METRIC_LABELS.items():
        cur.execute("""
            INSERT OR IGNORE INTO ideal_ranges (metric, label)
            VALUES (?, ?)
        """, (metric, label))

    conn.commit()
    conn.close()


def add_plant(name: str, species: str | None, location: str | None):
    conn = get_connection()
    cur = conn.cursor()

    cur.execute("""
        INSERT INTO plants (name, species, location)
        VALUES (?, ?, ?)
    """, (name, species, location))

    plant_id = cur.lastrowid

    cur.execute("""
        SELECT plant_id, name, species, location, created_at
        FROM plants
        WHERE plant_id = ?
    """, (plant_id,))

    row = cur.fetchone()
    conn.commit()
    conn.close()

    return dict(row)


def list_plants():
    conn = get_connection()
    cur = conn.cursor()

    cur.execute("""
        SELECT plant_id, name, species, location, created_at
        FROM plants
        ORDER BY plant_id
    """)

    rows = cur.fetchall()
    conn.close()

    return [dict(r) for r in rows]


def get_plant(plant_id: int):
    conn = get_connection()
    cur = conn.cursor()

    cur.execute("""
        SELECT plant_id, name, species, location, created_at
        FROM plants
        WHERE plant_id = ?
    """, (plant_id,))

    row = cur.fetchone()
    conn.close()

    return dict(row) if row else None


def delete_plant(plant_id: int):
    conn = get_connection()
    cur = conn.cursor()

    cur.execute("DELETE FROM sensor_readings WHERE plant_id = ?", (plant_id,))
    cur.execute("DELETE FROM plants WHERE plant_id = ?", (plant_id,))
    deleted = cur.rowcount > 0

    conn.commit()
    conn.close()

    return deleted


def update_plant_species(plant_id: int, species: str | None):
    conn = get_connection()
    cur = conn.cursor()

    cur.execute("""
        UPDATE plants
        SET species = ?
        WHERE plant_id = ?
    """, (species, plant_id))

    conn.commit()

    cur.execute("""
        SELECT plant_id, name, species, location, created_at
        FROM plants
        WHERE plant_id = ?
    """, (plant_id,))
    row = cur.fetchone()
    conn.close()

    return dict(row) if row else None


def add_sensor_reading(plant_id: int, readings: dict):
    allowed_cols = set(METRIC_LABELS.keys())
    filtered = {k: v for k, v in readings.items() if k in allowed_cols and v is not None}

    if not filtered:
        raise ValueError("No valid sensor values to record.")

    conn = get_connection()
    cur = conn.cursor()

    cur.execute("SELECT plant_id FROM plants WHERE plant_id = ?", (plant_id,))
    plant = cur.fetchone()
    if not plant:
        conn.close()
        raise ValueError(f"No plant found with ID {plant_id}")

    cols = ", ".join(filtered.keys())
    params = ", ".join(["?"] * len(filtered))
    values = list(filtered.values())

    cur.execute(f"""
        INSERT INTO sensor_readings (plant_id, {cols})
        VALUES (?, {params})
    """, [plant_id] + values)

    reading_id = cur.lastrowid

    cur.execute("""
        SELECT *
        FROM sensor_readings
        WHERE reading_id = ?
    """, (reading_id,))
    row = cur.fetchone()

    conn.commit()
    conn.close()

    return dict(row)


def get_readings_for_plant(plant_id: int):
    conn = get_connection()
    cur = conn.cursor()

    cur.execute("""
        SELECT *
        FROM sensor_readings
        WHERE plant_id = ?
        ORDER BY recorded_at DESC, reading_id DESC
    """, (plant_id,))

    rows = cur.fetchall()
    conn.close()

    return [dict(r) for r in rows]