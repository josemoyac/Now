import {describe,it,expect} from 'vitest';
import {runSerializedPoll} from './pollingGate';

describe('serialized foreground polling',()=>{
 it('coalesces remounts to a single trailing run using the newest callback',async()=>{
  let release!:()=>void,active=0,maxActive=0;
  const calls:number[]=[];
  const makePoll=(id:number,fail=false)=>async()=>{calls.push(id);active++;maxActive=Math.max(maxActive,active);if(id===1){await new Promise<void>(resolve=>{release=resolve;});active--;if(fail)throw new Error('stale request failed');return;}active--;};
  const first=runSerializedPoll('messages:match-a',makePoll(1,true));
  await Promise.resolve();
  const resumed=runSerializedPoll('messages:match-a',makePoll(2));
  const resumedAgain=runSerializedPoll('messages:match-a',makePoll(3));
  expect(calls).toEqual([1]);
  release();
  await Promise.all([first,resumed,resumedAgain]);
  expect(calls).toEqual([1,3]);
  expect(maxActive).toBe(1);
 });
 it('does not make an unrelated resource wait',async()=>{
  let release!:()=>void,secondFinished=false;
  const first=runSerializedPoll('messages:match-a',()=>new Promise<void>(resolve=>{release=resolve;}));
  await Promise.resolve();
  await runSerializedPoll('messages:match-b',async()=>{secondFinished=true;});
  expect(secondFinished).toBe(true);
  release();
  await first;
 });
});
