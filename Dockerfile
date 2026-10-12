# syntax=docker/dockerfile:1

# Node.js LTS version for stability and compatibility with Next.js 16 on AWS Linux
ARG NODE_VERSION=22-alpine

################################################################################
# Stage 1: Base image
FROM node:${NODE_VERSION} AS base

# Install libc6-compat for Alpine compatibility with Next.js binaries
RUN apk add --no-cache libc6-compat
WORKDIR /app

################################################################################
# Stage 2: Install dependencies
FROM base AS deps
WORKDIR /app

# Copy dependency definition files
COPY package.json package-lock.json ./

# Install dependencies cleanly using package-lock.json
RUN npm ci

################################################################################
# Stage 3: Build the application
FROM base AS builder
WORKDIR /app

# Copy installed node_modules from deps stage
COPY --from=deps /app/node_modules ./node_modules

# Copy the rest of the application source
COPY . .

# Disable telemetry and set production environment for build
ENV NEXT_TELEMETRY_DISABLED=1
ENV NODE_ENV=production

# Next.js build-time public arguments (default values allow docker build to succeed without failing on Clerk/Convex)
ARG NEXT_PUBLIC_CONVEX_URL="https://amicable-oyster-647.convex.cloud"
ARG NEXT_PUBLIC_CLERK_PUBLISHABLE_KEY="pk_test_c3RyaWtpbmctcGhlYXNhbnQtMzguY2xlcmsuYWNjb3VudHMuZGV2JA"
ARG NEXT_PUBLIC_CLERK_SIGN_IN_URL="/sign-in"
ARG NEXT_PUBLIC_CLERK_SIGN_UP_URL="/sign-up"
ARG NEXT_PUBLIC_UNSPLASH_ACCESS_KEY=""

ENV NEXT_PUBLIC_CONVEX_URL=$NEXT_PUBLIC_CONVEX_URL
ENV NEXT_PUBLIC_CLERK_PUBLISHABLE_KEY=$NEXT_PUBLIC_CLERK_PUBLISHABLE_KEY
ENV NEXT_PUBLIC_CLERK_SIGN_IN_URL=$NEXT_PUBLIC_CLERK_SIGN_IN_URL
ENV NEXT_PUBLIC_CLERK_SIGN_UP_URL=$NEXT_PUBLIC_CLERK_SIGN_UP_URL
ENV NEXT_PUBLIC_UNSPLASH_ACCESS_KEY=$NEXT_PUBLIC_UNSPLASH_ACCESS_KEY

# Build Next.js application in standalone mode
RUN npm run build

################################################################################
# Stage 4: Production runner (minimal, lightweight, non-root)
FROM base AS runner
WORKDIR /app

ENV NODE_ENV=production
ENV NEXT_TELEMETRY_DISABLED=1
ENV PORT=3000
ENV HOSTNAME="0.0.0.0"

# Prepare cache directory and permissions for node user
RUN mkdir -p .next/cache && chown -R node:node /app

# Copy static assets and Next.js standalone bundle
COPY --from=builder --chown=node:node /app/public ./public
COPY --from=builder --chown=node:node /app/.next/standalone ./
COPY --from=builder --chown=node:node /app/.next/static ./.next/static

# Run container as non-root user
USER node

# Expose internal listening port
EXPOSE 3000

# Start standalone Next.js server
CMD ["node", "server.js"]
