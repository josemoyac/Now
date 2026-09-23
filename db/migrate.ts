import { readFile,readdir } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';
import { Database } from './client';
export async function migrate(db:Database){await db.migrate('CREATE TABLE IF NOT EXISTS schema_migrations (name text PRIMARY KEY, applied_at bigint NOT NULL)');const dir=fileURLToPath(new URL('./migrations/',import.meta.url));for(const name of (await readdir(dir)).filter(n=>n.endsWith('.sql')).sort()){const exists=await db.tx(q=>q.one('SELECT name FROM schema_migrations WHERE name=$1',[name]));if(!exists){const source=await readFile(dir+name,'utf8');await db.migrate('BEGIN;\n'+source+`\nINSERT INTO schema_migrations VALUES ('${name.replaceAll("'","''")}',${Date.now()});\nCOMMIT;`);console.log(JSON.stringify({event:'migration.applied',name}));}}}
if(process.argv[1]?.endsWith('migrate.ts')){const db=await Database.open();await migrate(db);await db.close();}
