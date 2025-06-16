#!/bin/bash
# file: utils.sh

message() {
    echo "[$(date +"%m-%d-%Y %H:%M:%S")]: $1" | tee -a "$LOG_FILE"
}