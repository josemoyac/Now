import { Redis } from 'ioredis';
import type { Database } from '../../../db/client';
import type { Preferences } from '../../../packages/types/src/index';
import { MatchingService } from './matching';
import { SafetyService } from './safety';
import { push } from './providers';
import { id } from './crypto';
export class Jobs {
 redis:Redis|null=null;private running=false;private timer:ReturnType<typeof setInterval>|undefined;private turns=0;
 constructor(private db:Database,private matching:MatchingService,private safety:SafetyService,private changed:()=>void){}
 async start(){if(process.env.REDIS_URL){this.redis=new Redis(process.env.REDIS_URL,{maxRetriesPerRequest:1});this.redis.on('error',()=>console.error(JSON.stringify({event:'redis.unavailable'})));await this.redis.ping();}this.timer=setInterval(()=>{void this.tick().catch(()=>console.error(JSON.stringify({event:'worker.failed'})));},2000);this.timer.unref();}
 async tick(){if(this.running)return;this.running=true;const lock=id();try{if(this.redis&&!await this.redis.set('now:worker:lock',lock,'PX',30000,'NX'))return;await this.matching.tick();this.changed();if(++this.turns%15===0)await this.safety.retention();const notifications=await this.db.tx(q=>q.all<{id:string;user_id:string;title:string;body:string;kind:string;data:Preferences}>('SELECT n.*,p.data FROM notifications n JOIN preferences p ON p.user_id=n.user_id WHERE delivered_at IS NULL AND attempts<3 AND expires_at>$1 ORDER BY created_at LIMIT 20',[Date.now()]));for(const n of notifications){const hour=Number(new Intl.DateTimeFormat('en',{timeZone:n.data.timezone||'Europe/Madrid',hour:'numeric',hourCycle:'h23'}).format(Date.now()));const {quietStart:a,quietEnd:b}=n.data;const quiet=a===b?false:a>b?hour>=a||hour<b:hour>=a&&hour<b;if(quiet&&n.kind!=='safety')continue;const devices=await this.db.tx(q=>q.all<{push_token:string}>('SELECT push_token FROM devices WHERE user_id=$1',[n.user_id]));try{for(const d of devices)await push.send(d.push_token,n.title,n.body);await this.db.tx(q=>q.exec('UPDATE notifications SET delivered_at=$1 WHERE id=$2',[Date.now(),n.id]));}catch{await this.db.tx(q=>q.exec('UPDATE notifications SET attempts=attempts+1 WHERE id=$1',[n.id]));}}}finally{if(this.redis)await this.redis.eval('if redis.call("get",KEYS[1]) == ARGV[1] then return redis.call("del",KEYS[1]) else return 0 end',1,'now:worker:lock',lock);this.running=false;}}
 async close(){if(this.timer)clearInterval(this.timer);while(this.running)await new Promise(r=>setTimeout(r,20));await this.redis?.quit();}
}
