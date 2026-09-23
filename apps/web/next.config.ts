import type { NextConfig } from "next";
const config: NextConfig = { devIndicators: false, transpilePackages:["@now/types","@now/api-client","@now/ui"], async rewrites(){ return [{ source:"/v1/:path*", destination:`${process.env.API_INTERNAL_URL || "http://127.0.0.1:4000"}/v1/:path*` }]; }, async headers(){return [{source:"/:path*",headers:[{key:"X-Content-Type-Options",value:"nosniff"},{key:"Referrer-Policy",value:"no-referrer"},{key:"X-Frame-Options",value:"DENY"},{key:"Permissions-Policy",value:"camera=(), microphone=(), geolocation=(self)"}]}];}};
export default config;
