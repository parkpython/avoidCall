# Backend Server

This directory contains the Python backend server for the Twilio Media Streams project.

## Setup

1.  **Create a virtual environment:**
    ```bash
    python3 -m venv venv
    source venv/bin/activate
    ```

2.  **Install dependencies:**
    ```bash
    pip install -r requirements.txt
    ```

3.  **Set up environment variables:**
    -   Copy the `.env.example` file to a new file named `.env`.
    -   Fill in the required credentials in the `.env` file.

    ```bash
    cp .env.example .env
    ```

## Running the server

```bash
uvicorn main:app --reload
```

The server will be running at `http://127.0.0.1:8000`.
