from ultralytics import YOLO
import os

MODEL_PATH = os.path.join(os.path.dirname(__file__), "best2.pt")
PREMIUM_MODEL_PATH = os.path.join(os.path.dirname(__file__), "premiumIA.pt")

print(f"Loading base YOLO model from {MODEL_PATH}...")
model = YOLO(MODEL_PATH)

print(f"Loading premium YOLO model from {PREMIUM_MODEL_PATH}...")
premium_model = YOLO(PREMIUM_MODEL_PATH)

print("YOLO models loaded.")
