-- Runs once on first container start (docker-entrypoint-initdb.d)
-- Creates three isolated databases — one per service.
-- Each service only has credentials to its own database.

CREATE DATABASE warden_gateway_db;
CREATE DATABASE warden_engine_db;
CREATE DATABASE warden_brain_db;

-- TimescaleDB is pre-installed in the image; enable it per database.
-- The gateway uses hypertables for time-series sensor readings.
\connect warden_gateway_db
CREATE EXTENSION IF NOT EXISTS timescaledb;

-- pgvector will be added here for warden_brain_db in a later phase.
-- \connect warden_brain_db
-- CREATE EXTENSION IF NOT EXISTS vector;
