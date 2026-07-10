# syntax=docker/dockerfile:1

# Minimal base image; the app is dependency-free so no install stage is
# needed - only the runtime files are copied in.
FROM node:22-alpine

ENV NODE_ENV=production
WORKDIR /app

COPY package.json server.js ./

# Run as the unprivileged user that ships with the official Node image
USER node

EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=3s --retries=3 \
  CMD wget -qO- http://127.0.0.1:8080/health || exit 1

CMD ["node", "server.js"]
