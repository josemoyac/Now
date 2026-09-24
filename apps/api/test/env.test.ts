import {afterEach,describe,expect,it} from 'vitest';
import {env,validateEnv} from '../src/env';

const keys=['AUTH_SECRET','DATABASE_URL','REDIS_URL','SMTP_URL','APP_ORIGINS','PUBLIC_WEB_URL','SUPPORT_EMAIL','PRIVACY_EMAIL'] as const;
const original=Object.fromEntries(keys.map(key=>[key,process.env[key]]));
const prior={production:env.production,demo:env.demo};
function setValidProduction(){Object.assign(env,{production:true,demo:false});Object.assign(process.env,{AUTH_SECRET:'x'.repeat(40),DATABASE_URL:'postgres://user:pass@db.example.com/now',REDIS_URL:'redis://cache.example.com',SMTP_URL:'smtps://mail.example.com',APP_ORIGINS:'https://now.example.com,https://admin.example.com',PUBLIC_WEB_URL:'https://now.example.com',SUPPORT_EMAIL:'support@now.example.com',PRIVACY_EMAIL:'privacy@now.example.com'});}
afterEach(()=>{for(const key of keys){const value=original[key];if(value===undefined)delete process.env[key];else process.env[key]=value;}Object.assign(env,prior);});

describe('production environment validation',()=>{
 it('accepts complete HTTPS public origins and privacy contacts',()=>{setValidProduction();expect(()=>validateEnv()).not.toThrow();});
 it('rejects insecure or local public origins and missing privacy contacts',()=>{setValidProduction();process.env.APP_ORIGINS='https://now.example.com,http://admin.example.com';expect(()=>validateEnv()).toThrow(/HTTPS public URL\/origins/);setValidProduction();process.env.PUBLIC_WEB_URL='http://localhost:3000';expect(()=>validateEnv()).toThrow();setValidProduction();process.env.APP_ORIGINS='https://[::1]';expect(()=>validateEnv()).toThrow();setValidProduction();delete process.env.PRIVACY_EMAIL;expect(()=>validateEnv()).toThrow();});
});
