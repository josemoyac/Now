import {describe,it,expect} from 'vitest';
import fc from 'fast-check';
import {distance,quantize,isAdult,eligible,formGroup,score,socialLevel,pair,selectVenues,nextProposalState,reliability,radarBand,textAllowed,type Candidate,type Graph,type Venue} from './index';
import type {Activity} from '../../types/src/index';
const now=Date.now();
const a:Candidate={id:'intent-a',userId:'a',activity:'coffee',start:now,end:now+7200000,expires:now+7200000,radius:2000,visibility:'community',communityId:'campus',location:{lat:37.36,lon:-5.985},status:'SEARCHING',accountStatus:'active',over18:true,trust:'community',communities:['campus'],reliability:90,budget:1,accessible:false,country:'ES'};
const b={...a,id:'intent-b',userId:'b'};
const activities:Activity[]=[{id:'coffee',label:'Café',emoji:'☕',family:'social',compatible:['coffee','social','surprise'],options:[],enabled:true,minMinutes:20},{id:'social',label:'Social',emoji:'🍺',family:'social',compatible:['coffee','social','surprise'],options:[],enabled:true,minMinutes:20},{id:'surprise',label:'Sorpresa',emoji:'🎲',family:'social',compatible:['coffee','social','surprise'],options:[],enabled:true,minMinutes:20}];
const graph=():Graph=>({friends:new Set(),blocks:new Set(),riskPairs:new Set(),metBefore:new Set()});
const venue:Venue={id:'venue',name:'Café',location:a.location,activities:['coffee','social'],public:true,safe:true,accessible:true,capacity:6,budget:1,rating:4,openHour:0,closeHour:0,timezone:'Europe/Madrid'};
describe('geo and age',()=>{
 it('distance is symmetric, finite, nonnegative and identity zero',()=>fc.assert(fc.property(fc.double({min:-85,max:85,noNaN:true}),fc.double({min:-180,max:180,noNaN:true}),fc.double({min:-85,max:85,noNaN:true}),fc.double({min:-180,max:180,noNaN:true}),(lat,lon,lat2,lon2)=>{const x={lat,lon},y={lat:lat2,lon:lon2};expect(distance(x,x)).toBe(0);expect(distance(x,y)).toBeGreaterThanOrEqual(0);expect(distance(x,y)).toBeCloseTo(distance(y,x),5);})));
 it('quantizes exact position before persistence',()=>{expect(quantize({lat:37.360213,lon:-5.985125})).toEqual({lat:37.36,lon:-5.985});});
 it('enforces exact 18th birthday and rejects invalid dates',()=>{const t=new Date('2026-09-21T14:00:00Z');expect(isAdult('2008-09-21',t)).toBe(true);expect(isAdult('2008-09-22',t)).toBe(false);expect(isAdult('2000-02-30',t)).toBe(false);expect(isAdult('2099-01-01',t)).toBe(false);});
});
describe('hard constraints',()=>{
 it('accepts compatible community intentions',()=>expect(eligible(a,b,graph(),activities,now)).toBe(true));
 it.each([{over18:false},{accountStatus:'suspended'},{status:'RESERVED'},{expires:now},{country:'FR'},{start:now+7100000},{activity:'study'},{location:{lat:40,lon:-3}}])('rejects hard incompatibility %o',patch=>expect(eligible(a,{...b,...patch},graph(),activities,now)).toBe(false));
 it('excludes bilateral blocks regardless of score',()=>{const g=graph();g.blocks.add(pair('b','a'));expect(eligible(a,b,g,activities,now)).toBe(false);});
 it('excludes severe unresolved report relationships',()=>{const g=graph();g.riskPairs.add(pair('b','a'));expect(eligible(a,b,g,activities,now)).toBe(false);});
 it('enforces both sides visibility',()=>expect(eligible(a,{...b,visibility:'friends'},graph(),activities,now)).toBe(false));
 it('requires matching specific community, not any overlap',()=>expect(eligible(a,{...b,communities:['other']},graph(),activities,now)).toBe(false));
 it('does not match a user with themselves',()=>expect(eligible(a,{...a,id:'another'},graph(),activities,now)).toBe(false));
 it('friend of friend excludes blocked intermediaries',()=>{const g=graph();g.friends.add(pair('a','c'));g.friends.add(pair('b','c'));expect(socialLevel(a,b,g)).toBe(.8);g.blocks.add(pair('a','c'));expect(socialLevel(a,b,g)).toBe(.6);});
 it('open matching excludes basic trust',()=>expect(eligible({...a,visibility:'open',trust:'basic'},b,graph(),activities,now)).toBe(false));
});
describe('group construction',()=>{
 const pool=Array.from({length:10},(_,n)=>({...b,userId:'u'+n,id:'i'+n}));
 it('never creates a pair',()=>expect(formGroup(a,[b],graph(),activities,now)).toEqual([]));
 it('caps group at six and prefers four',()=>{expect(formGroup(a,pool,graph(),activities,now)).toHaveLength(4);expect(formGroup(a,pool,graph(),activities,now,10)).toHaveLength(6);});
 it('checks every pair, not only anchor',()=>{const g=graph();g.blocks.add(pair('u0','u1'));const group=formGroup(a,pool,g,activities,now);for(const x of group)for(const y of group)if(x!==y)expect(eligible(x,y,g,activities,now)).toBe(true);});
 it('deterministic regardless of input order with ties',()=>expect(formGroup(a,pool,graph(),activities,now).map(c=>c.id)).toEqual(formGroup(a,[...pool].reverse(),graph(),activities,now).map(c=>c.id)));
 it('records bounded explainable weighted components',()=>{const s=score(a,b,graph(),activities);expect(s.total).toBeGreaterThan(0);expect(s.total).toBeLessThanOrEqual(1);expect(s.components.social).toBe(.6);});
 it('hard filters withstand randomized blocks',()=>fc.assert(fc.property(fc.array(fc.integer({min:0,max:9}),{maxLength:20}),blocked=>{const g=graph();blocked.forEach(n=>g.blocks.add(pair('a','u'+n)));const group=formGroup(a,pool,g,activities,now);expect(group.every(c=>!blocked.includes(Number(c.userId.slice(1)))||c.userId==='a')).toBe(true);}))); 
});
describe('venue engine',()=>{
 it('selects a compatible public venue',()=>expect(selectVenues([a,b], [venue],now,now+3600000)[0].id).toBe('venue'));
 it.each([{public:false},{safe:false},{capacity:1},{budget:3},{activities:['study']},{location:{lat:40,lon:1}}])('rejects unsafe/incompatible venue %o',patch=>expect(selectVenues([a,b],[{...venue,...patch}],now,now+3600000)).toEqual([]));
 it('honors accessibility as a hard requirement',()=>expect(selectVenues([{...a,accessible:true},b],[{...venue,accessible:false}],now,now+3600000)).toEqual([]));
});
describe('state machine and reliability',()=>{
 it('does not confirm below minimum or before everyone accepts',()=>{expect(nextProposalState('PROPOSAL_PENDING',['accepted','accepted'],now+90000,now)).toBe('PARTIALLY_ACCEPTED');expect(nextProposalState('PROPOSAL_PENDING',['accepted','accepted','pending'],now+90000,now)).toBe('PARTIALLY_ACCEPTED');});
 it('confirms only all accepted; late acceptance loses to expiry',()=>{expect(nextProposalState('PARTIALLY_ACCEPTED',['accepted','accepted','accepted'],now+1,now)).toBe('CONFIRMED');expect(nextProposalState('PARTIALLY_ACCEPTED',['accepted','accepted','accepted'],now,now)).toBe('EXPIRED');});
 it('pass releases group, terminal states cannot resurrect',()=>{expect(nextProposalState('PROPOSAL_PENDING',['passed','pending','pending'],now+1,now)).toBe('CANCELLED');expect(nextProposalState('EXPIRED',['accepted','accepted','accepted'],now+1,now)).toBe('EXPIRED');});
 it('dampens newcomers and never returns a public shame score',()=>{expect(reliability(0,0)).toBe(80);expect(reliability(10,10)).toBe(90);expect(reliability(10,10)).toBeGreaterThan(reliability(7,10));});
 it('suppresses small counts and rounds density',()=>{expect(radarBand(0)).toBe(radarBand(2));expect(radarBand(3)).toBe(radarBand(5));});
 it('filters links and contact data in group chat',()=>{expect(textAllowed('Estoy en la entrada')).toBe(true);for(const s of ['https://malicious.test','llama al +34 600 555 222','jose@example.com','envía bizum'])expect(textAllowed(s)).toBe(false);});
});
