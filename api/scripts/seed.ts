/**
 * Resets lots and slots to the 20 Pune demo lots. Run: `npm run seed`.
 * Occupancy is pseudo-random but deterministic, so every run produces the same map.
 */
import { loadEnv } from '../src/config/env.js';
import { connectMongo, disconnectMongo } from '../src/infra/db/mongo.js';
import { LotModel, SlotModel } from '../src/modules/lots/lot.model.js';
import { PUNE_LOTS } from '../src/modules/lots/seed/puneLots.js';

/** Tiny deterministic PRNG (mulberry32) so the demo map looks the same every time. */
function mulberry32(seed: number): () => number {
  let a = seed;
  return () => {
    a = (a + 0x6d2b79f5) | 0;
    let t = Math.imul(a ^ (a >>> 15), 1 | a);
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

async function seed(): Promise<void> {
  const env = loadEnv();
  if (env.NODE_ENV === 'production') throw new Error('Refusing to seed a production database');

  await connectMongo(env.MONGO_URI);
  const random = mulberry32(42);

  await Promise.all([LotModel.deleteMany({}), SlotModel.deleteMany({})]);
  await Promise.all([LotModel.syncIndexes(), SlotModel.syncIndexes()]);

  for (const lot of PUNE_LOTS) {
    const created = await LotModel.create({
      name: lot.name,
      address: lot.address,
      location: { type: 'Point', coordinates: [lot.lng, lot.lat] },
      pricePerHourPaise: lot.pricePerHourPaise,
      totalSlots: lot.totalSlots,
    });

    // Each lot gets its own occupancy level between 30% and 95%, so some lots look nearly full.
    const occupancy = 0.3 + random() * 0.65;
    await SlotModel.insertMany(
      Array.from({ length: lot.totalSlots }, (_, i) => ({
        lotId: created._id,
        label: `S${String(i + 1).padStart(3, '0')}`,
        status: random() < occupancy ? 'BOOKED' : 'FREE',
      })),
    );
  }

  console.log(`Seeded ${PUNE_LOTS.length} lots`);
}

seed()
  .catch((err: unknown) => {
    console.error(err);
    process.exitCode = 1;
  })
  .finally(() => disconnectMongo());
