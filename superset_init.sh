#!/bin/bash
superset init
superset fab create-admin \
              --username admin \
              --firstname Superset \
              --lastname Admin \
              --email admin@superset.com \
              --password admin
superset db upgrade
superset load_examples
superset init
superset run --port=8088 --host=0.0.0.0