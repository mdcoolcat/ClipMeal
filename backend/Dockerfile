FROM python:3.11-slim

# Install system dependencies (ffmpeg for yt-dlp, deno for YouTube)
RUN apt-get update && apt-get install -y \
    ffmpeg \
    curl \
    git \
    unzip \
    && rm -rf /var/lib/apt/lists/*

# Install deno
RUN curl -fsSL https://deno.land/install.sh | sh
ENV PATH="/root/.deno/bin:$PATH"

# Set working directory
WORKDIR /app

# Copy and install Python dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application code
COPY . .

# Create temp directory for video downloads
RUN mkdir -p /tmp/recipe-keeper

# Expose port (Render sets PORT env variable automatically)
EXPOSE 8000

# Start uvicorn server
# Render sets $PORT environment variable, uvicorn will use it
CMD uvicorn main:app --host 0.0.0.0 --port ${PORT:-8000} --log-level info
