import {createHmac,randomBytes,randomUUID,timingSafeEqual} from 'node:crypto';
import {env} from './env';
export const id=()=>randomUUID();
export const token=()=>randomBytes(32).toString('base64url');
export const hash=(value:string)=>createHmac('sha256',env.secret).update(value).digest('hex');
export const digestEqual=(a:string,b:string)=>a.length===b.length&&timingSafeEqual(Buffer.from(a),Buffer.from(b));
