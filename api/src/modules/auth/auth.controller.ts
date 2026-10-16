import type { Request, Response } from 'express';
import type { AuthService, ClientContext } from './auth.service.js';
import type { LoginInput, LogoutInput, RefreshInput, RegisterInput } from './auth.schemas.js';

type BodyRequest<T> = Request<Record<string, string>, unknown, T>;

const clientContext = (req: BodyRequest<unknown>): ClientContext => ({
  userAgent: req.get('user-agent'),
});

/** HTTP in, HTTP out. Bodies are already validated by `validateBody`. */
export class AuthController {
  constructor(private readonly auth: AuthService) {}

  register = async (req: BodyRequest<RegisterInput>, res: Response) => {
    res.status(201).json(await this.auth.register(req.body, clientContext(req)));
  };

  login = async (req: BodyRequest<LoginInput>, res: Response) => {
    res.json(await this.auth.login(req.body, clientContext(req)));
  };

  refresh = async (req: BodyRequest<RefreshInput>, res: Response) => {
    res.json({ tokens: await this.auth.refresh(req.body.refreshToken, clientContext(req)) });
  };

  logout = async (req: BodyRequest<LogoutInput>, res: Response) => {
    await this.auth.logout(req.body.refreshToken);
    res.status(204).end();
  };
}
