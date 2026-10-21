import {addDays} from './calendar.ts';
export const roles=['Super Admin','Production','Stage Manager','Assistant Stage Manager','Company Manager','Production Manager','Lighting','Audio','Video','Scenic','Costuming','Marketing','Development','Box Office','Director','Guest','Cast'] as const;
export const modules=['productions','calendar','venues','personnel','stage'] as const;
export type Module=typeof modules[number];
export type Permission='none'|'view'|'edit';
export type Member={id:string;email:string;user_id:string|null;roles:string[];job_title:string;active:boolean;production_ids:string[];person_id:string|null;delegated:string[];overrides:Partial<Record<Module,Permission>>;revision:number};
export type Account={name:string;phone:string;photo:string;landing:string;calendar_view:'calendar'|'list';personnel_view:'tiles'|'list';time_format:'12'|'24'};
export const defaultAccount:Account={name:'',phone:'',photo:'',landing:'Productions',calendar_view:'calendar',personnel_view:'tiles',time_format:'12'};
export type CalendarTemplate={id:string;name:string;anchor:'opening'|'closing';offset:number;duration:number;category:string;department:string;enabled:boolean};
export type StageSettings={start:string;end:string;location:string;departments:string[]};
export type TheaterSettings={name:string;timezone:string;contact_email:string;phone:string;logo:string;current_season_id:string};
export type WorkspaceSettings={theater_id:string;revision:number;theater:TheaterSettings;stage:StageSettings;templates:CalendarTemplate[]};
export type SettingsContext={user_id:string;read_only?:boolean;thanos:boolean;theaters:{id:string;name:string;timezone:string}[];theater_id:string|null;member:Member|null;account:Account;account_revision:number;settings:WorkspaceSettings|null;seasons:{id:string;name:string}[];members:Member[];admin:boolean;delegated:string[];permissions:Record<Module,Permission>};
export function templateDates(template:CalendarTemplate,production:{opening_date:string;closing_date:string}){const start=addDays(template.anchor==='opening'?production.opening_date:production.closing_date,template.offset);return {start,end:addDays(start,template.duration-1)};}
export function permissionFor(member:Pick<Member,'roles'|'overrides'|'production_ids'>,module:Module,productionId?:string):Permission{
 if(member.roles.includes('Super Admin'))return 'edit';
 if(member.overrides[module]==='none')return 'none';
 const department=member.roles.some(r=>!['Cast','Guest','Director'].includes(r));
 if(!department&&productionId&&!member.production_ids.includes(productionId))return 'none';
 let level:Permission='none';
 for(const role of member.roles){
  const allowed=module==='productions'||module==='calendar'||(['Production','Stage Manager','Assistant Stage Manager','Company Manager','Production Manager','Lighting','Audio','Video','Scenic','Costuming'].includes(role))||(role==='Marketing'&&module==='personnel')||(role==='Box Office'&&['personnel','venues'].includes(module))||(['Director','Guest'].includes(role)&&['stage','personnel','venues'].includes(module))||(role==='Cast'&&module==='stage');
  if(allowed&&level==='none')level='view';
  if(module==='stage'&&['Stage Manager','Assistant Stage Manager','Company Manager'].includes(role))level='edit';
 }
 return member.overrides[module]||level;
}
export function initialWorkspaceTab(c:Pick<SettingsContext,'theater_id'|'account'|'permissions'>){if(!c.theater_id)return 'Onboarding';const landing=c.account.landing||defaultAccount.landing;const landingModule=({Productions:'productions',Schedule:'calendar',Personnel:'personnel',Callboard:'stage'} as Record<string,Module>)[landing];return landingModule&&c.permissions[landingModule]!=='none'?landing:'Settings';}
