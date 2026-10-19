import type {Metadata} from 'next';
import './globals.css';
export const metadata:Metadata={title:'Loon — Production Workspace',description:'One shared home for your productions and performances.'};
export default function Layout({children}:{children:React.ReactNode}){return <html lang="en"><body>{children}</body></html>}
