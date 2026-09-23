import type {Metadata} from 'next';
import '../../web/app/styles.css';
import './admin.css';
export const metadata:Metadata={title:'NOW · Operaciones',robots:{index:false,follow:false}};
export default function Layout({children}:{children:React.ReactNode}){return <html lang="es"><body>{children}</body></html>;}
