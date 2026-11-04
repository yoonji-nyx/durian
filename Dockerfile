FROM node:20-alpine
WORKDIR /app
COPY app/package.json ./
COPY app/index.js ./
USER node
EXPOSE 3000
CMD ["node", "index.js"]
