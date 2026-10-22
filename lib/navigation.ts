export type NavigationItem={id:string;label:string;destination?:string;icon?:'home'|'calendar'|'production'|'venues'|'people'|'callboard'|'company'|'stage'|'labor';comingSoon?:boolean;children?:NavigationItem[]};
type Access={productions:boolean;calendar:boolean;venues:boolean;personnel:boolean;stage:boolean;stageReports:boolean;castScheduling:boolean;company:boolean;labor:boolean};
export function workspaceNavigation(access:Access):NavigationItem[]{
 const soon=(id:string,label:string):NavigationItem=>({id,label,comingSoon:true});
 return [
  ...(access.productions?[{id:'home',label:'Theater Home',destination:'Productions',icon:'home'} as NavigationItem]:[]),
  ...(access.calendar?[{id:'calendar',label:'Master Calendar',destination:'Schedule',icon:'calendar'} as NavigationItem]:[]),
  ...(access.productions||access.labor?[{id:'production',label:'Production',icon:'production',children:[
   ...(access.labor?[{id:'labor',label:'Labor Dashboard',destination:'Clocking',icon:'labor',children:[{id:'tasks',label:'Task Tracker',destination:'Task Tracking'},{id:'planning',label:'Labor Planning',destination:'Labor Planning'}]} as NavigationItem]:[]),
   ...(access.productions?[soon('costuming','Costuming'),{id:'design',label:'Design Hub',comingSoon:true,children:[soon('design-meeting','Design Meeting')]}]:[])
  ]} as NavigationItem]:[]),
  ...(access.venues?[{id:'venues',label:'Venues',destination:'Venues',icon:'venues',children:[soon('venue-calendar','Venue Calendar'),soon('venue-media','Venue Media Library')]} as NavigationItem]:[]),
  ...(access.personnel?[{id:'personnel',label:'Personnel',destination:'Personnel',icon:'people'} as NavigationItem]:[]),
  ...(access.stage?[{id:'callboard',label:'Callboard',destination:'Callboard',icon:'callboard',children:[soon('actor-check-in','Actor Check In')]} as NavigationItem]:[]),
  ...(access.company?[{id:'company',label:'Company Management',destination:'CompanyManagement',icon:'company',children:[{id:'invite',label:'Personnel Invite Link',destination:'CompanyInvites'},{id:'approvals',label:'Personnel Approvals',destination:'CompanyApprovals'},soon('auditions','Auditions Hub')]} as NavigationItem]:[]),
  ...(access.stageReports?[{id:'stage',label:'Stage Management',icon:'stage',children:[
   ...(access.castScheduling?[{id:'cast-scheduling',label:'Cast Scheduling',destination:'StageSchedule'}]:[]),soon('cast-check-in','Cast Check In'),
   {id:'show-reports',label:'Show Reports',children:[{id:'rehearsal-reports',label:'Rehearsal Reports',destination:'RehearsalReports'},{id:'performance-reports',label:'Performance Reports',destination:'PerformanceReports'}]}
  ]} as NavigationItem]:[])
 ];
}
export function navigationContains(item:NavigationItem,destination:string):boolean{return item.destination===destination||Boolean(item.children?.some(child=>navigationContains(child,destination)));}
