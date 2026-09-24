import {useEffect} from 'react';
import {AppState,Platform} from 'react-native';
import {runSerializedPoll} from './pollingGate';

/** Runs one request at a time while the app is foregrounded, retrying with bounded backoff. */
export function useForegroundPolling(enabled:boolean,intervalMs:number,poll:()=>Promise<unknown>,onError:(error:unknown)=>void,resourceKey:string){
 useEffect(()=>{
  if(!enabled)return;
  let stopped=false,active=Platform.OS==='web'||AppState.currentState==='active',running=false,rerunRequested=false,failures=0;
  let timer:ReturnType<typeof setTimeout>|undefined;
  const clear=()=>{if(timer)clearTimeout(timer);timer=undefined;};
  const schedule=(delay:number)=>{clear();if(!stopped&&active)timer=setTimeout(()=>void run(),delay);};
  const run=async()=>{if(stopped||!active)return;if(running){rerunRequested=true;return;}running=true;try{await runSerializedPoll(resourceKey,poll);failures=0;}catch(error){failures=Math.min(failures+1,5);if(!stopped&&active)onError(error);}finally{running=false;if(!stopped&&active&&rerunRequested){rerunRequested=false;void run();}else schedule(Math.min(intervalMs*2**failures,60000));}};
  void run();
  const subscription=AppState.addEventListener('change',state=>{active=Platform.OS==='web'||state==='active';if(active)void run();else clear();});
  return()=>{stopped=true;clear();subscription.remove();};
 },[enabled,intervalMs,poll,onError]);
}
