from fastapi import FastAPI
from routers import http_routes, websocket_routes

app = FastAPI()

# Include Routers
app.include_router(http_routes.router)
app.include_router(websocket_routes.router)