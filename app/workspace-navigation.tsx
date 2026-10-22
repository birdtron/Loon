'use client';
import {useId,useState} from 'react';
import {Home,CalendarDays,Theater,MapPin,Users,ClipboardList,Clock,ChevronRight,Menu,X} from 'lucide-react';
import {navigationContains} from '../lib/navigation';
import type {NavigationItem} from '../lib/navigation';
const icons={home:Home,calendar:CalendarDays,production:Theater,venues:MapPin,people:Users,callboard:ClipboardList,company:Users,stage:Theater,labor:Clock};
export default function WorkspaceNavigation({items,active,onNavigate}:{items:NavigationItem[];active:string;onNavigate:(destination:string)=>boolean}){
 const [mobileOpen,setMobileOpen]=useState(false);const id=useId();
 function navigate(destination:string){if(onNavigate(destination))setMobileOpen(false);}
 return <nav className="workspace-nav" aria-label="Workspace" data-expanded={mobileOpen}><button type="button" className="workspace-menu-toggle" aria-expanded={mobileOpen} aria-controls={id} onClick={()=>setMobileOpen(v=>!v)}>{mobileOpen?<X size={18}/>:<Menu size={18}/>}Workspace menu<ChevronRight size={16}/></button><div id={id} className="workspace-nav-items">{items.map(item=><NavigationNode key={item.id} item={item} active={active} onNavigate={navigate}/>)}</div></nav>;
}
function NavigationNode({item,active,onNavigate}:{item:NavigationItem;active:string;onNavigate:(destination:string)=>void}){
 const [expanded,setExpanded]=useState(true);const childrenId=useId();const Icon=item.icon?icons[item.icon]:undefined;const selected=item.destination===active;const branchActive=navigationContains(item,active);const label=<>{Icon&&<Icon size={18}/>}<span className="workspace-nav-label">{item.label}</span>{item.comingSoon&&<small className="workspace-nav-soon">Coming soon</small>}</>;
 return <div className="workspace-nav-node" data-branch-active={branchActive}>
 <div className="workspace-nav-row">{item.destination?<button type="button" className={selected?'active':''} aria-current={selected?'page':undefined} title={item.destination==='Clocking'?'Clock in and out':undefined} onClick={()=>onNavigate(item.destination!)}>{label}</button>:item.children?<button type="button" aria-expanded={expanded} aria-controls={childrenId} onClick={()=>setExpanded(v=>!v)}>{label}<ChevronRight className="workspace-nav-chevron" size={14} data-expanded={expanded}/></button>:<button type="button" className="workspace-nav-future" disabled title="Coming soon">{label}</button>}
 {item.children&&item.destination&&<button type="button" className="workspace-nav-disclosure" aria-label={`${expanded?'Collapse':'Expand'} ${item.label}`} aria-expanded={expanded} aria-controls={childrenId} onClick={()=>setExpanded(v=>!v)}><ChevronRight size={14} data-expanded={expanded}/></button>}</div>
 {item.children&&<div className="workspace-nav-children" id={childrenId} hidden={!expanded}>{item.children.map(child=><NavigationNode key={child.id} item={child} active={active} onNavigate={onNavigate}/>)}</div>}
 </div>;
}
