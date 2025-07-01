FROM node:16-slim

WORKDIR /app

# Copy package files and install dependencies
COPY package*.json ./
RUN npm install --production

# Copy application files
COPY . .

# Expose port that the app runs on
EXPOSE 5000

# Command to run the app
CMD ["node", "index.js"]
