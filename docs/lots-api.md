# ParkSpot: Lots and nearby search (Milestone 2)

Status: implemented in `api/src/modules/lots`. Backs the Map home and the lot detail sheet.

## Flow

```
Map home opens (location permission granted)
  └─ GET /v1/lots/nearby?lat&lng[&radius][&limit] → markers (cluster client-side)
       └─ tap marker → bottom sheet uses the same item; GET /v1/lots/:id refreshes it
Camera idle after a pan → re-query with the new map centre (debounce ~400 ms on the client)
```

## Endpoints

Both are public: browsing needs no account and returns nothing user-specific.

| Method & path | Query / params | Success | Errors |
|---|---|---|---|
| `GET /v1/lots/nearby` | `lat` (-90..90), `lng` (-180..180), `radius` metres (default 2000, max 10000), `limit` (default 50, max 100) | `200 { lots: Lot[] }`, nearest first | `422 VALIDATION_ERROR` |
| `GET /v1/lots/:id` | | `200 { lot: Lot }` | `404 NOT_FOUND` (also for malformed ids) |

```json
{
  "id": "6712…",
  "name": "FC Road Multilevel Parking",
  "address": "Fergusson College Rd, Shivajinagar",
  "location": { "lat": 18.5246, "lng": 73.8411 },
  "pricePerHour": { "amount": 4000, "currency": "INR" },
  "totalSlots": 120,
  "freeSlots": 37,
  "photos": [],
  "distanceMeters": 412
}
```

- `pricePerHour.amount` is in **paise** (4000 = ₹40.00). Format on the client; never do money maths in doubles.
- `distanceMeters` is an integer, present only on `/nearby`.
- `freeSlots` is a live count of `FREE` slots, computed per request (no cached counter that can drift).

## Data model

- `Lot { name, address, location: GeoJSON Point [lng, lat] (2dsphere), pricePerHourPaise, totalSlots, photos[], ownerId? }`
- `Slot { lotId, label (unique per lot), status: FREE | LOCKED | BOOKED }`, indexed on `{ lotId, status }`

Nearby uses one aggregation: `$geoNear` (index-backed, sorted by distance, capped by `maxDistance`) → `$limit` → `$lookup` counting FREE slots.

## Seed

`npm run seed` resets lots and slots to 20 fictional, area-named lots across Pune (FC Road, Koregaon Park, Viman Nagar, Hinjewadi, …) with deterministic occupancy between 30% and 95%. It refuses to run with `NODE_ENV=production`.

## Stretch

Live slot counts over WebSocket, filters (price, EV charging, covered), lot photos upload, owner CRUD.
