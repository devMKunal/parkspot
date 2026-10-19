# ParkSpot API

Express + TypeScript + MongoDB. Contract and design: [docs/auth-api.md](../docs/auth-api.md).

## Run locally

```bash
cp .env.example .env          # then set JWT_ACCESS_SECRET
docker compose up -d          # MongoDB 7 on :27017
npm install
npm run dev                   # http://localhost:3000/health
```

## Scripts

| Script                                        | Does                                          |
| --------------------------------------------- | --------------------------------------------- |
| `npm run dev`                                 | Watch mode with tsx                           |
| `npm test`                                    | Unit + HTTP tests (in-memory fakes, no DB)    |
| `npm run test:int`                            | Repository tests against an in-memory MongoDB |
| `npm run typecheck` / `lint` / `format:check` | Static checks, same as CI                     |
| `npm run seed`                                | Reset the DB to 20 demo lots in Pune          |
| `npm run build && npm start`                  | Compiled production run                       |

## Layout

`src/core` holds cross-cutting HTTP concerns (errors, validation, auth middleware). `src/modules/<feature>` holds routes → controller → service → repository. `src/server.ts` is the only file that wires concrete implementations; `createApp(deps)` takes interfaces so tests inject fakes.
