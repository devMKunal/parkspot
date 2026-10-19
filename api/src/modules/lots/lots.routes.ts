import { Router } from 'express';
import { Errors } from '../../core/errors/AppError.js';
import { parseOrThrow } from '../../core/http/validate.js';
import type { LotRepository } from './lot.repository.js';
import { toLotDto } from './lot.types.js';
import { NearbyQuery } from './lots.schemas.js';

/**
 * Read-only lot discovery. Public on purpose: browsing the map needs no account,
 * and nothing here is user-specific.
 */
export function lotsRouter(deps: { lots: LotRepository }): Router {
  const router = Router();

  router.get('/nearby', async (req, res) => {
    const query = parseOrThrow(NearbyQuery, req.query);
    const lots = await deps.lots.findNearby({
      center: { lat: query.lat, lng: query.lng },
      radiusMeters: query.radius,
      limit: query.limit,
    });
    res.json({ lots: lots.map(toLotDto) });
  });

  router.get('/:id', async (req, res) => {
    const lot = await deps.lots.findById(req.params.id);
    if (!lot) throw Errors.notFound('Lot');
    res.json({ lot: toLotDto(lot) });
  });

  return router;
}
