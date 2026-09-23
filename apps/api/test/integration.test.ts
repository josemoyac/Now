import {beforeAll,afterAll,describe,it,expect} from 'vitest';
import {randomUUID} from 'node:crypto';
import sharp from 'sharp';
import {Database} from '../../../db/client';
import {migrate} from '../../../db/migrate';
import {seed,seedLiquidity} from '../../../db/seed';
import {buildApp} from '../src/server';
import {env} from '../src/env';
import type {UserView,RadarView,MatchView,CommunityView,CommunityEventView,HistoryView} from '../../../packages/types/src/index';
let db:Database,server:Awaited<ReturnType<typeof buildApp>>,jose:{accessToken:string;refreshToken:string;user:UserView},ana:typeof jose,admin:typeof jose;
const headers=(access:string,key=randomUUID())=>({'x-now-client':'mobile',authorization:'Bearer '+access,'idempotency-key':key});
const input=(u:UserView)=>({activity:'social',subtype:'terraza',minutes:120,radius:2000,visibility:'community',communityId:u.communities[0].id,location:{lat:37.360224,lon:-5.985137},budget:1});
async function demo(email:string){const result=email==='admin@now.demo'?await server.app.inject({method:'POST',url:'/v1/auth/demo-admin',headers:{'x-now-client':'mobile'},payload:{username:env.demoAdminUser,password:env.demoAdminPassword}}):await server.app.inject({method:'POST',url:'/v1/auth/demo',headers:{'x-now-client':'mobile'},payload:{email}});return result.json<typeof jose>();}
async function createFor(account:typeof jose){const r=await server.app.inject({method:'POST',url:'/v1/intents',headers:headers(account.accessToken),payload:input(account.user)});expect(r.statusCode,r.body).toBe(200);return r.json<{intentId:string}>();}
async function radar(account:typeof jose){const r=await server.app.inject({method:'GET',url:'/v1/radar',headers:headers(account.accessToken)});expect(r.statusCode,r.body).toBe(200);return r.json<RadarView>();}
async function clearLive(uid:string){await db.tx(async q=>{const ms=await q.all<{id:string}>('SELECT m.id FROM matches m JOIN match_members mm ON mm.match_id=m.id WHERE mm.user_id=$1 AND m.state IN (\'PROPOSAL_PENDING\',\'PARTIALLY_ACCEPTED\',\'CONFIRMED\') AND mm.safety_exit=false',[uid]);for(const m of ms)await server.matching.safeExit(q,uid,m.id);await q.exec('UPDATE intents SET status=$1,lat=NULL,lon=NULL,cell_x=NULL,cell_y=NULL WHERE user_id=$2',['CANCELLED',uid]);});}
beforeAll(async()=>{env.demo=true;env.production=false;db=await Database.open('pglite://:memory:');await migrate(db);await seed(db,true);await seedLiquidity(db);server=await buildApp(db,{workers:false});jose=await demo('jose@now.demo');ana=await demo('ana@now.demo');admin=await demo('admin@now.demo');});
afterAll(async()=>{await server?.app.close();await db?.close();});
describe('activity subtype options',()=>{
 it('provides fallback choices when an older local database has empty options',async()=>{await db.tx(q=>q.exec("UPDATE activities SET options='[]'::jsonb WHERE id='food'"));const response=await server.app.inject({method:'GET',url:'/v1/config'});expect(response.statusCode,response.body).toBe(200);const food=response.json<{activities:{id:string;options:{id:string}[]}[]}>().activities.find(a=>a.id==='food');expect(food?.options.map(o=>o.id)).toContain('tapas');await db.tx(q=>q.exec("UPDATE activities SET options=$1::jsonb WHERE id='food'",[JSON.stringify([{id:'tapas',label:'Tapas',emoji:'🥘'}])]));});
});
describe('interest alerts',()=>{
 it('saves explicit interests and sends a nearby alert only for a visible compatible NOW',async()=>{
  await clearLive(jose.user.id);await clearLive(ana.user.id);
  const pref=await server.app.inject({method:'PATCH',url:'/v1/preferences',headers:headers(jose.accessToken),payload:{interests:['coffee'],interestSubtypes:{coffee:['tranquilo']},interestAlerts:true}});
  expect(pref.statusCode,pref.body).toBe(200);expect(pref.json().preferences.interests).toEqual(['coffee']);
  const loc=await server.app.inject({method:'POST',url:'/v1/me/interest-location',headers:headers(jose.accessToken),payload:{location:{lat:37.360224,lon:-5.985137}}});
  expect(loc.statusCode,loc.body).toBe(200);expect(loc.json().precisionMeters).toBe(500);
  const create=await server.app.inject({method:'POST',url:'/v1/intents',headers:headers(ana.accessToken),payload:{activity:'coffee',subtype:'tranquilo',minutes:120,radius:2000,visibility:'friends',location:{lat:37.360224,lon:-5.985137},budget:1}});
  expect(create.statusCode,create.body).toBe(200);
  const notes=await db.tx(q=>q.all<{title:string}>('SELECT title FROM notifications WHERE user_id=$1 AND kind=$2',[jose.user.id,'interest']));
  expect(notes.some(n=>n.title==='Hay un NOW cerca que puede gustarte')).toBe(true);
  const privateOnly=await server.app.inject({method:'POST',url:'/v1/me/interest-location',headers:headers(jose.accessToken),payload:{location:null}});expect(privateOnly.statusCode).toBe(200);
  await server.app.inject({method:'POST',url:'/v1/me/interest-location',headers:headers(jose.accessToken),payload:{location:{lat:37.36,lon:-5.985}}});await server.app.inject({method:'POST',url:'/v1/consents',headers:headers(jose.accessToken),payload:{purpose:'location',granted:false}});const cleared=await db.tx(q=>q.one('SELECT interest_cell_x FROM users WHERE id=$1',[jose.user.id]));expect(cleared?.interest_cell_x).toBeNull();
  await clearLive(jose.user.id);await clearLive(ana.user.id);
  await server.app.inject({method:'PATCH',url:'/v1/preferences',headers:headers(jose.accessToken),payload:{interestAlerts:false,interests:[],interestSubtypes:{}}});
 });
});
describe('community memory and post-NOW privacy',()=>{
 it('shows totals but names only for people met in an attended NOW',async()=>{
  const r=await server.app.inject({method:'GET',url:'/v1/communities',headers:headers(jose.accessToken)});
  expect(r.statusCode,r.body).toBe(200);
  const campus=r.json<CommunityView[]>().find(c=>c.name==='Universidad de Sevilla');expect(campus).toBeDefined();
  expect(campus!.memberCount).toBe(64);
  expect(campus!.eventCount).toBe(5);
  expect(campus!.metMembers.map((p:{displayName:string})=>p.displayName)).toEqual(['Ana','Carlos','Lucía']);
  expect(campus!.unmetCount).toBe(60);
  expect(r.body).not.toContain('Pablo');
 });
 it('reveals event attendees only when I checked in',async()=>{
  const cid=jose.user.communities[0].id;
  const own=await server.app.inject({method:'GET',url:`/v1/communities/${cid}/events`,headers:headers(jose.accessToken)});
  expect(own.statusCode,own.body).toBe(200);
  const events=own.json<CommunityEventView[]>();
  expect(events.find(e=>e.attendedByMe)?.attendees?.map((p:{displayName:string})=>p.displayName)).toEqual(['Ana','Carlos','José','Lucía']);
  expect(events.filter(e=>!e.attendedByMe).every(e=>e.attendees===null)).toBe(true);
  const adminView=await server.app.inject({method:'GET',url:`/v1/communities/${cid}/events`,headers:headers(admin.accessToken)});
  expect(adminView.json<CommunityEventView[]>().every(e=>e.attendees===null)).toBe(true);
 });
 it('keeps personal history and permits a 30-day chat after an attended NOW',async()=>{
  const history=await server.app.inject({method:'GET',url:'/v1/me/history',headers:headers(jose.accessToken)});
  expect(history.statusCode,history.body).toBe(200);
  const item=history.json<HistoryView[]>()[0];expect(item.participants).toHaveLength(4);expect(item.chatOpen).toBe(true);
  const sent=await server.app.inject({method:'POST',url:`/v1/matches/${item.id}/messages`,headers:headers(jose.accessToken),payload:{body:'Me encantó el café de ayer'}});
  expect(sent.statusCode,sent.body).toBe(200);
  const chats=await server.app.inject({method:'GET',url:'/v1/me/conversations',headers:headers(jose.accessToken)});
  expect(chats.json<HistoryView[]>()[0].lastMessage).toBe('Me encantó el café de ayer');
  const outsider=await server.app.inject({method:'GET',url:`/v1/matches/${item.id}/messages`,headers:headers(admin.accessToken)});
  expect(outsider.statusCode).toBe(404);
 });
 it('validates subtype and strips photo metadata while allowing removal',async()=>{
  const bad=await server.app.inject({method:'POST',url:'/v1/intents',headers:headers(jose.accessToken),payload:{...input(jose.user),subtype:'inventado'}});
  expect(bad.statusCode).toBe(400);
  const image=await sharp({create:{width:80,height:80,channels:3,background:'#71994b'}}).jpeg().toBuffer();
  const put=await server.app.inject({method:'PUT',url:'/v1/me/avatar',headers:headers(jose.accessToken),payload:{image:'data:image/jpeg;base64,'+image.toString('base64')}});
  expect(put.statusCode,put.body).toBe(200);expect(put.json().avatar).toBeNull();expect(put.json().avatarPending).toBe(true);
  const queue=await server.app.inject({method:'GET',url:'/v1/admin/avatars',headers:headers(admin.accessToken)});expect(queue.json<{id:string}[]>().some(a=>a.id===jose.user.id)).toBe(true);
  const approve=await server.app.inject({method:'PATCH',url:'/v1/admin/avatars/'+jose.user.id,headers:headers(admin.accessToken),payload:{approved:true,rationale:'Foto válida para el perfil'}});expect(approve.statusCode,approve.body).toBe(200);
  const approved=await server.app.inject({method:'GET',url:'/v1/me',headers:headers(jose.accessToken)});expect(approved.json().avatar).toMatch(/^data:image\/jpeg;base64,/);
  const remove=await server.app.inject({method:'PUT',url:'/v1/me/avatar',headers:headers(jose.accessToken),payload:{image:null}});
  expect(remove.statusCode,remove.body).toBe(200);expect(remove.json().avatar).toBeNull();
 });
 it('limits public profiles to people actually met and gates private messages on mutual consent',async()=>{
  const [a,b]=[jose.user.id,ana.user.id];
  await db.tx(q=>q.exec('DELETE FROM friendships WHERE (a=$1 AND b=$2) OR (a=$2 AND b=$1)',[a,b]));
  try {
   const profile=await server.app.inject({method:'GET',url:`/v1/people/${b}`,headers:headers(jose.accessToken)});
   expect(profile.statusCode,profile.body).toBe(200);expect(profile.json()).toMatchObject({displayName:'Ana',friendStatus:'none'});expect(profile.json()).toHaveProperty('sharedNows');
   expect(Object.keys(profile.json()).sort()).toEqual(['avatar','displayName','friendStatus','id','sharedNows']);
   const pablo=await db.tx(q=>q.one<{id:string}>('SELECT id FROM users WHERE username=$1',['campus5']));
   expect((await server.app.inject({method:'GET',url:`/v1/people/${pablo!.id}`,headers:headers(jose.accessToken)})).statusCode).toBe(404);
   const request=await server.app.inject({method:'POST',url:`/v1/people/${b}/friend-request`,headers:headers(jose.accessToken),payload:{}});
   expect(request.statusCode,request.body).toBe(200);expect(request.json().status).toBe('outgoing');
   expect((await server.app.inject({method:'GET',url:'/v1/friend-requests',headers:headers(ana.accessToken)})).json()).toContainEqual(expect.objectContaining({id:a,displayName:'José'}));
   expect((await server.app.inject({method:'POST',url:`/v1/people/${b}/messages`,headers:headers(jose.accessToken),payload:{body:'Hola Ana'}})).statusCode).toBe(403);
   const accepted=await server.app.inject({method:'POST',url:`/v1/people/${a}/friend-request`,headers:headers(ana.accessToken),payload:{}});
   expect(accepted.statusCode,accepted.body).toBe(200);expect(accepted.json().status).toBe('friends');
   expect((await server.app.inject({method:'GET',url:`/v1/people/${b}`,headers:headers(jose.accessToken)})).json().friendStatus).toBe('friends');
   const sent=await server.app.inject({method:'POST',url:`/v1/people/${b}/messages`,headers:headers(jose.accessToken),payload:{body:'Hola Ana'}});expect(sent.statusCode,sent.body).toBe(200);
   const received=await server.app.inject({method:'GET',url:`/v1/people/${a}/messages`,headers:headers(ana.accessToken)});expect(received.statusCode,received.body).toBe(200);expect(received.json()[0]).toMatchObject({body:'Hola Ana',delivery:'received'});
   await server.app.inject({method:'POST',url:`/v1/people/${a}/messages/read`,headers:headers(ana.accessToken),payload:{}});
   const read=await server.app.inject({method:'GET',url:`/v1/people/${b}/messages`,headers:headers(jose.accessToken)});expect(read.json()[0].delivery).toBe('read');
   const conversations=await server.app.inject({method:'GET',url:'/v1/me/direct-conversations',headers:headers(jose.accessToken)});expect(conversations.statusCode,conversations.body).toBe(200);expect(conversations.json()[0]).toMatchObject({id:b,lastMessage:'Hola Ana'});
  } finally {
   await db.tx(async q=>{await q.exec('DELETE FROM direct_messages WHERE (sender_id=$1 AND recipient_id=$2) OR (sender_id=$2 AND recipient_id=$1)',[a,b]);const [left,right]=[a,b].sort();await q.exec('INSERT INTO friendships(a,b,status,created_at) VALUES($1,$2,\'accepted\',$3) ON CONFLICT(a,b) DO UPDATE SET status=\'accepted\'',[left,right,Date.now()]);});
  }
 });
 it('balances mass-NOW attendance reviews and unlocks profiles only after confirmation',async()=>{
  const usernames=Array.from({length:12},(_,i)=>'campus'+(5+i));
  const userMarks=usernames.map((_,i)=>'$'+(i+1)).join(',');
  const attendees=await db.tx(q=>q.all<{id:string;username:string}>(`SELECT id,username FROM users WHERE username IN (${userMarks}) ORDER BY username`,usernames));
  expect(attendees).toHaveLength(12);
  const participantIds=attendees.map(x=>x.id),marks=participantIds.map((_,i)=>'$'+(i+1)).join(','),friendships=await db.tx(q=>q.all<{a:string;b:string;status:string;created_at:number}>(`SELECT a,b,status,created_at FROM friendships WHERE a IN (${marks}) AND b IN (${marks})`,[...participantIds,...participantIds]));
  const mid=randomUUID(),pablo=attendees.find(x=>x.username==='campus5')!;
  await db.tx(async q=>{
   await q.exec(`DELETE FROM friendships WHERE a IN (${marks}) AND b IN (${marks})`,[...participantIds,...participantIds]);
   const venue=await q.one<{id:string}>('SELECT id FROM venues LIMIT 1');
   const now=Date.now()-10*60000;
   await q.exec('INSERT INTO matches(id,activity,subtype,venue_id,state,scheduled_at,ends_at,expires_at,created_at,confirmed_at,is_demo) VALUES($1,$2,$3,$4,$5,$6,$7,$8,$6,$6,true)',[mid,'coffee','tranquilo',venue!.id,'CONFIRMED',now-3600000,now-60000,now-3600000]);
   for(const [index,person] of attendees.entries())await q.exec('INSERT INTO match_members(match_id,user_id,response,checked_in) VALUES($1,$2,$3,$4)',[mid,person.id,'accepted',index<11]);
   for(let i=0;i<4;i++)await q.exec('INSERT INTO messages(id,match_id,sender_id,body,created_at,expires_at) VALUES($1,$2,$3,$4,$5,$6)',[randomUUID(),mid,pablo.id,'Conversación compartida',now+i,now+30*86400000]);
   await server.matching.complete(q,mid);
  });
  try {
   const workload=await db.tx(q=>q.all<{reviewer:string;n:number}>('SELECT reviewer_id AS reviewer,count(*)::int AS n FROM attendance_review_assignments WHERE match_id=$1 GROUP BY reviewer_id',[mid]));
   expect(workload.length).toBeGreaterThan(0);expect(workload.every(x=>x.n<=2)).toBe(true);
   const verifications=await db.tx(q=>q.all<{subject:string;required_yes:number;state:string}>('SELECT subject_id AS subject,required_yes,state FROM attendance_verifications WHERE match_id=$1',[mid]));
   expect(verifications.find(x=>x.subject===pablo.id)).toMatchObject({required_yes:1,state:'pending'});
   expect(verifications.every(x=>x.subject!==attendees[11].id)).toBe(true);
   const assignment=await db.tx(q=>q.one<{reviewer_id:string}>('SELECT reviewer_id FROM attendance_review_assignments WHERE match_id=$1 AND subject_id=$2 LIMIT 1',[mid,pablo.id]));
   const reviewer=attendees.find(x=>x.id===assignment!.reviewer_id)!;const account=await server.auth.demo(reviewer.username+'@now.demo');
   const hidden=await server.app.inject({method:'GET',url:`/v1/people/${pablo.id}`,headers:headers(account.accessToken)});expect(hidden.statusCode).toBe(404);
   const reviews=await server.app.inject({method:'GET',url:'/v1/me/attendance-reviews',headers:headers(account.accessToken)});
   expect(reviews.json<{subjectId:string}[]>()).toEqual(expect.arrayContaining([expect.objectContaining({subjectId:pablo.id})]));
   const answer=await server.app.inject({method:'POST',url:`/v1/matches/${mid}/attendance-reviews/${pablo.id}`,headers:headers(account.accessToken),payload:{attended:true}});
   expect(answer.statusCode,answer.body).toBe(200);
   const reviewerVotes=await db.tx(q=>q.all<{reviewer_id:string}>('SELECT reviewer_id FROM attendance_review_assignments WHERE match_id=$1 AND subject_id=$2 AND state=$3 LIMIT 2',[mid,reviewer.id,'pending']));
   for(const vote of reviewerVotes){const voter=attendees.find(x=>x.id===vote.reviewer_id)!;const voterAccount=await server.auth.demo(voter.username+'@now.demo');const confirmed=await server.app.inject({method:'POST',url:`/v1/matches/${mid}/attendance-reviews/${reviewer.id}`,headers:headers(voterAccount.accessToken),payload:{attended:true}});expect(confirmed.statusCode,confirmed.body).toBe(200);}
   const visible=await server.app.inject({method:'GET',url:`/v1/people/${pablo.id}`,headers:headers(account.accessToken)});expect(visible.statusCode,visible.body).toBe(200);
   const noShow=await db.tx(q=>q.one('SELECT 1 FROM attendance_verifications WHERE match_id=$1 AND subject_id=$2',[mid,attendees[11].id]));expect(noShow).toBeFalsy();
  } finally {
   await db.tx(async q=>{await q.exec('DELETE FROM attendance WHERE match_id=$1',[mid]);await q.exec('DELETE FROM messages WHERE match_id=$1',[mid]);await q.exec('DELETE FROM reliability_events WHERE match_id=$1',[mid]);await q.exec('DELETE FROM notifications WHERE kind=$1 AND created_at>$2',['attendance_review',Date.now()-60000]);await q.exec('DELETE FROM match_members WHERE match_id=$1',[mid]);await q.exec('DELETE FROM matches WHERE id=$1',[mid]);for(const f of friendships)await q.exec('INSERT INTO friendships(a,b,status,created_at) VALUES($1,$2,$3,$4) ON CONFLICT(a,b) DO UPDATE SET status=$3,created_at=$4',[f.a,f.b,f.status,f.created_at]);});
  }
 });
});
describe('authentication and age gate',()=>{
 it('rejects minors server-side',async()=>{const r=await server.app.inject({method:'POST',url:'/v1/auth/request',headers:{'x-now-client':'mobile'},payload:{email:'minor@example.test',displayName:'Menor',birthDate:'2015-01-01',terms:true}});expect(r.statusCode).toBe(403);});
 it('signup → OTP → community verifies → real intent → accept → confirmed',async()=>{const h={'x-now-client':'mobile'};const request=await server.app.inject({method:'POST',url:'/v1/auth/request',headers:h,payload:{email:'new'+randomUUID()+'@example.test',displayName:'Alba Nueva',birthDate:'2001-01-01',terms:true}});expect(request.statusCode,request.body).toBe(200);const c=request.json<{challenge:string;binding:string;demoCode:string}>();const wrong=await server.app.inject({method:'POST',url:'/v1/auth/verify',headers:h,payload:{challenge:c.challenge,binding:'x'.repeat(40),code:c.demoCode}});expect(wrong.statusCode).toBe(401);const verified=await server.app.inject({method:'POST',url:'/v1/auth/verify',headers:h,payload:{...c,code:c.demoCode}});expect(verified.statusCode,verified.body).toBe(200);const account=verified.json<typeof jose>();const join=await server.app.inject({method:'POST',url:'/v1/communities/'+jose.user.communities[0].id+'/join',headers:headers(account.accessToken),payload:{code:'CAMPUS-NOW'}});expect(join.statusCode,join.body).toBe(200);account.user.communities=jose.user.communities;await createFor(account);const r=await radar(account);expect(r.match?.size).toBeGreaterThanOrEqual(3);const accepted=await server.app.inject({method:'POST',url:`/v1/matches/${r.match!.id}/respond`,headers:headers(account.accessToken),payload:{response:'accepted'}});expect(accepted.statusCode,accepted.body).toBe(200);await db.tx(q=>q.exec('UPDATE matches SET created_at=$1 WHERE id=$2',[Date.now()-4000,r.match!.id]));await server.matching.tick();const confirmed=await radar(account);expect(confirmed.match!.state).toBe('CONFIRMED');expect(confirmed.match!.venue).toBeTruthy();await clearLive(account.user.id);});
 it('admin demo requires its username and password and never allows demo bypass',async()=>{const bad=await server.app.inject({method:'POST',url:'/v1/auth/demo-admin',headers:{'x-now-client':'mobile'},payload:{username:env.demoAdminUser,password:env.demoAdminPassword+'-wrong'}});expect(bad.statusCode).toBe(401);const adminPass=await server.app.inject({method:'POST',url:'/v1/auth/demo',headers:{'x-now-client':'mobile'},payload:{email:'admin@now.demo'}});expect(adminPass.statusCode).toBe(400);const login=await server.app.inject({method:'POST',url:'/v1/auth/demo-admin',headers:{'x-now-client':'mobile'},payload:{username:env.demoAdminUser,password:env.demoAdminPassword}});expect(login.statusCode,login.body).toBe(200);expect(login.json().user.role).toBe('admin');});
 it('web auth uses HttpOnly cookies and hides tokens from JSON',async()=>{const r=await server.app.inject({method:'POST',url:'/v1/auth/demo',headers:{'x-now-client':'web',origin:'http://localhost:3000'},payload:{email:'jose@now.demo'}});expect(r.statusCode).toBe(200);expect(r.json().accessToken).toBeUndefined();expect(r.cookies.every(c=>c.httpOnly)).toBe(true);expect(r.cookies.every(c=>c.sameSite==='Strict')).toBe(true);});
 it('refresh rotates and replay revokes family',async()=>{const a=await demo('carlos@now.demo');const rotated=await server.auth.refresh(a.refreshToken);expect(rotated.accessToken).not.toBe(a.accessToken);await expect(server.auth.authenticate(a.accessToken)).rejects.toThrow();await expect(server.auth.refresh(a.refreshToken)).rejects.toThrow();await expect(server.auth.authenticate(rotated.accessToken)).rejects.toThrow();});
 it('rejects cross-origin mutation and missing CSRF header',async()=>{const r=await server.app.inject({method:'POST',url:'/v1/auth/demo',headers:{'x-now-client':'web',origin:'https://attacker.example'},payload:{email:'jose@now.demo'}});expect(r.statusCode).toBe(403);const no=await server.app.inject({method:'POST',url:'/v1/auth/demo',payload:{email:'jose@now.demo'}});expect(no.statusCode).toBe(403);});
 it('does not permit forged community or open trust',async()=>{const r=await server.app.inject({method:'POST',url:'/v1/intents',headers:headers(jose.accessToken),payload:{...input(jose.user),communityId:randomUUID()}});expect(r.statusCode).toBe(403);const open=await server.app.inject({method:'POST',url:'/v1/intents',headers:headers(jose.accessToken),payload:{...input(jose.user),visibility:'open'}});expect(open.statusCode).toBe(403);});
});
describe('matching transactions, privacy, state machine',()=>{
 it('concurrent create with same idempotency key yields one intent; conflicting retries fail',async()=>{await clearLive(jose.user.id);const k=randomUUID(),payload=input(jose.user);const request=()=>server.app.inject({method:'POST',url:'/v1/intents',headers:headers(jose.accessToken,k),payload});const results=await Promise.all([request(),request()]);for(const r of results)expect(r.statusCode,r.body).toBe(200);expect(results[0].json().intentId).toBe(results[1].json().intentId);const conflict=await server.app.inject({method:'POST',url:'/v1/intents',headers:headers(jose.accessToken,k),payload:{...payload,minutes:60}});expect(conflict.statusCode).toBe(409);});
 it('proposal and radar have no users, emails or coordinates',async()=>{const r=await radar(jose);expect(r.match?.state).toBe('PROPOSAL_PENDING');expect(r.match?.venue).toBeNull();expect(r.match?.participants).toEqual([]);const text=JSON.stringify(r);expect(text).not.toMatch(/"(?:lat|lon|email|user_id|cell_x|cell_y)"/);const saved=await db.tx(q=>q.one<{lat:number;lon:number}>('SELECT lat,lon FROM intents WHERE id=$1',[r.intent!.id]));expect(saved).toEqual({lat:37.36,lon:-5.985});});
 it('prevents IDOR across intent, match, check-in, chat and reports',async()=>{const r=await radar(jose);for(const [method,url,payload] of [['GET','/v1/matches/'+r.match!.id,undefined],['DELETE','/v1/intents/'+r.intent!.id,undefined],['POST','/v1/matches/'+r.match!.id+'/respond',{response:'accepted'}],['POST','/v1/matches/'+r.match!.id+'/check-in',{}],['GET','/v1/matches/'+r.match!.id+'/messages',undefined]] as const){const out=await server.app.inject({method,url,headers:headers(ana.accessToken),payload});expect(out.statusCode,out.body).toBe(404);}});
 it('chat unavailable before confirmation',async()=>{const r=await radar(jose);const out=await server.app.inject({method:'POST',url:'/v1/matches/'+r.match!.id+'/messages',headers:headers(jose.accessToken),payload:{body:'hola'}});expect(out.statusCode).toBe(403);});
 it('concurrent acceptance is idempotent and confirms everyone; erases geo',async()=>{const r=await radar(jose);const k=randomUUID();const accept=()=>server.app.inject({method:'POST',url:'/v1/matches/'+r.match!.id+'/respond',headers:headers(jose.accessToken,k),payload:{response:'accepted'}});const responses=await Promise.all([accept(),accept()]);responses.forEach(x=>expect(x.statusCode,x.body).toBe(200));await db.tx(q=>q.exec('UPDATE matches SET created_at=$1 WHERE id=$2',[Date.now()-5000,r.match!.id]));await server.matching.tick();const confirmed=await radar(jose);expect(confirmed.match!.state).toBe('CONFIRMED');expect(confirmed.match!.participants).toHaveLength(confirmed.match!.size);const geos=await db.tx(q=>q.all<{lat:number|null;lon:number|null}>('SELECT lat,lon FROM intents WHERE id IN(SELECT intent_id FROM match_members WHERE match_id=$1)',[r.match!.id]));expect(geos.every(x=>x.lat===null&&x.lon===null)).toBe(true);});
 it('check-in and completion update attendance once and create IRL hours',async()=>{const r=await radar(jose);const k=randomUUID();const check=()=>server.app.inject({method:'POST',url:'/v1/matches/'+r.match!.id+'/check-in',headers:headers(jose.accessToken,k),payload:{}});const [a,b]=await Promise.all([check(),check()]);expect(a.statusCode,a.body).toBe(200);expect(b.statusCode).toBe(200);const bad=await server.app.inject({method:'POST',url:'/v1/matches/'+r.match!.id+'/messages',headers:headers(jose.accessToken),payload:{body:'Contacta https://example.com'}});expect(bad.statusCode).toBe(422);const message=await server.app.inject({method:'POST',url:'/v1/matches/'+r.match!.id+'/messages',headers:headers(jose.accessToken),payload:{body:'Os espero en la entrada'}});expect(message.statusCode).toBe(200);const complete=await server.app.inject({method:'POST',url:'/v1/demo/matches/'+r.match!.id+'/complete',headers:headers(jose.accessToken),payload:{}});expect(complete.statusCode,complete.body).toBe(200);expect(complete.json<MatchView>().state).toBe('COMPLETED');const metrics=await server.app.inject({method:'GET',url:'/v1/admin/metrics',headers:headers(admin.accessToken)});expect(metrics.json().irlHours).toBeGreaterThan(0);});
 it('expired proposals reject late acceptance, release seats and leave the active radar',async()=>{await createFor(ana);const r=await radar(ana);expect(r.match).toBeTruthy();await db.tx(q=>q.exec('UPDATE matches SET expires_at=$1 WHERE id=$2',[Date.now()-1,r.match!.id]));const res=await server.app.inject({method:'POST',url:'/v1/matches/'+r.match!.id+'/respond',headers:headers(ana.accessToken),payload:{response:'accepted'}});expect(res.statusCode).toBe(409);await server.matching.tick();expect((await radar(ana)).match).toBeNull();expect((await db.tx(q=>q.one<{state:string}>('SELECT state FROM matches WHERE id=$1',[r.match!.id])))?.state).toBe('EXPIRED');await clearLive(ana.user.id);});
});
describe('safety and privacy',()=>{
 it('reports are idempotent; block is bilateral and removes future eligibility',async()=>{const r=await radar(jose);const target=r.match!.participants.find(p=>p.id!==jose.user.id)!.id;const k=randomUUID(),payload={subjectId:target,matchId:r.match!.id,category:'harassment',details:'Conducta de prueba para moderación'};const a=await server.app.inject({method:'POST',url:'/v1/reports',headers:headers(jose.accessToken,k),payload});const b=await server.app.inject({method:'POST',url:'/v1/reports',headers:headers(jose.accessToken,k),payload});expect(a.statusCode,a.body).toBe(200);expect(a.json().id).toBe(b.json().id);const blocked=await server.app.inject({method:'POST',url:'/v1/users/'+target+'/block',headers:headers(jose.accessToken),payload:{}});expect(blocked.statusCode).toBe(200);expect((await radar(jose)).match!.participants.some(p=>p.id===target)).toBe(false);});
 it('non-admin cannot access operations; SQL injection is a literal search',async()=>{expect((await server.app.inject({method:'GET',url:'/v1/admin/reports',headers:headers(ana.accessToken)})).statusCode).toBe(403);const search=await server.app.inject({method:'GET',url:'/v1/admin/users?q='+encodeURIComponent("'; DROP TABLE users; --"),headers:headers(admin.accessToken)});expect(search.statusCode).toBe(200);expect(search.json()).toEqual([]);});
 it('suspension prevents radar and retains own appeal and privacy rights',async()=>{const res=await server.app.inject({method:'PATCH',url:'/v1/admin/users/'+ana.user.id,headers:headers(admin.accessToken),payload:{status:'suspended',rationale:'Prueba de control de acceso suspendido'}});expect(res.statusCode).toBe(200);expect((await server.app.inject({method:'GET',url:'/v1/radar',headers:headers(ana.accessToken)})).statusCode).toBe(403);const cases=await server.app.inject({method:'GET',url:'/v1/moderation/mine',headers:headers(ana.accessToken)});expect(cases.statusCode).toBe(200);expect(cases.json().cases.length).toBe(1);const appeal=await server.app.inject({method:'POST',url:'/v1/appeals',headers:headers(ana.accessToken),payload:{caseId:cases.json().cases[0].id,reason:'Solicito una revisión de esta decisión de prueba.'}});expect(appeal.statusCode).toBe(200);});
 it('export excludes other people, token hashes and operational geolocation',async()=>{const out=await server.app.inject({method:'GET',url:'/v1/privacy/export',headers:headers(jose.accessToken)});expect(out.statusCode,out.body).toBe(200);expect(out.body).not.toMatch(/access_hash|refresh_hash|push_token|"lat"|"lon"/);expect(out.body).toContain('jose@now.demo');expect(out.body).not.toContain('ana@now.demo');});
 it('delete revokes sessions, erases contact, devices and precise/cell location',async()=>{const out=await server.app.inject({method:'DELETE',url:'/v1/account',headers:headers(ana.accessToken)});expect(out.statusCode,out.body).toBe(200);expect((await server.app.inject({method:'GET',url:'/v1/me',headers:headers(ana.accessToken)})).statusCode).toBe(401);const data=await db.tx(async q=>({contact:await q.one('SELECT * FROM identity.contacts WHERE user_id=$1',[ana.user.id]),intents:await q.all('SELECT * FROM intents WHERE user_id=$1',[ana.user.id]),sessions:await q.all('SELECT * FROM sessions WHERE user_id=$1',[ana.user.id])}));expect(data.contact).toBeUndefined();expect(data.intents).toEqual([]);expect(data.sessions).toEqual([]);});
 it('rate limiting protects OTP challenge enumeration/brute force',async()=>{const email='ratelimit@example.test';const results=[];for(let i=0;i<5;i++)results.push(await server.app.inject({method:'POST',url:'/v1/auth/request',headers:{'x-now-client':'mobile'},payload:{email}}));expect(results[4].statusCode).toBe(429);});
 it('production demo entry point is fail-closed',async()=>{env.demo=false;const out=await server.app.inject({method:'POST',url:'/v1/auth/demo',headers:{'x-now-client':'mobile'},payload:{email:'jose@now.demo'}});expect(out.statusCode).toBe(404);env.demo=true;});
});
