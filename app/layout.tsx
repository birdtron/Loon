import type {Metadata} from 'next';
import './globals.css';
export const metadata:Metadata={title:'Loon — Production Workspace',description:'Manage theater productions, schedules, venues, and personnel.'};
export default function Layout({children}:{children:React.ReactNode}){return <html lang="en"><body>{children}</body></html>}
