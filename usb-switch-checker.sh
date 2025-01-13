#!/bin/bash

# VCP codes - successfully tested on a Samsung CRG9 (C49RG9x)
VCP_CODE_DP1="0x09"
#VCP_CODE_DP2="0x03"
VCP_CODE_HDMI="0x06"

# Define usage function
usage() {
  echo "Usage: $0 [DEVICE_ID] [REQUIRED_COUNT]"
  echo "Example: $0 00f0:00f0 2"
  echo "This script monitors USB devices and runs 'ddcutil setvcp' if at least [REQUIRED_COUNT] devices with ID [DEVICE_ID] are detected."
  exit 1
}

# Function to check if required tools are installed
check_tools() {
  local tools=("lsusb" "grep" "ddcutil")
  for tool in "${tools[@]}"; do
    if ! command -v "$tool" &>/dev/null; then
      echo "Error: $tool is not installed. Please install it to run this script."
      exit 1
    fi
  done

  # Check if the i2c-dev module is loaded
  if lsmod | grep -q i2c_dev; then
    echo "The i2c-dev module is loaded."
  else
    echo "The i2c-dev module is NOT loaded."
    # Check if the module is built into the kernel
    if grep -q CONFIG_I2C_CHARDEV=y /boot/config-$(uname -r); then
      echo "The i2c-dev module is built into the kernel."
      echo "You can use it directly without loading it as a module."
    else
      echo "The i2c-dev module is NOT built into the kernel."
      # Suggest steps to resolve the issue
      echo "To resolve this issue, you can do the following:"
      echo "1. Load the module manually by running: sudo modprobe i2c-dev"
      echo "2. If that fails, add 'i2c-dev' to /etc/modules or create a file in /etc/modules-load.d/ with 'i2c-dev' in it:"
      echo "   sudo -i"
      echo "   echo i2c_dev > /etc/modules-load.d/i2c_dev.conf"
      echo "3. If you need to compile the kernel, make sure to enable 'I2C device interface' in your kernel configuration."
      echo "   You can check this in your kernel config file located at /boot/config-$(uname -r)."
      exit 1
    fi
  fi
}

# Validate that required tools are installed
check_tools

# Require values for device ID and required count
# Validate input arguments
#if [ "$#" -ne 2 ]; then
#  usage
#fi
#DEVICE_ID="$1"
#REQUIRED_COUNT="$2"

# Set default values for device ID and required count
DEVICE_ID="${1:-05e3:0610}" # Default device ID
REQUIRED_COUNT="${2:-3}"    # Default required count

# Capture the initial lsusb output
PREVIOUS_OUTPUT=$(lsusb | grep -E "Bus [0-9]+ Device [0-9]+: ID $DEVICE_ID .*")
# Initialize a variable to track if the command has been executed
COMMAND_EXECUTED=false

# Infinite loop to monitor changes
while true; do
  # Capture the current lsusb output
  CURRENT_OUTPUT=$(lsusb | grep -E "Bus [0-9]+ Device [0-9]+: ID $DEVICE_ID .*")

  # Check for differences between previous and current outputs
  if [ "$PREVIOUS_OUTPUT" != "$CURRENT_OUTPUT" ]; then
    # Count matches for the specific regex in the current output
    MATCH_COUNT=$(echo "$CURRENT_OUTPUT" | wc -l)

    if [ "$MATCH_COUNT" -ge "$REQUIRED_COUNT" ]; then
      # Continue if at least [REQUIRED_COUNT] of matches found and not already executed
      if [ "$COMMAND_EXECUTED" = false ]; then
        # Switch to DP1
        ddcutil --display 1 setvcp 60 "$VCP_CODE_DP1"
        COMMAND_EXECUTED=true # Set the flag to true after execution
      fi
    else
      # Less than [REQUIRED_COUNT] of matches and not already executed
      if [ "$COMMAND_EXECUTED" = false ]; then
        # Switch to HDMI
        ddcutil --display 1 setvcp 60 "$VCP_CODE_HDMI"
        COMMAND_EXECUTED=true # Set the flag to true after execution
      fi
    fi

    # Update previous output for the next iteration
    PREVIOUS_OUTPUT="$CURRENT_OUTPUT"
  else
    # Reset command executed flag (when no change is detected)
    COMMAND_EXECUTED=false
  fi

  # Sleep for a brief moment before checking again
  sleep 2
done