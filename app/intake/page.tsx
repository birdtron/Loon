import type {Metadata} from 'next';
import PublicIntake from './intake-form';
export const metadata:Metadata={title:'Personnel Intake Form — Loon',robots:{index:false,follow:false},referrer:'no-referrer'};
export default function IntakePage(){return <PublicIntake/>;}
