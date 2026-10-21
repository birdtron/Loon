'use client';
import {useEffect, useRef, useState} from 'react';
import Image from 'next/image';
import BirdAvatar from './bird-avatar';
import PersonnelContactDetails from './personnel-contact-details';
import type {ContactActions} from './personnel-contact-details';
import {ArrowLeft, ArrowUpRight, Camera, Check, LayoutGrid, List, LoaderCircle, Pencil, Search, Users, X} from 'lucide-react';
import {SUPABASE_KEY, SUPABASE_URL} from '../lib/supabase-config';
import {personTypes, type Person, type PersonDraft, type Production, type ProductionCredit} from '../lib/loon-types';
import {filterPeople, peopleInSeason, initials, personName, portraitName, splitLabels} from '../lib/personnel';

type Props = ContactActions & {seasonMemberships?:{person_id:string;season_id:string}[];canManageContacts?:boolean;onDirty?:(dirty:boolean)=>void; currentSeason?:string;defaultView?:'tiles'|'list';canEdit?:boolean;
  people: Person[]; credits: ProductionCredit[]; productions: Production[];
  productionFilter: string; onProductionFilterChange: (id: string) => void;
  getToken: () => Promise<string>;
  onSave: (person: Person, draft: PersonDraft) => Promise<void>;
  onUpload: (person: Person, file: File) => Promise<void>;
  onOpenProduction: (id: string) => void;
};
export function Headshot({person, getToken, large=false}: {person: Person; getToken: Props['getToken']; large?: boolean}) {
  const [privateUrl, setPrivateUrl] = useState(''), [failed, setFailed] = useState(false);
  const tokenRef = useRef(getToken); tokenRef.current = getToken;
  useEffect(() => {
    let objectUrl='', active=true; const abort=new AbortController(); setFailed(false); setPrivateUrl('');
    if (person.intake_headshot || (person.headshot_kind==='uploaded' && person.headshot_path)) {
      void (async()=>{
        try {
          const token=await tokenRef.current();
          if(person.intake_headshot){const response=await fetch(`${SUPABASE_URL}/rest/v1/rpc/get_personnel_media`,{method:'POST',headers:{apikey:SUPABASE_KEY,Authorization:`Bearer ${token}`,'Content-Type':'application/json'},body:JSON.stringify({p:person.id,kind:'headshot'}),signal:abort.signal});if(!response.ok)throw Error('Headshot unavailable');const result=await response.json();if(active)setPrivateUrl(result.data||'');return;}
          const path=person.headshot_path!.split('/').map(encodeURIComponent).join('/');
          const response=await fetch(`${SUPABASE_URL}/storage/v1/object/authenticated/personnel-headshots/${path}`,{headers:{apikey:SUPABASE_KEY,Authorization:`Bearer ${token}`},signal:abort.signal});
          if(!response.ok)throw Error('Headshot unavailable');
          objectUrl=URL.createObjectURL(await response.blob());
          if(active)setPrivateUrl(objectUrl);else URL.revokeObjectURL(objectUrl);
        } catch(error) {if(active && !abort.signal.aborted)setFailed(true);}
      })();
    }
    return ()=>{active=false;abort.abort();if(objectUrl)URL.revokeObjectURL(objectUrl);};
  },[person.id,person.intake_headshot,person.updated_at,person.headshot_kind,person.headshot_path]);
  const demoSrc=person.headshot_kind==='demo'&&person.headshot_path?`/headshots/${person.headshot_path}`:'';
  return <div className={`person-headshot${large?' large':''}`}>
    {demoSrc && !failed ? <Image src={demoSrc} alt={`${person.display_name} portrait`} width={400} height={500} sizes={large?'(max-width: 760px) 180px, 270px':'(max-width: 480px) 45vw, 200px'} onError={()=>setFailed(true)}/> : privateUrl && !failed ?
      // Authenticated object URLs are downloaded with the owner's session above.
      // eslint-disable-next-line @next/next/no-img-element
      <img src={privateUrl} alt={`${person.display_name} headshot`} loading="lazy"/> : person.profile_avatar?<div className="bird-profile-avatar"><BirdAvatar name={person.profile_avatar}/></div>:<div className="headshot-placeholder"><Users size={44}/><strong>{initials(person.display_name)}</strong><span>{person.headshot_kind==='uploaded'&&!failed?'Loading headshot…':'Headshot needed'}</span></div>}
  </div>;
}
function ProfileEditor({person,onClose,onSave}: {person:Person;onClose:()=>void;onSave:Props['onSave']}) {
  const [draft,setDraft]=useState<PersonDraft>({display_name:person.display_name,first_name:person.first_name,last_name:person.last_name,known_as:person.known_as,person_types:person.person_types,job_title:person.job_title,departments:person.departments,area:person.area,hometown:person.hometown,bio:person.bio,favorite_shakespeare:person.favorite_shakespeare,unions:person.unions,intern:person.intern});
  const [departments,setDepartments]=useState(person.departments.join(', ')),[unions,setUnions]=useState(person.unions.join(', ')),[saving,setSaving]=useState(false),[error,setError]=useState('');
  async function save(e:React.FormEvent){e.preventDefault();if(saving)return;setSaving(true);setError('');try{if(!draft.display_name.trim())throw Error('Enter a display name.');if(!draft.person_types.length)throw Error('Choose at least one personnel type.');await onSave(person,{...draft,display_name:draft.display_name.trim(),departments:splitLabels(departments),unions:splitLabels(unions)});onClose();}catch(error){setError((error as Error).message);}finally{setSaving(false);}}
  return <div className="modal-shade"><section className="modal person-editor" role="dialog" aria-modal="true" aria-labelledby="person-editor-title"><button className="modal-close" aria-label="Close profile editor" disabled={saving} onClick={onClose}><X/></button><div className="eyebrow">PERSONNEL</div><h2 id="person-editor-title">Edit profile</h2>{person.is_demo&&<p className="form-help">This is a fictional test profile. Its show credits and biographical details are sample data.</p>}<form onSubmit={save}>
    <label>Display name<input required maxLength={200} value={draft.display_name} onChange={e=>setDraft({...draft,display_name:e.target.value})}/></label>
    <div className="person-form-pair"><label>First name<input value={draft.first_name} onChange={e=>setDraft({...draft,first_name:e.target.value})}/></label><label>Last name<input value={draft.last_name} onChange={e=>setDraft({...draft,last_name:e.target.value})}/></label></div>
    <label>Known as<input value={draft.known_as} onChange={e=>setDraft({...draft,known_as:e.target.value})}/></label>
    <fieldset><legend>Personnel types</legend>{personTypes.map(type=><label className="check-label" key={type}><input type="checkbox" checked={draft.person_types.includes(type)} onChange={e=>setDraft({...draft,person_types:e.target.checked?[...draft.person_types,type]:draft.person_types.filter(value=>value!==type)})}/>{type}</label>)}</fieldset>
    <label>Job title<input value={draft.job_title} onChange={e=>setDraft({...draft,job_title:e.target.value})}/></label>
    <label>Departments<input placeholder="e.g. Production, Marketing" value={departments} onChange={e=>setDepartments(e.target.value)}/></label><p className="form-help">Separate multiple departments with commas. Directory labels do not change login access.</p>
    <label>Area<input value={draft.area} onChange={e=>setDraft({...draft,area:e.target.value})}/></label>
    <label>Hometown<input value={draft.hometown} onChange={e=>setDraft({...draft,hometown:e.target.value})}/></label>
    <label>Biography<textarea rows={6} value={draft.bio} onChange={e=>setDraft({...draft,bio:e.target.value})}/></label>
    <label>Favorite Shakespeare work<input value={draft.favorite_shakespeare} onChange={e=>setDraft({...draft,favorite_shakespeare:e.target.value})}/></label>
    <label>Unions<input value={unions} onChange={e=>setUnions(e.target.value)}/></label>
    <label className="check-label"><input type="checkbox" checked={draft.intern} onChange={e=>setDraft({...draft,intern:e.target.checked})}/>Intern</label>
    {error&&<div className="error" role="alert">{error}</div>}<div className="modal-actions"><button type="button" className="secondary" disabled={saving} onClick={onClose}>Cancel</button><button className="primary" disabled={saving}>{saving?'Saving…':'Save profile'}<Check size={16}/></button></div>
  </form></section></div>;
}
export default function PersonnelDirectory({seasonMemberships=[],canManageContacts=false,loadContact,saveContact,onDirty,people,credits,productions,productionFilter,onProductionFilterChange,getToken,onSave,onUpload,onOpenProduction,currentSeason='',defaultView='tiles',canEdit=true}:Props) {
  const [query,setQuery]=useState(''),[type,setType]=useState(''),[department,setDepartment]=useState(''),[selectedId,setSelectedId]=useState<string|null>(null),[editing,setEditing]=useState(false),[uploading,setUploading]=useState(false),[error,setError]=useState('');
  const [contactDirty,setContactDirty]=useState(false),[contactVersion,setContactVersion]=useState(0);
  useEffect(()=>{onDirty?.(contactDirty);return()=>onDirty?.(false);},[contactDirty,onDirty]);
  function leaveContact(){if(!contactDirty)return true;if(!window.confirm('Discard unsaved contact information?'))return false;setContactDirty(false);setContactVersion(v=>v+1);return true;}
  const [season,setSeason]=useState(currentSeason);
  useEffect(()=>setSeason(currentSeason),[currentSeason]);
  const [view,setView]=useState<'tiles'|'list'>(defaultView);
  useEffect(()=>setView(defaultView),[defaultView]);
  function changeView(next:'tiles'|'list'){setView(next);try{localStorage.setItem('loon.personnelView',next);}catch{}}
  useEffect(()=>{window.scrollTo(0,0);},[selectedId]);
  const uploadInput=useRef<HTMLInputElement>(null);
  const selected=people.find(person=>person.id===selectedId);
  const departments=[...new Set(people.flatMap(person=>person.departments))].sort();
  const seasonProductions=productions.filter(p=>!season||p.season_id===season);
  const seasonCredits=credits.filter(c=>seasonProductions.some(p=>p.id===c.production_id));
  const seasonPeople=peopleInSeason(people,seasonCredits,season,seasonMemberships);
  const filtered=filterPeople(seasonPeople,seasonCredits,{query,type,production:productionFilter,department});
  const selectedCredits=credits.filter(credit=>credit.person_id===selectedId).sort((a,b)=>a.billing_order-b.billing_order);
  async function upload(file:File){if(!selected||uploading)return;setUploading(true);setError('');try{await onUpload(selected,file);}catch(error){setError((error as Error).message);}finally{setUploading(false);if(uploadInput.current)uploadInput.current.value='';}}
  const testNotice=<div className="personnel-test-note"><strong>Fictional test personnel.</strong> Names and photos identify public figures; these production credits, locations, union values, and biographies are sample data, not claims about those people.</div>;
  if(selected)return <section className="personnel-directory"><button className="back" onClick={()=>{if(leaveContact()){setSelectedId(null);setError('');}}}><ArrowLeft size={15}/>Back to personnel</button><div className="person-profile-heading"><div><div className="eyebrow">{selected.person_types.join(' / ')}</div><h1>{personName(selected)}</h1>{selected.known_as&&selected.known_as!==selected.display_name&&<p>{selected.display_name}</p>}<div className="person-tags">{selected.is_demo&&<span className="pill demo-pill">FICTIONAL TEST PROFILE</span>}{selected.intern&&<span className="pill">Intern · test value</span>}</div></div><button className="secondary" disabled={!canEdit} onClick={()=>setEditing(true)}><Pencil size={15}/>Edit profile</button></div>{selected.is_demo&&testNotice}
    <div className="person-profile-grid"><aside className="person-photo-panel"><Headshot person={selected} getToken={getToken} large/><p className="portrait-caption">{portraitName(selected)} | {selected.job_title||selected.person_types.join(' / ')}</p><input ref={uploadInput} type="file" accept="image/jpeg,image/png,image/webp" aria-label={`Upload headshot for ${selected.display_name}`} className="sr-only" onChange={e=>{const file=e.target.files?.[0];if(file)void upload(file);}}/><button className="primary" disabled={uploading||!canEdit} onClick={()=>uploadInput.current?.click()}>{uploading?<LoaderCircle size={16} className="spin"/>:<Camera size={16}/>} {uploading?'Uploading…':selected.headshot_path?'Replace headshot':'Upload headshot'}</button><p className="form-help">JPG, PNG, or WebP · Up to 4 MB. Uploaded photos are private to Loon.</p>{selected.headshot_kind==='demo'&&selected.headshot_source_url&&<div className="photo-credit"><a href={selected.headshot_source_url} target="_blank" rel="noreferrer">Photo source</a><p>{selected.headshot_credit}</p>{selected.headshot_license_url?<a href={selected.headshot_license_url} target="_blank" rel="noreferrer">{selected.headshot_license}</a>:<span>{selected.headshot_license}</span>}</div>}{selected.headshot_kind==='uploaded'&&<p className="photo-credit">Private uploaded headshot</p>}{error&&<div className="error" role="alert">{error}</div>}</aside>
    <div className="person-profile-body"><section className="person-profile-section"><h2>About {personName(selected)}</h2><p className="person-bio">{selected.bio||'No biography added yet.'}</p><dl className="person-facts"><div><dt>Job title</dt><dd>{selected.job_title||'Not set'}</dd></div><div><dt>Departments</dt><dd>{selected.departments.join(' · ')||'Not assigned'}</dd></div><div><dt>Area</dt><dd>{selected.area.replaceAll('_',' ')||'Not set'}</dd></div><div><dt>Hometown {selected.is_demo&&<small>(test value)</small>}</dt><dd>{selected.hometown||'Not set'}</dd></div><div><dt>Unions {selected.is_demo&&<small>(test value)</small>}</dt><dd>{selected.unions.join(' · ')||'Not set'}</dd></div><div><dt>Favorite Shakespeare</dt><dd>{selected.favorite_shakespeare||'Not set'}</dd></div></dl></section>
    {canManageContacts&&<PersonnelContactDetails key={selected.id+':'+contactVersion} personId={selected.id} readOnly={!canEdit} loadContact={loadContact} saveContact={saveContact} onDirty={setContactDirty}/>}
    <section className="person-profile-section"><h2>Production credits <span className="muted">{selectedCredits.length}</span></h2><div className="person-credit-list">{selectedCredits.map(credit=><button key={credit.id} onClick={()=>{if(leaveContact())onOpenProduction(credit.production_id);}}><div><strong>{productions.find(p=>p.id===credit.production_id)?.title||'Production'}</strong><span>{credit.role} · {credit.credit_type}</span></div><ArrowUpRight size={18}/></button>)}{selectedCredits.length===0&&<p>No production credits yet.</p>}</div></section></div></div>
    {editing&&<ProfileEditor person={selected} onSave={onSave} onClose={()=>setEditing(false)}/>}
  </section>;
  return <section className="personnel-directory"><div className="page-heading"><div><div className="eyebrow">ORLANDO SHAKES / PEOPLE</div><h1>Personnel</h1><p>Cast and creatives, with their production credits.</p></div><span className="pill">{people.length} people</span></div>{people.some(person=>person.is_demo)&&testNotice}
    <div className="personnel-controls"><label>Season<select value={season} onChange={e=>{setSeason(e.target.value);onProductionFilterChange('');}}><option value="">All seasons</option>{[...new Map(productions.map(p=>[p.season_id,p.seasons?.name||'Season'])).entries()].map(([id,name])=><option key={id} value={id}>{name}</option>)}</select></label><label>Personnel type<select value={type} onChange={e=>setType(e.target.value)}><option value="">All people</option>{personTypes.map(value=><option key={value}>{value}</option>)}</select></label><label>Production<select value={productionFilter} onChange={e=>onProductionFilterChange(e.target.value)}><option value="">All productions</option>{seasonProductions.map(p=><option value={p.id} key={p.id}>{p.title}</option>)}</select></label><label>Department<select value={department} onChange={e=>setDepartment(e.target.value)}><option value="">All departments</option>{departments.map(value=><option key={value}>{value}</option>)}</select></label><label className="search"><Search size={16}/><input aria-label="Find personnel" placeholder="Name, role, or department…" value={query} onChange={e=>setQuery(e.target.value)}/></label></div>
    <div className="section-title personnel-results"><h2>{filtered.length} {filtered.length===1?'person':'people'}</h2>{(query||type||productionFilter||department)&&<button className="text-button" onClick={()=>{setQuery('');setType('');setDepartment('');onProductionFilterChange('');}}>Clear filters</button>}<div className="personnel-view-switch" role="group" aria-label="Personnel view"><button aria-pressed={view==='tiles'} onClick={()=>changeView('tiles')}><LayoutGrid size={15}/>Tiles</button><button aria-pressed={view==='list'} onClick={()=>changeView('list')}><List size={15}/>List</button></div></div>
    <div className={`person-grid personnel-${view}`}>{filtered.map(person=>{const assignments=credits.filter(credit=>credit.person_id===person.id&&(!productionFilter||credit.production_id===productionFilter)).sort((a,b)=>a.billing_order-b.billing_order);return <button className="person-card" key={person.id} onClick={()=>{setSelectedId(person.id);setError('');}}><div className="person-portrait"><Headshot person={person} getToken={getToken}/><h3>{portraitName(person)}</h3><p className="person-card-role">{assignments.map(credit=>credit.role).join(' · ')||person.job_title||'No role assigned'}</p></div><div className="person-card-body"><div className="person-card-types">{person.person_types.join(' / ')}{person.is_demo&&<span>TEST PROFILE</span>}</div><div className="person-card-productions">{[...new Set(assignments.map(credit=>credit.production_id))].map(id=><span key={id}>{productions.find(p=>p.id===id)?.title}</span>)}</div></div></button>;})}</div>
    {filtered.length===0&&<div className="empty"><Users/><h2>No people match these filters.</h2><p>Try another name, production, or department.</p></div>}
  </section>;
}
