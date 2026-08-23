# eDoktor

Full-stack project for the Razvoj Softvera 2 course @ FIT. **Index number: IB210059.**
The SQL Server database is named **`210059`** (index number without the `IB` prefix, per the assignment).
**eDoktor** is an e-Health platform that connects patients with doctors digitally: search doctors by specialization, book appointments, do online video consultations, view your medical record + e-prescriptions, and pay via PayPal.

It uses a microservice-style architecture (REST API + Worker), .NET 8 / SQL Server / RabbitMQ / Redis, a Flutter desktop app for administrators, and a Flutter mobile app for patients.

## Table of Contents
- [Project Overview](#project-overview)
- [Tech Stack](#tech-stack)
- [Features](#features)
- [Getting Started](#getting-started)
- [Credentials](#credentials)
- [PayPal Sandbox](#paypal-sandbox)
- [Doctor Recommendation System](#doctor-recommendation-system)
- [Messaging (RabbitMQ)](#messaging-rabbitmq)
- [Real-time notifications (SignalR)](#real-time-notifications-signalr)
- [Appointment State Machine](#appointment-state-machine)

## Project Overview
- Patients register/login on the **mobile app**, search doctors by specialization or name, book appointments from a calendar of available slots (in-person or online), pay with PayPal, attend video consultations, view their **electronic medical record** (visits, prescriptions, lab results), and receive real-time notifications.
- Administrators use the **desktop app** to manage doctors, specializations, clinics, patients, appointments (including refunds for cancellations >24h before the start time), and view reports.
- Doctors are managed accounts created by the admin; they can also log in to mark appointments as completed, add medical-record entries, and issue prescriptions.

## Tech Stack
- **Backend**: .NET 8 (`eDoktor.API`), Entity Framework Core, SQL Server 2022
- **Worker**: .NET 8 (`eDoktor.Worker`) — consumes RabbitMQ queues, sends emails (MailKit)
- **Messaging**: RabbitMQ 3.13
- **Cache**: Redis 7 (used by the recommender for cached doctor rankings)
- **Auth**: JWT bearer tokens, BCrypt password hashing
- **Real-time**: SignalR (push notifications to mobile clients)
- **Payments**: PayPal Checkout REST API (Sandbox)
- **Video calls**: Jitsi rooms (the API mints a room id per online appointment)
- **Recommender**: in-process TF-IDF + cosine similarity, weighted by rating / distance / availability (see [below](#doctor-recommendation-system))
- **Desktop app**: Flutter (Windows / macOS / Linux)
- **Mobile app**: Flutter (Android primarily)

## Project Structure

```
eDoktor/
  eDoktor.API/             ASP.NET Core REST API (Swagger at /swagger)
  eDoktor.Model/           DTOs (Requests, Responses, SearchObjects, Messages)
  eDoktor.Services/        Domain services, EF Core context, recommender, state machine,
                           JWT, BCrypt, Redis cache, PayPal client, SignalR hub
  eDoktor.Worker/          RabbitMQ consumer (emails, etc.)
  docker-compose.yml       SQL Server, RabbitMQ, Redis, API, Worker
  .env / .env.example      All secrets and connection strings
UI/
  edoktor_desktop/         Flutter admin app
  edoktor_mobile/          Flutter patient app
```

## Getting Started

### Prerequisites
- Docker + Docker Compose
- Flutter 3.7+ (for running the desktop & mobile apps locally)
- .NET 8 SDK (only if you want to run the backend without Docker)

### Backend
```bash
cd eDoktor
cp .env.example .env        # if you don't already have .env
# (optional) edit PayPal credentials if you want to test live PayPal Sandbox
docker compose up --build
```

This starts SQL Server, RabbitMQ, Redis, the API (port **5190**), and the Worker. The API auto-creates the database schema and seeds initial data (one admin, two patients, four doctors, four specializations, three clinics) on first boot.

- Swagger UI: <http://localhost:5190/swagger>
- RabbitMQ admin: <http://localhost:15672> (guest / guest)

> The Worker degrades gracefully: if no SMTP credentials are configured, it logs emails to stdout instead of sending them. PayPal calls require `PayPal__ClientId` / `PayPal__ClientSecret` from the PayPal Developer dashboard.

### Desktop app
```bash
cd UI/edoktor_desktop
flutter pub get
flutter run -d macos                # or windows / linux
# To override the API base URL:
flutter run -d macos --dart-define=API_BASE_URL=http://localhost:5190
```

### Mobile app (Android emulator)
```bash
cd UI/edoktor_mobile
flutter pub get
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:5190
```
`10.0.2.2` is the Android emulator's alias for the host machine.

## Credentials
All seeded accounts use password **`stringst`**.

| Role     | Username           | Notes |
|----------|--------------------|-------|
| Admin    | `admin`            | Desktop app |
| Patient  | `patient1`         | Mobile app, has location in Sarajevo |
| Patient  | `patient2`         | Mobile app, has location in Banja Luka |
| Doctor   | `doktor.mehic`     | Opća praksa, Klinika Centar Sarajevo |
| Doctor   | `doktor.begic`     | Kardiologija, Klinika Centar Sarajevo |
| Doctor   | `doktor.hodzic`    | Dermatologija, Poliklinika Ilidža |
| Doctor   | `doktor.selimovic` | Neurologija, Poliklinika Banja Luka |

## PayPal Sandbox
Get a Sandbox client id/secret at <https://developer.paypal.com>. Fill in the env vars:

```
PayPal__ClientId=...
PayPal__ClientSecret=...
PayPal__BaseUrl=https://api-m.sandbox.paypal.com
```

The mobile app opens the PayPal approval flow in a `WebView`. After approval, the app calls `/api/payments/paypal/orders/{orderId}/capture`, which marks the appointment as **Confirmed** and publishes a `payment.captured` RabbitMQ message.

Payment is finalized **server-side**: the capture endpoint verifies the order with PayPal, and the `paypal/webhook` endpoint verifies PayPal's signature (using `PayPal__WebhookId`) before acting. To test the full payment flow, configure real PayPal Sandbox credentials in `.env`.

## Doctor Recommendation System
The recommender lives at `eDoktor.Services/Recommender/RecommenderService.cs` and produces personalized doctor rankings using **content-based filtering**.

Formula:
```
score(d) = 0.50 · sim(p,d) + 0.25 · norm(rating(d)) + 0.15 · distDecay(d) + 0.10 · availability(d)
```

- **sim(p,d)** — cosine similarity between the patient's TF-IDF profile vector and the doctor's TF-IDF feature vector. The doctor's vector is built from specialization, sub-keywords from bio, and clinic city. The patient's vector is built from specializations of past appointments + diagnosis / therapy / notes in their medical record.
- **norm(rating(d))** — average review rating, scaled to `[0, 1]` by dividing by 5.
- **distDecay(d)** — `exp(-distance_km / 25)` between the patient's stored coordinates and the clinic's coordinates. Falls back to `1.0` when locations are unknown.
- **availability(d)** — `1` if the doctor has any free time slot in the next 7 days, else `0`.

Each recommendation carries a short reason ("Visoko ocijenjen ljekar", "Ljekar u vašoj blizini", "Dostupan u narednih 7 dana", …) derived from the dominant scoring component.

The full ranked list is cached in **Redis** under `recs:{patientId}` for 6 hours. The cache is invalidated when a patient submits a new review (so future runs reflect the new opinion). Cold-start (no review history) is handled automatically: with an empty patient vector, the similarity term collapses to 0 and the ranking falls back to rating + availability + distance.

## Messaging (RabbitMQ)
The Worker (`eDoktor.Worker`) consumes:

| Queue | Trigger | Effect |
|---|---|---|
| `email` | Any generic `EmailMessage` | Sends an email |
| `appointment.booked` | Patient books an appointment | Sends a confirmation email |
| `appointment.cancelled` | Appointment cancelled | Sends a cancellation email; `ShouldRefund=true` if cancelled ≥24h before start while paid |
| `appointment.reminder` | Reminder due (24h / 1h) | Sends a reminder email |
| `payment.captured` | PayPal capture succeeded | Sends a receipt; appointment is also marked `Confirmed` |
| `prescription.issued` | Doctor issues an e-prescription | Notifies the patient |
| `doctor.created` | Admin creates a doctor account | Emails the doctor their temporary password |

## Real-time notifications (SignalR)
The API exposes a hub at `/hubs/notifications` (JWT-authenticated; the mobile app passes the token via `?access_token=...`). The `NotificationService` writes a row to the `Notifications` table **and** pushes the event to the user's `user-{id}` SignalR group. The mobile app's `NotificationProvider` subscribes via `signalr_netcore` and refreshes the bell badge in real time.

## Appointment State Machine
Implemented in `eDoktor.Services/AppointmentStateMachine/`. States are stored as strings on the `Appointment.StateMachine` column. Transitions are centralized and validated server-side.

```
   create
  ┌──────►  Pending  ─── PayPal capture ──►  Confirmed  ─── doctor marks done ──►  Completed
  │            │                                  │
  │            └── cancel (server unbooks slot, no refund)
  │                                               │
  │                                               └── cancel (≥24h before start + paid -> Worker refunds; <24h -> no refund)
  │                                                                                 ↓
  └────────────────────────────────────────────────────────────────────────────► Cancelled
```

A review can only be created against an appointment in `Completed` state, enforced in `ReviewService`.

## Differences vs. eProdaja
- **Services, not products**: appointments and consultations, not items in a cart.
- **Video consultations** (Jitsi rooms minted per online appointment).
- **Electronic medical record**: visits / prescriptions / lab results, master–details UX on mobile.
- **E-prescriptions** with line items (medication, dosage, frequency, duration).
- **Calendar-based booking** with per-doctor time slots, not stock and cart.
- **TF-IDF + cosine recommender** with the weighted scoring formula above, instead of category-based product suggestions.
- **PayPal** for online payment, with admin-initiated refunds for cancellations.
- **Real-time SignalR notifications** for appointment events, prescriptions, payments.
