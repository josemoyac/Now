import 'dotenv/config';
import { PGlite } from '@electric-sql/pglite';
import pg from 'pg';
import { drizzle as embeddedDrizzle } from 'drizzle-orm/pglite';
import { drizzle as postgresDrizzle } from 'drizzle-orm/node-postgres';
import { sql, type SQL } from 'drizzle-orm';
import { resolve } from 'node:path';
import { mkdir } from 'node:fs/promises';
export interface Query {all<T extends object=Record<string,unknown>>(text:string,params?:unknown[]):Promise<T[]>;one<T extends object=Record<string,unknown>>(text:string,params?:unknown[]):Promise<T|undefined>;exec(text:string,params?:unknown[]):Promise<void>}
interface Executor{execute(q:SQL):Promise<{rows:unknown[]}>}
function parameterize(text:string,params:unknown[]=[]){const parts=text.split(/\$(\d+)/g);return sql.join(parts.map((s,i)=>i%2?sql`${params[Number(s)-1]}`:sql.raw(s)),sql.raw(''));}
function query(executor:Executor):Query{
 const all=async <T extends object=Record<string,unknown>>(text:string,params:unknown[]=[]):Promise<T[]>=>{const r=await executor.execute(parameterize(text,params));return r.rows as T[];};
 return {all,async one<T extends object=Record<string,unknown>>(text:string,params:unknown[]=[]):Promise<T|undefined>{return (await all<T>(text,params))[0];},async exec(text:string,params:unknown[]=[]){await executor.execute(parameterize(text,params));}};
}
export class Database {
 private tail:Promise<unknown>=Promise.resolve();
 private constructor(private pglite:PGlite|null,private pool:pg.Pool|null){}
 static async open(url=process.env.DATABASE_URL||'pglite://.local/postgres'){if(url.startsWith('pglite://')){const name=url.slice(9);if(name&&name!==':memory:')await mkdir(resolve(name),{recursive:true});const p=new PGlite(name===':memory:'?undefined:resolve(name));await p.waitReady;return new Database(p,null);}const pool=new pg.Pool({connectionString:url,max:10});await pool.query('SELECT 1');return new Database(null,pool);}
 /** Single embedded connection is serialized. PostgreSQL uses a transaction-scoped application lock.
  * Deliberately conservative: safe for several API workers; shard by community before high scale. */
 async tx<T>(fn:(q:Query)=>Promise<T>):Promise<T>{const work=this.tail.then(async()=>{if(this.pglite){return embeddedDrizzle(this.pglite).transaction(async tx=>fn(query(tx as unknown as Executor)));}const c=await this.pool!.connect();try{await c.query('BEGIN');await c.query('SELECT pg_advisory_xact_lock(7800291)');const result=await fn(query(postgresDrizzle(c) as unknown as Executor));await c.query('COMMIT');return result;}catch(e){await c.query('ROLLBACK');throw e;}finally{c.release();}});this.tail=work.catch(()=>{});return work;}
 async migrate(source:string){if(this.pglite)await this.pglite.exec(source);else await this.pool!.query(source);}
 async close(){await this.tail;if(this.pglite)await this.pglite.close();if(this.pool)await this.pool.end();}
}
