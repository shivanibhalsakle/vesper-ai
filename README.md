# Vesper

Personalized sunrise/sunset discovery app — ranks real, nearby public viewing
spots against your own sky-color taste, rather than a generic quality score.

Monorepo: `backend/` (FastAPI) and `client/` (Flutter, added in the next phase).

## Backend — local setup

Requires Docker Desktop.

```bash
cd backend
cp .env.example .env
docker compose up --build
```

Then check `http://localhost:8010/health`.

(Port 8010 is used instead of the default 8000 because another local dev server on this machine already occupies 8000.)

To run tests locally (outside Docker), create a virtualenv and install dev deps:

```bash
cd backend
python -m venv .venv
.venv\Scripts\activate
pip install -r requirements-dev.txt
pytest
```

## Build order

See project brief / conversation history for full phase breakdown. Backend
recommendation loop is complete: Astronomy, Weather, Scoring, and Places
services, combined behind `POST /session`. Next: the Flutter client's
session-setup and results screens.
