import mongoose, { Types, type PipelineStage } from 'mongoose';
import { LotModel, SlotModel } from './lot.model.js';
import type { GeoPoint, LotRecord, NearbyLotRecord } from './lot.types.js';

export interface NearbyQuery {
  center: GeoPoint;
  radiusMeters: number;
  limit: number;
}

export interface LotRepository {
  /** Lots within the radius, nearest first, with their current free-slot count. */
  findNearby(query: NearbyQuery): Promise<NearbyLotRecord[]>;
  findById(id: string): Promise<LotRecord | null>;
}

interface LotAggregateRow {
  _id: Types.ObjectId;
  name: string;
  address: string;
  location: { coordinates: [number, number] };
  pricePerHourPaise: number;
  totalSlots: number;
  photos: string[];
  freeSlots: number;
  distanceMeters?: number;
}

/** Joins the count of FREE slots onto each lot in the same round-trip. */
const freeSlotsStages: PipelineStage[] = [
  {
    $lookup: {
      from: SlotModel.collection.name,
      let: { lotId: '$_id' },
      pipeline: [
        { $match: { $expr: { $eq: ['$lotId', '$$lotId'] }, status: 'FREE' } },
        { $count: 'n' },
      ],
      as: 'free',
    },
  },
  { $set: { freeSlots: { $ifNull: [{ $first: '$free.n' }, 0] } } },
  { $unset: 'free' },
];

const toRecord = (row: LotAggregateRow): LotRecord => ({
  id: row._id.toString(),
  name: row.name,
  address: row.address,
  location: { lng: row.location.coordinates[0], lat: row.location.coordinates[1] },
  pricePerHourPaise: row.pricePerHourPaise,
  totalSlots: row.totalSlots,
  freeSlots: row.freeSlots,
  photos: row.photos,
});

export class MongoLotRepository implements LotRepository {
  async findNearby({ center, radiusMeters, limit }: NearbyQuery): Promise<NearbyLotRecord[]> {
    const rows = await LotModel.aggregate<LotAggregateRow>([
      {
        // $geoNear must be the first stage; it uses the 2dsphere index and sorts by distance.
        $geoNear: {
          near: { type: 'Point', coordinates: [center.lng, center.lat] },
          distanceField: 'distanceMeters',
          maxDistance: radiusMeters,
          spherical: true,
        },
      },
      { $limit: limit },
      ...freeSlotsStages,
    ]);
    return rows.map((row) => ({ ...toRecord(row), distanceMeters: row.distanceMeters ?? 0 }));
  }

  async findById(id: string): Promise<LotRecord | null> {
    if (!mongoose.isValidObjectId(id)) return null;
    const [row] = await LotModel.aggregate<LotAggregateRow>([
      { $match: { _id: new Types.ObjectId(id) } },
      ...freeSlotsStages,
    ]);
    return row ? toRecord(row) : null;
  }
}
