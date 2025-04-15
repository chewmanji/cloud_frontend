FROM node:22-alpine AS base
WORKDIR /app
COPY package.json package-lock.json ./

#All deps stage
FROM base AS dev-deps
RUN npm ci

#Prod deps only stage
FROM base AS prod-deps
RUN npm ci --omit=dev

#Build stage
FROM dev-deps AS build
COPY . .
RUN npm run build

#Prod stage
FROM prod-deps
ENV PUBLIC_API_BASE_URL="http://localhost:8081/"
ENV HOST="0.0.0.0"
ENV PORT="5173"
COPY --from=build /app/build ./build

CMD ["node", "build"]
