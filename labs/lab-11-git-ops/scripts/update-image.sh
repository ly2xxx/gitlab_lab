#!/bin/bash
# Script to update Docker base images systematically

set -e

DOCKERFILE_PATH="${1:-sample-app/Dockerfile}"

if [ ! -f "$DOCKERFILE_PATH" ]; then
    echo "Error: Dockerfile not found at $DOCKERFILE_PATH"
    exit 1
fi

echo "Updating Docker base images in $DOCKERFILE_PATH"

# Backup original file
cp "$DOCKERFILE_PATH" "${DOCKERFILE_PATH}.backup"

# Update Python images
sed -i 's/FROM python:3\.9/FROM python:3.11/g' "$DOCKERFILE_PATH"
sed -i 's/FROM python:3\.10/FROM python:3.11/g' "$DOCKERFILE_PATH"

# Update Node.js images
sed -i 's/FROM node:16/FROM node:18/g' "$DOCKERFILE_PATH"
sed -i 's/FROM node:17/FROM node:18/g' "$DOCKERFILE_PATH"

# Update Alpine images
sed -i 's/FROM alpine:3\.15/FROM alpine:3.18/g' "$DOCKERFILE_PATH"
sed -i 's/FROM alpine:3\.16/FROM alpine:3.18/g' "$DOCKERFILE_PATH"
sed -i 's/FROM alpine:3\.17/FROM alpine:3.18/g' "$DOCKERFILE_PATH"

# Update Ubuntu images
sed -i 's/FROM ubuntu:20\.04/FROM ubuntu:22.04/g' "$DOCKERFILE_PATH"
sed -i 's/FROM ubuntu:21\.04/FROM ubuntu:22.04/g' "$DOCKERFILE_PATH"

# Update Nginx images
sed -i 's/FROM nginx:1\.20/FROM nginx:1.24/g' "$DOCKERFILE_PATH"
sed -i 's/FROM nginx:1\.21/FROM nginx:1.24/g' "$DOCKERFILE_PATH"

echo "Base image updates completed!"

# Show differences
if command -v diff > /dev/null; then
    echo "Changes made:"
    diff "${DOCKERFILE_PATH}.backup" "$DOCKERFILE_PATH" || true
fi