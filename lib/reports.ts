import {localDay} from './calendar.ts';
import {callOnDay} from './cast-scheduling.ts';
import type {CalendarEvent,CallCast,ProductionCredit} from './loon-types';
export type ReportKind='Rehearsal'|'Performance';
export type ReportData={show_critical?:boolean;critical_note?:string;start:string;end:string;house:string;intermission:string;act_two:string;has_intermission:boolean;summary:string;cancelled:boolean;cancel_reason:string;cancel_details:string;breaks:string;break_details:string;penalties:boolean;penalty_reason:string;penalty_details:string;fight:string;fight_details:string;departments:Record<string,string>};
export type ReportCast={id:string;name:string;source:'callboard'|'additional'};
export type StageReport={id:string;theater_id:string;production_id:string;kind:ReportKind;report_date:string;event_id:string|null;data:ReportData;cast_snapshot:ReportCast[];source_calls:string[];fight_required:boolean;revision:number;updated_at:string};
export type ReportDraft={id:string;production_id:string;kind:ReportKind;report_date:string;event_id:string|null;data:ReportData;additional_cast:string[];refresh_cast:boolean;expected:number|null};
export const cancellationReasons=['Staffing','Technical','Facility','Other'];
export const penaltyReasons=['Break intrusion','Schedule change < 24 hours','Matrix Overage','6th Day','7th Day','Media','Other'];
export function calledOnDate(events:CalendarEvent[],members:CallCast[],production:string,date:string){const ids=new Set(events.filter(e=>e.production_id===production&&callOnDay(e,date)).map(e=>e.id));return [...new Set(members.filter(m=>ids.has(m.event_id)).map(m=>m.person_id))];}
export function hasFightCredit(credits:ProductionCredit[],production:string){return credits.some(c=>c.production_id===production&&/fight.*choreograph|choreograph.*fight/i.test(c.role));}
export function reportRuntime(data:ReportData){if(!data.start||!data.end||data.cancelled)return null;const minutes=(Date.parse(data.end)-Date.parse(data.start))/60000;return Number.isFinite(minutes)&&minutes>0?minutes:null;}
export function validateReport(kind:ReportKind,date:string,d:ReportData,fight:boolean){
 if(d.show_critical&&(!d.critical_note?.trim()||d.critical_note.length>10000))throw Error('Describe the show-critical note (up to 10,000 characters).');
 if(d.cancelled){if(!cancellationReasons.includes(d.cancel_reason)||!d.cancel_details.trim())throw Error('Choose a cancellation reason and add details.');}
 else{
  if(!d.start||!d.end||!reportRuntime(d)||(reportRuntime(d)??0)>1440)throw Error('Enter start and end times in order, within 24 hours.');
  if(localDay(d.start)!==date)throw Error('Start time must fall on the report date.');
  if(kind==='Rehearsal'&&(!['Yes','No'].includes(d.breaks)||(d.breaks==='No'&&!d.break_details.trim())))throw Error('Confirm whether union breaks were upheld and explain any missed breaks.');
  if(kind==='Performance'){
   if(!d.house||Date.parse(d.house)>Date.parse(d.start))throw Error('House open must be at or before performance start.');
   if(d.has_intermission&&(!d.intermission||!d.act_two||Date.parse(d.intermission)<Date.parse(d.start)||Date.parse(d.act_two)<=Date.parse(d.intermission)||Date.parse(d.act_two)>Date.parse(d.end)))throw Error('Enter intermission and Act II times in performance order.');
   if(fight&&(!['Yes','No'].includes(d.fight)||(d.fight==='No'&&!d.fight_details.trim())))throw Error('Record the fight call and explain if it did not take place.');
  }
 }
 if(kind==='Performance'&&d.penalties&&(!penaltyReasons.includes(d.penalty_reason)||!d.penalty_details.trim()))throw Error('Choose a penalty or overtime reason and add details.');
 if(!d.summary.trim())throw Error('Enter a general summary.');
}
export function blankReport(departments:string[]):ReportData{return {start:'',end:'',house:'',intermission:'',act_two:'',has_intermission:false,summary:'',cancelled:false,cancel_reason:'',cancel_details:'',breaks:'',break_details:'',penalties:false,penalty_reason:'',penalty_details:'',fight:'',fight_details:'',departments:Object.fromEntries(departments.map(d=>[d,'']))};}

export type CriticalNote={report_id:string;theater_id:string;production_id:string;report_date:string;note:string;revision:number;resolved_at:string|null;updated_at:string};
