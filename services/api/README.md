## FastAPI + Keycloak Example

This directory contains a minimal FastAPI service configured to authenticate
users via [Keycloak](https://www.keycloak.org/) using the
`fastapi-keycloak` library.

### Configuration

All Keycloak settings can be configured through environment variables or the
`.env` file in this directory. Copy `.env.example` to `.env` and update the
values as needed:

```
KEYCLOAK_SERVER_URL=http://localhost:8080/
KEYCLOAK_REALM=master
KEYCLOAK_CLIENT_ID=fastapi
KEYCLOAK_CLIENT_SECRET=
KEYCLOAK_ADMIN_CLIENT_SECRET=
KEYCLOAK_CALLBACK_URI=http://localhost:8000/auth/callback
```

Update these values to match your Keycloak installation.

### Running the API

Install dependencies with [Poetry](https://python-poetry.org/):

```bash
poetry install
```

Then start the server:

```bash
poetry run uvicorn app.main:app --reload
```

The API exposes a `/protected` route which requires authentication. Visit
`/auth/login` in your browser to log in using Keycloak and obtain a token.
