# evege

A small college event listing and registration app named evege. The interface is served by
Spring Boot, and event and registration records are stored in PostgreSQL.

Features include searchable and category-filtered upcoming event cards, a gallery
with event-specific photos and community-shared images served locally, secure
account registration and login, and authenticated event registration. Account
passwords are hashed with BCrypt, and the app protects session-based requests
against CSRF.

## Run with Docker Desktop

From this directory, run:

```powershell
docker compose up --build
```

Open [http://localhost:8080](http://localhost:8080). Docker starts the Java app
and PostgreSQL database together. To stop them, press `Ctrl+C`; run
`docker compose down` to stop and remove the containers. The database volume is
kept between runs.

## Run the app directly on Windows

For a normal development setup, install a 64-bit Java 8 (or later) JDK and
PostgreSQL, create the `evege` database and `evege_user` login, then run
`.\mvnw.cmd spring-boot:run` from this directory.

This Windows machine can instead use portable Java and PostgreSQL runtimes
without Docker, WSL, or administrator access. With those runtimes extracted
under `D:\evege-runtime`, run this from the project directory:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\run-evege.ps1
```

The launcher builds the project, initializes the local PostgreSQL database on
first run, starts both services, and leaves database files under `D:`. Open
[http://localhost:8080](http://localhost:8080), and press `Ctrl+C` in the
launcher window to stop the application.

The first launch adds six sample events with dates relative to the current day.
They are stored in PostgreSQL and are not reseeded once events exist.

## Database configuration

The defaults are database `evege`, username `evege_user`, and password
`evege_password`, configured for the included Docker Compose database. Override
them with `PGHOST`, `PGPORT`, `PGDATABASE`, `PGUSER`, and `PGPASSWORD` when
connecting to a different PostgreSQL instance.

## API

- `GET /api/events` — list events, ordered by date
- `/login` — sign-in or create an evege account
- `GET /api/auth/csrf` — obtain the CSRF token used by protected requests
- `POST /api/auth/signup` — create an account with `fullName`, `email`, and `password`
- `POST /api/auth/login` — sign in with `email` and `password`
- `GET /api/auth/me` — check the current session (`204` when signed out)
- `POST /api/auth/logout` — sign out of the current session
- `POST /api/events/{eventId}/registrations` — signed-in users can register with
  `{"fullName":"Alex Morgan","email":"alex@example.com"}`

Passwords must contain at least eight characters; an email address can register
only once for the same event. The site frontend obtains and sends CSRF tokens for
you when signing up, logging in, signing out, and registering for events.
