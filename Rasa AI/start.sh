#!/bin/bash
echo 'Starting Rasa on port $PORT...'
exec rasa run -i 0.0.0.0 -p $PORT --enable-api --cors "*" --endpoints endpoints.yml
