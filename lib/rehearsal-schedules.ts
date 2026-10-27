import type {CalendarEvent, Person, Venue} from './loon-types';
import {parseCSV} from './imports.ts';
import {toUTC} from './calendar.ts';
export const scheduleHeaders=['date','start_time','end_time','venue','event_name','scene','cast_called'];
export const scheduleTemplate=()=>scheduleHeaders.join(',')+'\r\n';
export type ScheduleDraft={id:string;production_id:string;expected_updated_at:string|null;start:string;end:string;venue_id:string;title:string;schedule_scene:string;schedule_cast:string[];call_status:'Published'|'Canceled'};
export function scheduleTimes(day:string,start:string,end:string){
 if(!/^\d{4}-\d{2}-\d{2}$/.test(day)||!Number.isFinite(Date.parse(day))||new Date(day+'T12:00:00Z').toISOString().slice(0,10)!==day)throw Error('Use a valid date in YYYY-MM-DD format.');
 if(!/^([01]\d|2[0-3]):[0-5]\d$/.test(start)||!/^([01]\d|2[0-3]):[0-5]\d$/.test(end))throw Error('Use 24-hour times in HH:MM format.');
 const result={start:toUTC(day+'T'+start),end:toUTC(day+'T'+end)};
 if(result.end<=result.start)throw Error('End time must be after start time on the same day.');return result;
}
export function scheduleKey(e:Pick<CalendarEvent,'production_id'|'venue_id'|'title'|'start'|'end'>){return [e.production_id,e.venue_id,e.title.trim().toLowerCase(),new Date(e.start).toISOString(),new Date(e.end).toISOString()].join('|');}
export function previewScheduleCSV(source:string,productionId:string,venues:Venue[],cast:Person[],existing:CalendarEvent[]){
 const rows=parseCSV(source,scheduleHeaders,scheduleHeaders.slice(0,5));
 const seen=new Set(existing.filter(e=>e.rehearsal_schedule&&e.call_status!=='Canceled').map(scheduleKey));
 return rows.map((row,i)=>{
  try{
   const matches=venues.filter(v=>v.id===row.venue||v.name.trim().toLowerCase()===row.venue.toLowerCase());
   if(matches.length!==1)throw Error(`Venue "${row.venue}" is missing or ambiguous. Use its exact name or ID.`);
   if(!row.event_name||row.event_name.length>200)throw Error('Event name must contain 1–200 characters.');
   if((row.scene||'').length>200)throw Error('Scene must be 200 characters or fewer.');
   const members=(row.cast_called||'').split('|').map(s=>s.trim()).filter(Boolean).map(name=>{
    const people=cast.filter(p=>p.id===name||p.display_name.trim().toLowerCase()===name.toLowerCase());
    if(people.length!==1)throw Error(`Cast member "${name}" is missing or ambiguous for this show. Use their exact display name or ID.`);
    return people[0].id;
   });
   const draft:ScheduleDraft={id:crypto.randomUUID(),production_id:productionId,expected_updated_at:null,...scheduleTimes(row.date,row.start_time,row.end_time),venue_id:matches[0].id,title:row.event_name,schedule_scene:row.scene||'',schedule_cast:[...new Set(members)],call_status:'Published'};
   const key=scheduleKey(draft);if(seen.has(key))throw Error('This event already exists in the schedule or file.');seen.add(key);
   return {row:i+2,draft,error:''};
  }catch(error){return {row:i+2,draft:null,error:(error as Error).message};}
 });
}
