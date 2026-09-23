import type {Metadata} from 'next';
import './styles.css';
export const metadata:Metadata={title:'NOW · Un rato libre. Un mundo de posibilidades.',description:'Di qué te apetece. NOW encuentra el grupo. Tu radar privado de disponibilidad social. Para mayores de 18 años.'};
export default function Layout({children}:{children:React.ReactNode}){return <html lang="es"><body>{children}</body></html>;}
