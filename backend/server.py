from fastapi import FastAPI, UploadFile, File, HTTPException
from pydantic import BaseModel
from PIL import Image
from transformers import pipeline
from datetime import datetime, timezone
import io

from db import (
    initialize_database,
    add_plant,
    list_plants,
    get_plant,
    delete_plant,
    update_plant_species,
    add_sensor_reading,
    get_readings_for_plant,
)

app = FastAPI()

# Load models once at startup
disease_model_id = "Diginsa/Plant-Disease-Detection-Project"
disease_clf = pipeline("image-classification", model=disease_model_id, device=-1)

MODEL_ID = "Sisigoks/FloraSense"
clf = pipeline("image-classification", model=MODEL_ID, device=-1)

# Keep only the latest sensor reading in memory
latest_sensor_data = {
    "moisture": None,
    "temperature": None,
    "ec": None,
    "ph": None,
    "nitrogen": None,
    "phosphorus": None,
    "potassium": None,
    "lux": None,
    "timestamp": None,
}


@app.on_event("startup")
def startup_event():
    initialize_database()


class SensorData(BaseModel):
    moisture: float
    temperature: float
    ec: int
    ph: float
    nitrogen: int
    phosphorus: int
    potassium: int
    lux: float


class PlantCreate(BaseModel):
    name: str
    species: str | None = None
    location: str | None = None


class PlantSpeciesUpdate(BaseModel):
    species: str | None = None


@app.post("/predict")
async def predict(file: UploadFile = File(...), top_k: int = 5):
    data = await file.read()
    img = Image.open(io.BytesIO(data)).convert("RGB")

    preds = clf(img, top_k=top_k)
    labels = [p["label"] for p in preds]

    return {
        "labels": labels,
        "top": labels[0] if labels else None,
    }


@app.post("/disease_predict")
async def disease_predict(file: UploadFile = File(...), top_k: int = 3):
    contents = await file.read()
    img = Image.open(io.BytesIO(contents)).convert("RGB")

    preds = disease_clf(img, top_k=top_k)

    results = [
        {"label": p["label"], "score": float(p["score"])}
        for p in preds
    ]

    return {
        "top": results[0]["label"] if results else None,
        "predictions": results
    }


@app.post("/data")
async def receive_data(data: SensorData):
    global latest_sensor_data

    latest_sensor_data = {
        "moisture": data.moisture,
        "temperature": data.temperature,
        "ec": data.ec,
        "ph": data.ph,
        "nitrogen": data.nitrogen,
        "phosphorus": data.phosphorus,
        "potassium": data.potassium,
        "lux": data.lux,
        "timestamp": datetime.now(timezone.utc).isoformat(),
    }

    print("Received JSON:", latest_sensor_data)
    return {"status": "ok", "message": "Data received"}


@app.get("/latest_data")
async def get_latest_data():
    return latest_sensor_data


@app.post("/plants")
async def create_plant(payload: PlantCreate):
    name = payload.name.strip()
    species = (payload.species or "").strip() or None
    location = (payload.location or "").strip() or None

    if not name:
        raise HTTPException(status_code=400, detail="Plant name is required.")

    plant = add_plant(name=name, species=species, location=location)
    return plant


@app.get("/plants")
async def get_plants():
    return list_plants()


@app.get("/plants/{plant_id}")
async def get_single_plant(plant_id: int):
    plant = get_plant(plant_id)
    if not plant:
        raise HTTPException(status_code=404, detail="Plant not found.")
    return plant


@app.put("/plants/{plant_id}/species")
async def update_species(plant_id: int, payload: PlantSpeciesUpdate):
    plant = get_plant(plant_id)
    if not plant:
        raise HTTPException(status_code=404, detail="Plant not found.")

    updated = update_plant_species(plant_id, (payload.species or "").strip() or None)
    return updated


@app.delete("/plants/{plant_id}")
async def remove_plant(plant_id: int):
    deleted = delete_plant(plant_id)
    if not deleted:
        raise HTTPException(status_code=404, detail="Plant not found.")
    return {"status": "ok"}


@app.post("/plants/{plant_id}/record_latest")
async def record_latest_sensor_snapshot(plant_id: int):
    plant = get_plant(plant_id)
    if not plant:
        raise HTTPException(status_code=404, detail="Plant not found.")

    if latest_sensor_data["timestamp"] is None:
        raise HTTPException(status_code=400, detail="No live sensor data available yet.")

    reading_payload = {
        "moisture": latest_sensor_data["moisture"],
        "temperature": latest_sensor_data["temperature"],
        "ec": latest_sensor_data["ec"],
        "ph": latest_sensor_data["ph"],
        "nitrogen": latest_sensor_data["nitrogen"],
        "phosphorus": latest_sensor_data["phosphorus"],
        "potassium": latest_sensor_data["potassium"],
        "lux": latest_sensor_data["lux"],
    }

    try:
        reading = add_sensor_reading(plant_id, reading_payload)
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))

    return {
        "status": "ok",
        "plant_id": plant_id,
        "reading": reading,
    }


@app.get("/plants/{plant_id}/readings")
async def get_plant_readings(plant_id: int):
    plant = get_plant(plant_id)
    if not plant:
        raise HTTPException(status_code=404, detail="Plant not found.")
    return get_readings_for_plant(plant_id)