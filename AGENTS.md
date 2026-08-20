# Memory Story — Codex Instructions

## Project

Memory Story is a private memories application built around Stories, participants,
memories, locations, media, timeline, and Story Playback.

The repository contains:
- a Java/Spring Boot backend;
- a Flutter mobile application;
- project documentation in `/docs`.

## Source of Truth

Documentation in `/docs` is the source of truth for product requirements,
business rules, domain rules, API contracts, architecture, security, and roadmap.

Before changing code:
1. Read only the documentation relevant to the requested task.
2. Inspect the existing implementation and follow established project patterns.
3. Do not scan all documentation unless explicitly requested.
4. If the requested change conflicts with the documentation, stop and report the
   conflict instead of silently choosing a different design.
5. Do not implement functionality that belongs to a future roadmap phase unless
   explicitly requested.

Follow YAGNI. Do not add speculative abstractions or future functionality.

## Backend

Backend stack:
- Java 21
- Spring Boot
- Spring MVC
- Spring Security
- Spring Validation
- Spring JDBC / JdbcClient
- PostgreSQL
- PostGIS
- Flyway
- Gradle Kotlin DSL

Rules:
- Do NOT use Hibernate.
- Do NOT use JPA or Spring Data JPA.
- Prefer existing project patterns over introducing new patterns.
- Keep SQL explicit and predictable.
- Preserve feature-based package organization.
- Respect existing domain and application boundaries.
- Keep authorization centralized according to the existing security architecture.
- Treat all client input as untrusted.
- Do not weaken Story-based access control.

## Flutter

Mobile stack:
- Flutter
- Riverpod
- Dio
- go_router
- flutter_secure_storage
- MapLibre

Rules:
- Preserve the existing feature-based architecture.
- Follow existing Riverpod/state-management patterns.
- Keep UI, application state, and infrastructure concerns separated according to
  the existing project architecture.
- Map provider details must remain behind the existing replaceable map-source
  configuration boundary.
- Do not couple domain/application logic to OpenFreeMap or another map provider.

## Scope

Make the smallest change that fully satisfies the requested task.

Do NOT:
- refactor unrelated code;
- rename unrelated classes/files;
- reformat unrelated files;
- introduce speculative abstractions;
- add dependencies unless required by the task;
- change public contracts unless required by the task;
- implement future features "for completeness";
- modify documentation unless explicitly requested.

When an existing implementation provides a suitable pattern, reuse that pattern
instead of inventing a new one.

## Documentation

Do NOT edit files in `/docs` unless explicitly instructed to do so.

If code changes require a documentation or ADR update:
- do not modify the documentation;
- report exactly which document and section should be updated;
- briefly describe the required change.

The documentation update will be performed manually.

## Commands and Verification

Do NOT run:
- Gradle builds;
- Gradle tests;
- Gradle compile tasks;
- dependency resolution;
- Flyway migrations;
- Docker or Docker Compose;
- Testcontainers;
- Flutter tests;
- flutter analyze;
- flutter pub get;
- flutter run;
- application startup commands;
- other long-running or potentially blocking commands.

Do not run commands merely to "verify" the implementation.

Static inspection of relevant source files is allowed.

After making changes, provide the commands that the developer can run manually
to verify the implementation.

## Dependencies

Do not add or upgrade dependencies unless the task explicitly requires it.

If a new dependency appears necessary:
1. explain why the existing stack is insufficient;
2. identify the proposed dependency;
3. do not install or resolve it unless explicitly requested.

## Security

Memory Story contains private user memories and media.

Security-sensitive changes must preserve:
- authentication;
- Story-based authorization;
- participant permissions;
- IDOR protection;
- private media access;
- input validation;
- secret/token confidentiality.

Never log:
- JWT access tokens;
- refresh tokens;
- invite tokens;
- Google ID tokens;
- passwords, credentials, or secrets.

Never expose PostgreSQL, object-storage credentials, internal storage keys, or
other infrastructure secrets through API responses or logs.

## Working Style

For each task:
1. inspect the relevant existing code;
2. inspect only the relevant documentation;
3. identify the existing implementation pattern;
4. make the minimal required change;
5. avoid unrelated cleanup;
6. report anything that prevents a documentation-compliant implementation.

Do not spend time explaining obvious code before making the requested change.

## Final Response

Keep the final response concise.

Include only:
1. files changed;
2. a short summary of what changed;
3. important assumptions or documentation conflicts, if any;
4. manual verification commands for the developer to run.

Do not include long tutorials or repeat the task description.