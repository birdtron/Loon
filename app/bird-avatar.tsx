import Image from 'next/image';
import {avatarOptions} from '../lib/intake';
export default function BirdAvatar({name='bird-00',decorative=false}:{name?:string;decorative?:boolean}){const avatar=avatarOptions.find(a=>a.id===name)||avatarOptions[0];return <Image className="bird-avatar-image" src={`/profile-icons/${avatar.id}.png`} alt={decorative?'':`${avatar.label} profile image`} width={1080} height={1080} sizes="(max-width:700px) 88px, 160px"/>;}
