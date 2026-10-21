import type {Person} from './loon-types';
export type ClockPerson={id:string;display_name:string;job_title:string;departments:string[];intern:boolean};
export type ClockEntry={id:string;theater_id:string;person_id:string;production_id:string;work_date:string;started_at:string;ended_at:string|null;minutes:number|null;department:string;role:string;notes:string;revision:number};
export type ClockContext={allowed:boolean;manager:boolean;read_only:boolean;person_id:string|null;people:ClockPerson[];productions:{id:string;title:string}[]};
export type ClockDraft={id:string;person_id:string;production_id:string;department:string;role:string;notes:string};
export type LaborRow={person_id:string;personnel:string;production_id:string;production:string;department:string;role:string;minutes:number};
export function eligibleForClocking(p:Pick<Person,'intern'|'person_types'>){return p.intern||p.person_types.some(t=>['Creative','Staff','Crew'].includes(t));}
export function elapsedMinutes(start:string,end:string){const minutes=(Date.parse(end)-Date.parse(start))/60000;return Number.isFinite(minutes)?Math.max(0,minutes):0;}
export function validateClockDraft(d:ClockDraft){if(!d.person_id||!d.production_id)throw Error('Choose personnel and a production.');if(!d.department.trim()||d.department.length>120||!d.role.trim()||d.role.length>200)throw Error('Enter a department and role.');if(d.notes.length>10000)throw Error('Notes must be 10,000 characters or fewer.');}
export function laborGroups(rows:LaborRow[],group:'production'|'personnel'|'department'){const groups=new Map<string,number>();for(const r of rows){const label=r[group]||'Unassigned';groups.set(label,(groups.get(label)||0)+Number(r.minutes));}return [...groups].map(([label,minutes])=>({label,minutes})).sort((a,b)=>b.minutes-a.minutes||a.label.localeCompare(b.label));}
export function hours(minutes:number){return new Intl.NumberFormat('en-US',{maximumFractionDigits:2}).format(minutes/60);}
