# Use a slim Python image with version 3.9
FROM python:3.9-slim

# Set working directory to /app
WORKDIR /app

# Install system dependencies required by PIL, OpenCV, and others
RUN apt-get update && apt-get install -y \
    libglib2.0-0 \
    libsm6 \
    libxext6 \
    libxrender1 \
    && rm -rf /var/lib/apt/lists/*

# Install Python dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
RUN pip install --no-cache-dir torch==2.3.1 torchvision==0.18.1 torchaudio==2.3.1 --index-url https://download.pytorch.org/whl/cpu
RUN pip install python-multipart

# Copy the entire application code to the container
COPY . /app

# Expose port 8099 for FastAPI server
EXPOSE 8099

# Command to run FastAPI app using Uvicorn
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8099"]
