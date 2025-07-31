# Sample Dockerfile for testing the evergreen scanner
FROM python:3.9.18-slim
FROM node:18.17.0-alpine
FROM nginx:1.24.0
FROM redis:7.0.11-alpine

WORKDIR /app

# Install dependencies
COPY requirements.txt .
RUN pip install -r requirements.txt

# Copy application code
COPY . .

# Expose port
EXPOSE 8000

# Run the application
CMD ["python", "app.py"]
