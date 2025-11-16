import os
import httpx
from fastapi import FastAPI, HTTPException
from datetime import datetime

app = FastAPI(title="Service A - API Gateway")

SERVICE_B_URL = os.getenv("SERVICE_B_URL", "http://localhost:8001")

@app.get("/health")
async def health():
    """Health check endpoint for ALB"""
    return {"status": "healthy", "service": "service-a"}

@app.get("/api/hello")
async def hello():
    """Public API endpoint"""
    return {
        "message": "Hello from Service A",
        "timestamp": datetime.utcnow().isoformat(),
        "service": "service-a"
    }

@app.get("/api/info")
async def info():
    """Service information endpoint"""
    return {
        "service": "service-a",
        "version": "1.0.0",
        "description": "API Gateway Service",
        "endpoints": ["/api/hello", "/api/info", "/api/backend"]
    }

@app.get("/api/backend")
async def call_backend():
    """Call Service B and return response"""
    try:
        async with httpx.AsyncClient(timeout=5.0) as client:
            response = await client.get(f"{SERVICE_B_URL}/process")
            return {
                "service_a": "success",
                "service_b_response": response.json(),
                "timestamp": datetime.utcnow().isoformat()
            }
    except httpx.RequestError as e:
        raise HTTPException(
            status_code=503,
            detail=f"Service B unavailable: {str(e)}"
        )
