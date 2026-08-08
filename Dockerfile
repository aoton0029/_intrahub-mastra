# `mastra build` は .mastra/output/ に自己完結したサーバーバンドル
# （index.mjs + package.json + node_modules）を生成する。.mastra は .gitignore 対象なので
# イメージ内でビルドし、成果物だけを runtime 段へ渡す。
FROM node:22-slim AS builder
WORKDIR /app

COPY package.json package-lock.json ./
RUN npm ci

COPY . .
RUN npm run build

FROM node:22-slim AS runtime
WORKDIR /app

ENV NODE_ENV=production
ENV PORT=4111

COPY --from=builder --chown=node:node /app/.mastra/output ./

# LibSQL とオブザーバビリティの書き込み先。compose 側でボリュームをマウントする。
RUN mkdir -p /app/data && chown node:node /app/data

USER node
EXPOSE 4111

CMD ["node", "./index.mjs"]
