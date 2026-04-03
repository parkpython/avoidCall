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

## Development auth admin user

For local or dev-only Supabase testing without email confirmation delivery, use the trusted-only admin creation script from the repo root after installing this backend's dependencies:

```bash
python3 ../scripts/create-dev-admin-user.py
```

Environment loading behavior:

- On Railway, this script reads the service environment variables directly
- For local development, it also falls back to `backend/.env` or repo-root `.env` if present

Required env values:

- `SUPABASE_URL`
- `SUPABASE_SERVICE_ROLE_KEY`
- `DEV_ADMIN_EMAIL`
- `DEV_ADMIN_PASSWORD`
- optional: `DEV_ADMIN_NAME`
- optional: `DEV_ADMIN_PLAN_ID`

Railway one-off command example from the repo root:

```bash
python3 scripts/create-dev-admin-user.py
```
