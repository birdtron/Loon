'use client';
import {useCallback,useEffect,useRef,useState} from 'react';
import {Download,Upload} from 'lucide-react';
import type {Person} from '../lib/loon-types';
import {SUPABASE_URL,SUPABASE_KEY} from '../lib/supabase-config';
type Contract={id:string;name:string;created_at:string};
export default function PersonnelContracts({person,getToken,readOnly=false}:{person:Person;getToken:()=>Promise<string>;readOnly?:boolean}){
 const auth=useRef(getToken);useEffect(()=>{auth.current=getToken;},[getToken]);
 const [files,setFiles]=useState<Contract[]>([]),[busy,setBusy]=useState(false),[loading,setLoading]=useState(true),[error,setError]=useState(''),[notice,setNotice]=useState('');
 const prefix=`${person.theater_id}/${person.id}`;
 const request=useCallback(async(path:string,options:RequestInit={})=>{const response=await fetch(SUPABASE_URL+'/storage/v1'+path,{...options,headers:{apikey:SUPABASE_KEY,Authorization:'Bearer '+await auth.current(),...options.headers}});if(!response.ok){let msg='Contract request failed.';try{const value=await response.json();msg=value.message||value.error||msg;}catch{}throw Error(msg);}return response;},[]);
 const load=useCallback(async()=>{try{const res=await request('/object/list/personnel-contracts',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({prefix,limit:100,sortBy:{column:'created_at',order:'desc'}})});setFiles((await res.json()).filter((f:Contract)=>f.id));setError('');}catch(e){setError((e as Error).message);}finally{setLoading(false);}},[prefix,request]);
 // Initial remote fetch updates state only after the response settles.
 // eslint-disable-next-line react-hooks/set-state-in-effect
 useEffect(()=>{if(!readOnly)void load();},[load,readOnly]);
 async function upload(file:File){setBusy(true);setError('');setNotice('');try{if(!['application/pdf','image/jpeg','image/png'].includes(file.type)||!file.size||file.size>10*1024*1024)throw Error('Choose a PDF, JPG, or PNG contract up to 10 MB.');const path=prefix+'/'+crypto.randomUUID()+'_'+file.name.replace(/[^a-zA-Z0-9._()-]/g,'_');await request('/object/personnel-contracts/'+path,{method:'POST',headers:{'Content-Type':file.type},body:file});await load();setNotice('Signed contract saved privately.');}catch(e){setError((e as Error).message);}finally{setBusy(false);}}
 async function download(file:Contract){setBusy(true);setError('');try{const response=await request('/object/authenticated/personnel-contracts/'+prefix+'/'+encodeURIComponent(file.name));const url=URL.createObjectURL(await response.blob());const a=document.createElement('a');a.href=url;a.download=file.name.slice(37);a.click();setTimeout(()=>URL.revokeObjectURL(url),1000);}catch(e){setError((e as Error).message);}finally{setBusy(false);}}
 if(readOnly)return <section className="person-profile-section"><h2>Signed contracts</h2><p>Private contract attachments are unavailable in the read-only demo.</p></section>;
 return <section className="person-profile-section"><h2>Signed contracts</h2><p className="form-help">Private to Company Management and Super Admin. PDF, JPG, or PNG · Up to 10 MB.</p><label className="contract-upload"><Upload size={16}/>Upload signed contract<input type="file" accept="application/pdf,image/jpeg,image/png" disabled={busy} onChange={e=>{const file=e.target.files?.[0];if(file)void upload(file);e.target.value='';}}/></label>{error&&<p className="error" role="alert">{error}</p>}{notice&&<p className="notice" role="status">{notice}</p>}{loading&&<p role="status">Loading contracts…</p>}{!loading&&!files.length&&<p>No contracts attached.</p>}<ul className="contract-list">{files.map(f=><li key={f.id}><span>{f.name.slice(37)}</span><button className="secondary" disabled={busy} onClick={()=>void download(f)}><Download size={15}/>Download</button></li>)}</ul>{files.length===100&&<p>Showing the latest 100 contracts.</p>}</section>;
}
