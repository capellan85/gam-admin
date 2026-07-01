#!/bin/bash
cd /Users/guillermocapellan/gam-ui
exec .venv/bin/uvicorn main:app --port "${PORT:-58432}"
