type PollFlight={promise:Promise<void>;trailing:boolean;latest:()=>Promise<unknown>};
const inFlight=new Map<string,PollFlight>();

/** Serializes the same polling callback across hook unmount/remount cycles. */
export async function runSerializedPoll(key:string,poll:()=>Promise<unknown>):Promise<void>{
 const existing=inFlight.get(key);
 if(existing){existing.latest=poll;existing.trailing=true;return existing.promise;}
 const flight:PollFlight={promise:Promise.resolve(),trailing:false,latest:poll};
 inFlight.set(key,flight);
 flight.promise=Promise.resolve().then(async()=>{
  let current=poll;
  while(true){
   flight.trailing=false;
   try{await current();}catch(error){if(!flight.trailing)throw error;}
   if(!flight.trailing)return;
   current=flight.latest;
  }
 }).finally(()=>{if(inFlight.get(key)===flight)inFlight.delete(key);});
 return flight.promise;
}
