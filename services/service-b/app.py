import os
from fastapi import FastAPI
from datetime import datetime
import random

app = FastAPI(title="Service B - Backend")

@app.get("/health")
async def health():
    """Health check endpoint for ALB"""
    return {"status": "healthy", "service": "service-b"}

@app.get("/process")
async def process():
    """Backend processing endpoint"""
    # Simulate some processing
    processing_time = random.uniform(0.1, 0.5)
    
    return {
        "service": "service-b",
        "status": "processed",
        "processing_time": f"{processing_time:.2f}s",
        "timestamp": datetime.utcnow().isoformat(),
        "data": {
            "result": "success",
            "items_processed": random.randint(10, 100)
        }
    }

@app.get("/internal/status")
async def internal_status():
    """Internal status endpoint"""
    return {
        "service": "service-b",
        "version": "1.0.0",
        "status": "running",
        "uptime": "healthy"
    }
