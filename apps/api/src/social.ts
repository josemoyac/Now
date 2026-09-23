import type {Query} from '../../../db/client';
import type {Activity,CommunityEventView,CommunityView,HistoryView,PersonSummary} from '../../../packages/types/src/index';
import {activities,iso,requireValue} from './core';
import {MatchingService} from './matching';

type CommunityRow={id:string;name:string;kind:string;city:string;description:string;method:string;verified:boolean|null;user_id:string|null};
const peopleSql="SELECT DISTINCT u.id,u.display_name AS \"displayName\",u.avatar FROM users u JOIN memberships cm ON cm.user_id=u.id AND cm.community_id=$1 AND cm.verified=true JOIN match_members other ON other.user_id=u.id AND other.checked_in=true AND other.safety_exit=false JOIN matches m ON m.id=other.match_id AND m.state='COMPLETED' JOIN match_members me ON me.match_id=m.id AND me.user_id=$2 AND me.checked_in=true AND me.safety_exit=false WHERE u.id<>$2 AND u.status='active' AND NOT EXISTS(SELECT 1 FROM blocks b WHERE (b.blocker=$2 AND b.blocked=u.id) OR (b.blocked=$2 AND b.blocker=u.id)) ORDER BY \"displayName\"";

export async function communityList(q:Query,uid:string):Promise<CommunityView[]>{
 const rows=await q.all<CommunityRow>('SELECT c.id,c.name,c.kind,c.city,c.description,c.method,m.verified,m.user_id FROM communities c LEFT JOIN memberships m ON m.community_id=c.id AND m.user_id=$1 WHERE c.enabled=true ORDER BY c.name',[uid]);
 return Promise.all(rows.map(async c=>{
  const members=await q.one<{count:string}>("SELECT count(*) FROM memberships cm JOIN users u ON u.id=cm.user_id WHERE cm.community_id=$1 AND cm.verified=true AND u.status='active'",[c.id]);
  const events=await q.one<{count:string}>("SELECT count(*) FROM matches WHERE community_id=$1 AND state='COMPLETED'",[c.id]);
  const metMembers=c.verified?await q.all<PersonSummary>(peopleSql,[c.id,uid]):[];
  const memberCount=Number(members?.count||0);
  return {id:c.id,name:c.name,kind:c.kind,city:c.city,description:c.description,method:c.method,joined:!!c.user_id,verified:!!c.verified,memberCount,eventCount:Number(events?.count||0),metMembers,unmetCount:Math.max(0,memberCount-metMembers.length-(c.verified?1:0))};
 }));
}

export async function communityEvents(q:Query,uid:string,cid:string):Promise<CommunityEventView[]>{
 requireValue(await q.one('SELECT 1 FROM memberships cm JOIN communities c ON c.id=cm.community_id WHERE cm.user_id=$1 AND cm.community_id=$2 AND cm.verified=true AND c.enabled=true',[uid,cid]),'COMMUNITY_REQUIRED','Verifica esta comunidad para consultar sus encuentros.');
 const rows=await q.all<{id:string;activity:string;subtype:string|null;scheduled_at:number;venue:string|null;attendee_count:string;attended_by_me:boolean}>("SELECT m.id,m.activity,m.subtype,m.scheduled_at,v.name AS venue,(SELECT count(*) FROM match_members mm WHERE mm.match_id=m.id AND mm.checked_in=true AND mm.safety_exit=false) AS attendee_count,EXISTS(SELECT 1 FROM match_members mm WHERE mm.match_id=m.id AND mm.user_id=$2 AND mm.checked_in=true AND mm.safety_exit=false) AS attended_by_me FROM matches m LEFT JOIN venues v ON v.id=m.venue_id WHERE m.community_id=$1 AND m.state='COMPLETED' ORDER BY m.scheduled_at DESC LIMIT 100",[cid,uid]);
 const aa=await activities(q);
 return Promise.all(rows.map(async row=>{
  const attendees=row.attended_by_me?await q.all<PersonSummary>("SELECT u.id,u.display_name AS \"displayName\",u.avatar FROM match_members mm JOIN users u ON u.id=mm.user_id WHERE mm.match_id=$1 AND mm.checked_in=true AND mm.safety_exit=false AND u.status='active' AND NOT EXISTS(SELECT 1 FROM blocks b WHERE (b.blocker=$2 AND b.blocked=u.id) OR (b.blocked=$2 AND b.blocker=u.id)) ORDER BY u.display_name",[row.id,uid]):null;
  return {id:row.id,activity:aa.find(a=>a.id===row.activity) as Activity,subtype:row.subtype,scheduledAt:iso(row.scheduled_at),venue:row.venue,attendeeCount:Number(row.attendee_count),attendees,attendedByMe:row.attended_by_me};
 }));
}

export async function myHistory(q:Query,uid:string,matching:MatchingService):Promise<HistoryView[]>{
 const rows=await q.all<{id:string;community_id:string|null;community_name:string|null;last_message:string|null}>("SELECT m.id,m.community_id,c.name AS community_name,(SELECT x.body FROM messages x WHERE x.match_id=m.id AND x.state='visible' AND x.expires_at>$2 AND NOT EXISTS(SELECT 1 FROM blocks b WHERE (b.blocker=$1 AND b.blocked=x.sender_id) OR (b.blocked=$1 AND b.blocker=x.sender_id)) ORDER BY x.created_at DESC LIMIT 1) AS last_message FROM matches m JOIN match_members mm ON mm.match_id=m.id LEFT JOIN communities c ON c.id=m.community_id WHERE mm.user_id=$1 AND mm.checked_in=true AND mm.safety_exit=false AND m.state='COMPLETED' ORDER BY m.scheduled_at DESC LIMIT 100",[uid,Date.now()]);
 return Promise.all(rows.map(async row=>{
  const view=await matching.view(q,uid,row.id);
  return {id:row.id,activity:view.activity,subtype:view.subtype,scheduledAt:view.scheduledAt,state:view.state,community:row.community_id&&row.community_name?{id:row.community_id,name:row.community_name}:null,participants:view.participants.filter(p=>p.checkedIn).map(p=>({id:p.id,displayName:p.displayName,avatar:p.avatar})),chatOpen:view.chatOpen,lastMessage:row.last_message};
 }));
}

export async function myConversations(q:Query,uid:string,matching:MatchingService):Promise<HistoryView[]>{
 return myHistory(q,uid,matching);
}
