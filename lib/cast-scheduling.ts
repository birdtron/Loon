import type {CalendarEvent, Person, ProductionCredit} from './loon-types';
import {localDay, toUTC} from './calendar.ts';
export function productionCast(people:Person[],credits:ProductionCredit[],productionId:string){
 const ids=new Set(credits.filter(c=>c.production_id===productionId&&c.credit_type==='Cast').map(c=>c.person_id));
 return people.filter(p=>ids.has(p.id)).sort((a,b)=>a.display_name.localeCompare(b.display_name));
}
export function callOnDay(event:CalendarEvent,day:string){
 return event.category==='Rehearsal'&&event.call_status==='Published'&&localDay(event.start)<=day&&localDay(new Date(new Date(event.end).getTime()-1))>=day;
}
export function rehearsalTimes(day:string,start:string,end:string){
 const begin=toUTC(`${day}T${start}`),finish=toUTC(`${day}T${end}`);
 if(finish<=begin)throw Error('End time must be after start time.');return {start:begin,end:finish};
}
