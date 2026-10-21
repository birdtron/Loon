import type {SettingsContext} from './settings';
export const contactFields={email:254,phone:80,address_line_1:300,address_line_2:300,city:120,state:120,zip:32,emergency_contact_name:200,emergency_contact_phone:80} as const;
export type PersonnelContactDraft=Record<keyof typeof contactFields,string>;
export type PersonnelContact=PersonnelContactDraft & {revision:number};
export const emptyContact:PersonnelContact={email:'',phone:'',address_line_1:'',address_line_2:'',city:'',state:'',zip:'',emergency_contact_name:'',emergency_contact_phone:'',revision:0};
export function canManagePersonnelContacts(context:Pick<SettingsContext,'admin'|'member'|'permissions'>|null){return Boolean(context&&(context.admin||(context.permissions.stage==='edit'&&context.member?.active&&context.member.roles.some(r=>['Stage Manager','Assistant Stage Manager','Company Manager'].includes(r)))));}
export function cleanPersonnelContact(draft:PersonnelContactDraft):PersonnelContactDraft{
 const clean=Object.fromEntries(Object.keys(contactFields).map(key=>[key,''])) as PersonnelContactDraft;for(const key of Object.keys(contactFields) as (keyof PersonnelContactDraft)[]){clean[key]=draft[key].trim();if(clean[key].length>contactFields[key])throw Error(`${key.replaceAll('_',' ')} is too long.`);}
 if(clean.email&&!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(clean.email))throw Error('Enter a valid email address.');return clean;
}
