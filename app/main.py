from fastapi import FastAPI, HTTPException, Depends
from pydantic import BaseModel
from sqlalchemy import create_engine, Column, Integer, String
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker, Session
import os
import time
import psycopg2
from fastapi.responses import Response
from prometheus_client import generate_latest, CONTENT_TYPE_LATEST, Counter

DEFAULT_HOST = os.getenv("DB_HOST", "localhost")
DATABASE_URL = f"postgresql://fastapi:fastapi@{DEFAULT_HOST}:5432/fastapidb"

# --- WAIT FOR POSTGRES ---
def wait_for_postgres():
    while True:
        try:
            conn = psycopg2.connect(
                dbname="fastapidb",
                user="fastapi",
                password="fastapi",
                host=DEFAULT_HOST
            )
            conn.close()
            print(f"✅ PostgreSQL at {DEFAULT_HOST} is ready.")
            break
        except Exception as e:
            print(f"⏳ Waiting for PostgreSQL at {DEFAULT_HOST}...", e)
            time.sleep(2)

# 🛠️ Only wait if env var explicitly set
if os.getenv("WAIT_FOR_DB", "false").lower() == "true":
    wait_for_postgres()
# --- DATABASE SETUP ---
engine = create_engine(DATABASE_URL, echo=True)
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
Base = declarative_base()

# --- MODEL ---
class ItemModel(Base):
    __tablename__ = "items"
    id = Column(Integer, primary_key=True, index=True)
    name = Column(String, nullable=False)
    description = Column(String, default="")

# --- TABLE CREATION ---
print("🔧 Creating tables (if not exist)...")
Base.metadata.create_all(bind=engine)
print("✅ Table check complete.")

# --- FASTAPI SETUP ---
app = FastAPI()

class Item(BaseModel):
    name: str
    description: str = ""

def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()

@app.post("/items")
def create_item(item: Item, db: Session = Depends(get_db)):
    db_item = ItemModel(name=item.name, description=item.description)
    db.add(db_item)
    db.commit()
    db.refresh(db_item)
    return db_item

@app.get("/items/{item_id}")
def get_item(item_id: int, db: Session = Depends(get_db)):
    item = db.query(ItemModel).filter(ItemModel.id == item_id).first()
    if not item:
        raise HTTPException(status_code=404, detail="Item not found")
    return item

@app.put("/items/{item_id}")
def update_item(item_id: int, item: Item, db: Session = Depends(get_db)):
    db_item = db.query(ItemModel).filter(ItemModel.id == item_id).first()
    if not db_item:
        raise HTTPException(status_code=404, detail="Item not found")
    db_item.name = item.name
    db_item.description = item.description
    db.commit()
    db.refresh(db_item)
    return db_item

@app.delete("/items/{item_id}")
def delete_item(item_id: int, db: Session = Depends(get_db)):
    db_item = db.query(ItemModel).filter(ItemModel.id == item_id).first()
    if not db_item:
        raise HTTPException(status_code=404, detail="Item not found")
    db.delete(db_item)
    db.commit()
    return {"message": f"Item {item_id} deleted"}

@app.get("/metrics")
def metrics():
    return Response(generate_latest(), media_type=CONTENT_TYPE_LATEST)
