export interface GeoPoint {
  lat: number;
  lng: number;
}

/** A lot plus its live availability, as the repository returns it. */
export interface LotRecord {
  id: string;
  name: string;
  address: string;
  location: GeoPoint;
  pricePerHourPaise: number;
  totalSlots: number;
  freeSlots: number;
  photos: string[];
}

export interface NearbyLotRecord extends LotRecord {
  distanceMeters: number;
}

export interface Money {
  /** Minor units: paise for INR. 4000 = ₹40.00 */
  amount: number;
  currency: 'INR';
}

export interface LotDto {
  id: string;
  name: string;
  address: string;
  location: GeoPoint;
  pricePerHour: Money;
  totalSlots: number;
  freeSlots: number;
  photos: string[];
  distanceMeters?: number;
}

export const toLotDto = (lot: LotRecord | NearbyLotRecord): LotDto => ({
  id: lot.id,
  name: lot.name,
  address: lot.address,
  location: lot.location,
  pricePerHour: { amount: lot.pricePerHourPaise, currency: 'INR' },
  totalSlots: lot.totalSlots,
  freeSlots: lot.freeSlots,
  photos: lot.photos,
  ...('distanceMeters' in lot ? { distanceMeters: Math.round(lot.distanceMeters) } : {}),
});
