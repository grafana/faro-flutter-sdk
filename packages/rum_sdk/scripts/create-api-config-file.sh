#!/bin/bash

# Get the directory of the currently executing script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Define the path to the api-config.json file in the parent directory
API_CONFIG_FILE="$SCRIPT_DIR/../example/api-config.json"

# Use default values if environment variables are not defined
FARO_API_KEY="${FARO_API_KEY:- }"

# Create the api-config.json file with the environment variables
cat > $API_CONFIG_FILE <<EOL
{
  "FARO_API_KEY": "$FARO_API_KEY",
  "FARO_COLLECTOR_URL": "$FARO_COLLECTOR_URL"
}
EOL

echo "api-config.json has been created."