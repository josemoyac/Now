import { Database } from '../../../db/client';
import { buildApp } from './server';
import { env } from './env';
const db=await Database.open();const {app}=await buildApp(db,{logger:true});await app.listen({host:env.host,port:env.port});
const stop=async()=>{await app.close();await db.close();process.exit(0);};process.on('SIGINT',()=>void stop());process.on('SIGTERM',()=>void stop());
