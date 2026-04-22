import sqlite3
from dataclasses import dataclass, field, asdict
from datetime import datetime
from typing import Optional
import uvicorn
from fastapi import FastAPI, HTTPException, Query
from fastapi.middleware.cors import CORSMiddleware

DB_PATH = "bloom_buddy.db"

app = FastAPI(title="Plant Monitor API", version="1.0.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # tighten this in production
    allow_methods=["*"],
    allow_headers=["*"],
)


# ── Data model ────────────────────────────────────────────────────────────────

@dataclass
class Recommendation:
    plant_id: int
    type: str           # "water" | "fertilize"
    severity: str       # "urgent" | "warning"
    reason: str
    metrics: dict = field(default_factory=dict)
    created_at: str = field(default_factory=lambda: datetime.now().isoformat())


# ── Alert logic ───────────────────────────────────────────────────────────────

def check_water_alerts(conn, plant_id: Optional[int] = None) -> list[Recommendation]:
    plant_filter = "AND plant_id = ?" if plant_id else ""
    params = [plant_id] if plant_id else []

    rows = conn.execute(f"""
        SELECT plant_id, MIN(moisture_pct) AS min_m,
               ROUND((julianday('now') - julianday(MIN(recorded_at))) * 24, 1) AS hrs
        FROM sensor_readings
        WHERE recorded_at >= datetime('now', '-6 hours')
          AND moisture_pct < 25.0
          {plant_filter}
        GROUP BY plant_id
        HAVING hrs >= 2.0
        ORDER BY hrs DESC
    """, params).fetchall()

    alerts = []
    for row_plant_id, min_m, hrs in rows:
        alerts.append(Recommendation(
            plant_id=row_plant_id,
            type="water",
            severity="urgent" if hrs >= 4 else "warning",
            reason=f"Moisture at {min_m:.0f}% for {hrs}h (threshold: 25%)",
            metrics={"moisture_pct": round(min_m, 1), "hours_below": hrs},
        ))
    return alerts


def check_nutrient_alerts(conn, plant_id: Optional[int] = None) -> list[Recommendation]:
    plant_filter = "AND plant_id = ?" if plant_id else ""
    params_recent = [plant_id] if plant_id else []
    params_prior  = [plant_id] if plant_id else []

    rows = conn.execute(f"""
        WITH daily_avg AS (
            SELECT plant_id, DATE(recorded_at) AS day,
                   AVG(nitrogen_mg_kg)   AS n,
                   AVG(phosphorus_mg_kg) AS p,
                   AVG(potassium_mg_kg)  AS k
            FROM sensor_readings
            WHERE recorded_at >= datetime('now', '-6 days')
              {plant_filter}
            GROUP BY plant_id, DATE(recorded_at)
        ),
        recent AS (
            SELECT plant_id, AVG(n) n, AVG(p) p, AVG(k) k
            FROM daily_avg WHERE day >= DATE('now', '-3 days')
            GROUP BY plant_id
        ),
        prior AS (
            SELECT plant_id, AVG(n) n, AVG(p) p, AVG(k) k
            FROM daily_avg WHERE day < DATE('now', '-3 days')
            GROUP BY plant_id
        )
        SELECT r.plant_id, r.n, r.p, r.k, pr.n, pr.p, pr.k
        FROM recent r JOIN prior pr ON r.plant_id = pr.plant_id
    """, params_recent).fetchall()

    alerts = []
    limits = {"N": 150.0, "P": 20.0, "K": 100.0}
    cols   = {"N": (1, 4), "P": (2, 5), "K": (3, 6)}

    for row in rows:
        row_plant_id = row[0]
        low = []
        for nutrient, (ri, pi) in cols.items():
            now_val, before = row[ri], row[pi]
            if (now_val is not None
                    and now_val < limits[nutrient]
                    and (before is None or now_val < before)):
                low.append(f"{nutrient} ({now_val:.0f} < {limits[nutrient]:.0f})")
        if low:
            alerts.append(Recommendation(
                plant_id=row_plant_id,
                type="fertilize",
                severity="warning",
                reason=f"Declining nutrients: {', '.join(low)}",
                metrics={
                    "N": round(row[1], 1) if row[1] else None,
                    "P": round(row[2], 1) if row[2] else None,
                    "K": round(row[3], 1) if row[3] else None,
                },
            ))
    return alerts


# ── Routes ────────────────────────────────────────────────────────────────────

@app.get("/recommendations")
def get_recommendations(plant_id: Optional[int] = Query(None)):
    """Return all active alerts, optionally filtered by plant_id."""
    try:
        with sqlite3.connect(DB_PATH) as conn:
            alerts = (
                check_water_alerts(conn, plant_id)
                + check_nutrient_alerts(conn, plant_id)
            )
        return {"alerts": [asdict(a) for a in alerts], "count": len(alerts)}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@app.get("/plants")
def get_plants():
    """Return all plants with their latest sensor snapshot."""
    try:
        with sqlite3.connect(DB_PATH) as conn:
            rows = conn.execute("""
                SELECT p.plant_id, p.name, p.created_at,
                       s.moisture_pct, s.ph_level,
                       s.nitrogen_mg_kg, s.recorded_at AS last_reading
                FROM plants p
                LEFT JOIN sensor_readings s ON s.reading_id = (
                    SELECT reading_id FROM sensor_readings
                    WHERE plant_id = p.plant_id
                    ORDER BY recorded_at DESC LIMIT 1
                )
                ORDER BY p.plant_id
            """).fetchall()
        return {"plants": [
            {
                "plant_id": r[0], "name": r[1], "created_at": r[2],
                "moisture_pct": r[3], "ph_level": r[4],
                "nitrogen_mg_kg": r[5], "last_reading": r[6],
            }
            for r in rows
        ]}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@app.get("/health")
def health():
    return {"status": "ok", "timestamp": datetime.now().isoformat()}


if __name__ == "__main__":
    uvicorn.run("main:app", host="0.0.0.0", port=8000, reload=True)
