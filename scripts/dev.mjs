import 'dotenv/config';
import {spawn} from 'node:child_process';
import {resolve} from 'node:path';
const root=process.cwd();
const children=[];
const env={...process.env,NEXT_TELEMETRY_DISABLED:'1',EXPO_NO_TELEMETRY:'1'};
if(process.argv.includes('--demo')){env.DEMO_MODE='true';env.DATABASE_URL=env.DATABASE_URL||'pglite://.local/postgres';}
async function run(file,args){return new Promise((ok,bad)=>{const p=spawn(process.execPath,[file,...args],{cwd:root,env,stdio:'inherit'});p.on('exit',code=>code===0?ok():bad(new Error(file+' failed: '+code)));});}
await run(resolve('node_modules/tsx/dist/cli.mjs'),['db/migrate.ts']);await run(resolve('node_modules/tsx/dist/cli.mjs'),['db/seed.ts']);
function start(file,args){const p=spawn(process.execPath,[file,...args],{cwd:root,env,stdio:'inherit'});children.push(p);p.on('error',e=>console.error(e.message));p.on('exit',code=>{if(code&&code!==0)console.error('Service exited:',code);});}
start(resolve('node_modules/tsx/dist/cli.mjs'),['apps/api/src/main.ts']);
start(resolve('node_modules/next/dist/bin/next'),['dev','apps/web','-p','3000']);
start(resolve('node_modules/next/dist/bin/next'),['dev','apps/admin','-p','3002']);
console.log('\nNOW web: http://localhost:3000\nAdmin: http://localhost:3002\nAPI: http://localhost:4000\nOpenAPI: http://localhost:4000/api/docs\nMóvil: npm run dev:mobile\n');
function stop(){for(const p of children)p.kill('SIGTERM');}
process.on('SIGINT',stop);process.on('SIGTERM',stop);
