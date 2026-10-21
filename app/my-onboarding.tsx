'use client';
import {useEffect,useState,useRef} from 'react';
import type {IntakeRPC} from '../lib/intake';
type Status={id:string;theater_name:string;season_name:string;status:string;access_role:string};
export default function MyOnboarding({rpc,onLogout}:{rpc:IntakeRPC;onLogout:()=>void}){
 const [rows,setRows]=useState<Status[]|null>(null),[error,setError]=useState('');
 const api=useRef(rpc);useEffect(()=>{api.current=rpc;},[rpc]);
 useEffect(()=>{let active=true;void api.current('get_my_onboarding',{}).then(r=>{if(active)setRows(r as Status[]);}).catch(e=>{if(active)setError((e as Error).message);});return()=>{active=false;};},[]);
 return <section className="my-onboarding"><h1>Your Loon onboarding</h1><p>Your login is active. Workspace access starts after Company Management approves your personnel submission.</p>{error&&<p className="error" role="alert">{error}</p>}{!rows&&!error&&<p role="status">Checking your invitations…</p>}{rows?.map(row=><article key={row.id}><h2>{row.theater_name}</h2><p>{row.season_name} · {row.status==='Pending'?'Waiting for Company Management approval':row.status==='Rejected'?'Submission not approved — contact Company Management':row.status}</p>{row.status==='Intake required'&&<a className="primary" href={'/intake#'+row.id}>Complete personnel intake</a>}{row.status==='Approved'&&<p>Your personnel record is approved. Contact Company Management if workspace access is still pending.</p>}</article>)}{rows?.length===0&&<p>No active invitation was found. Contact Company Management to request access.</p>}<button className="secondary" onClick={onLogout}>Sign out</button></section>;
}
