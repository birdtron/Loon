import {contactFields,emptyContact,cleanPersonnelContact} from './personnel-contacts.ts';
import type {PersonnelContactDraft} from './personnel-contacts';
import type {SettingsContext} from './settings';
export const avatarOptions=[{id:'bird-00',label:'Eagle'},{id:'bird-01',label:'Cardinal'},{id:'bird-02',label:'Owl'},{id:'bird-03',label:'Peacock'},{id:'bird-04',label:'Songbird'},{id:'bird-05',label:'Origami crane'},{id:'bird-06',label:'Pelican'},{id:'bird-07',label:'Standing bird'},{id:'bird-08',label:'Kiwi'},{id:'bird-09',label:'Flamingo'},{id:'bird-10',label:'Geometric bird'},{id:'bird-11',label:'Flying bird'},{id:'bird-12',label:'Parrot'},{id:'bird-13',label:'Hummingbird'}] as const;
export const avatars=avatarOptions.map(a=>a.id);
export const avatarLabel=(id:string)=>avatarOptions.find(a=>a.id===id)?.label||'Bird';
export const unionOptions=['AEA','SAG-AFTRA','IATSE','AFM','UMAW','AGMA','AGVA','USA 829','SDC','Other'];
export type IntakeAssignment={production_id:string;role:string};
export type IntakePayload={full_name:string;known_as:string;area:'Cast'|'Creative'|'Admin';job_title:string;department:string;bio:string;favorite_shakespeare:string;unions:string[];other_union:string;intern:boolean;contacts:PersonnelContactDraft;assignments:IntakeAssignment[];avatar:typeof avatars[number];headshot:string;resume:string;resume_name:string;consent:boolean};
export type IntakeFormInfo={theater_name:string;theater_logo?:string;recipient_email?:string;season_name:string;recipient_name:string;submitted:boolean;productions:{id:string;title:string;roles?:{Cast:string[];Creative:string[]}}[]};
export type IntakeLink={id:string;recipient_name:string;recipient_email:string;season_name:string;expires_at:string;revoked_at:string|null;submitted:boolean};
export type IntakeSummary={id:string;full_name:string;email:string;area:string;status:'Pending'|'Approved'|'Rejected';season_id:string;season_name:string;submitted_at:string;revision:number;review_note:string};
export type IntakeCandidate={id:string;display_name:string;email:string;updated_at:string;contact_revision:number};
export type IntakeQueue={links:IntakeLink[];submissions:IntakeSummary[];people:IntakeCandidate[];pending_count:number};
export type IntakeDetail=IntakeSummary & {access_role?:string;login_verified?:boolean;payload:IntakePayload;person_id:string|null};
export type IntakeRPC=(name:string,body:object)=>Promise<unknown>;
export function canManageIntake(c:Pick<SettingsContext,'admin'|'member'|'permissions'>|null){return Boolean(c&&(c.admin||(c.member?.active&&c.member.roles.includes('Company Manager')&&c.permissions.stage==='edit'&&c.permissions.personnel!=='none')));}
export function emptyIntake():IntakePayload{return {full_name:'',known_as:'',area:'Cast',job_title:'',department:'',bio:'',favorite_shakespeare:'',unions:[],other_union:'',intern:false,contacts:Object.fromEntries(Object.keys(contactFields).map(k=>[k,emptyContact[k as keyof PersonnelContactDraft]])) as PersonnelContactDraft,assignments:[{production_id:'',role:''}],avatar:'bird-00',headshot:'',resume:'',resume_name:'',consent:false};}
export function validateIntake(p:IntakePayload,productions:{id:string}[]){
 if(!p.full_name.trim()||p.full_name.trim().length>200)throw Error('Enter your full name (up to 200 characters).');
 const contacts=cleanPersonnelContact(p.contacts);if(!contacts.email)throw Error('Enter your email address.');
 if(!['Cast','Creative','Admin'].includes(p.area))throw Error('Choose an area.');
 if(p.area==='Admin'&&(!p.department.trim()||!p.job_title.trim()))throw Error('Enter your department and job title.');
 if(p.area!=='Admin'&&(!p.assignments.length||p.assignments.length>20||p.assignments.some(a=>!productions.some(x=>x.id===a.production_id)||!a.role.trim()||a.role.trim().length>200)))throw Error('Choose a show and enter a role for every production.');
 if(p.unions.some(u=>!unionOptions.includes(u))||(p.unions.includes('Other')&&!p.other_union.trim()))throw Error('Check your union affiliations and specify Other if selected.');
 if(!avatars.includes(p.avatar))throw Error('Choose a profile image.');
 if(p.bio.length>10000||p.known_as.length>200||p.job_title.length>200||p.department.length>120||p.favorite_shakespeare.length>200||p.other_union.length>200)throw Error('One of your profile fields is too long.');
 if(!p.consent)throw Error('Confirm that Company Management may review and store your information.');
 return {...p,full_name:p.full_name.trim(),contacts};
}
export async function readResume(file:File){if(file.type!=='application/pdf'||file.size>2*1024*1024||!file.size)throw Error('Choose a PDF résumé up to 2 MB.');const bytes=new Uint8Array(await file.arrayBuffer());if(new TextDecoder().decode(bytes.slice(0,5))!=='%PDF-')throw Error('The résumé must be a valid PDF file.');return readDataURL(file);}
function readDataURL(file:Blob){return new Promise<string>((resolve,reject)=>{const r=new FileReader();r.onload=()=>resolve(String(r.result));r.onerror=()=>reject(Error('Could not read the file.'));r.readAsDataURL(file);});}
export async function readIntakeHeadshot(file:File){if(!['image/jpeg','image/png','image/webp'].includes(file.type)||!file.size||file.size>4*1024*1024)throw Error('Choose a JPG, PNG or WebP headshot up to 4 MB.');const bitmap=await createImageBitmap(file);try{const scale=Math.min(1,1200/Math.max(bitmap.width,bitmap.height));const canvas=document.createElement('canvas');canvas.width=Math.round(bitmap.width*scale);canvas.height=Math.round(bitmap.height*scale);const ctx=canvas.getContext('2d');if(!ctx)throw Error('Could not process the headshot.');ctx.fillStyle='white';ctx.fillRect(0,0,canvas.width,canvas.height);ctx.drawImage(bitmap,0,0,canvas.width,canvas.height);let url=canvas.toDataURL('image/jpeg',0.85);if(url.length>699000)url=canvas.toDataURL('image/jpeg',0.6);if(url.length>699000)throw Error('Choose a smaller headshot.');return url;}finally{bitmap.close();}}

export function roleSuggestions(info:IntakeFormInfo,productionId:string,area:string){return [...new Set(info.productions.find(p=>p.id===productionId)?.roles?.[area==='Creative'?'Creative':'Cast']||[])].sort((a,b)=>a.localeCompare(b));}
export function normalizeRole(value:string,options:string[]){return options.find(r=>r.toLowerCase()===value.trim().toLowerCase())||value.trim();}
export function theaterLogo(name:string,configured?:string){return configured||(['Orlando Shakespeare Theater','Orlando Shakes'].includes(name)?'/brand/orlando-shakes.webp':'');}
