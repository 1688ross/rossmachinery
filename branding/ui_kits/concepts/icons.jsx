// Lucide-style icons (stroke 2, 24x24) — matches the icon system used in the
// Ross Machinery codebase (lucide-react). Exported to window for the UI kit.
const React = window.React;

function Icon({ children, size = 24, stroke = 2, style, ...rest }) {
  return (
    <svg width={size} height={size} viewBox="0 0 24 24" fill="none"
      stroke="currentColor" strokeWidth={stroke} strokeLinecap="round"
      strokeLinejoin="round" style={style} {...rest}>
      {children}
    </svg>
  );
}

const ArrowRight = (p) => <Icon {...p}><path d="M5 12h14"/><path d="m13 6 6 6-6 6"/></Icon>;
const Phone = (p) => <Icon {...p}><path d="M22 16.92v3a2 2 0 0 1-2.18 2 19.79 19.79 0 0 1-8.63-3.07 19.5 19.5 0 0 1-6-6 19.79 19.79 0 0 1-3.07-8.67A2 2 0 0 1 4.11 2h3a2 2 0 0 1 2 1.72c.13.96.36 1.9.7 2.81a2 2 0 0 1-.45 2.11L8.09 9.91a16 16 0 0 0 6 6l1.27-1.27a2 2 0 0 1 2.11-.45c.91.34 1.85.57 2.81.7A2 2 0 0 1 22 16.92z"/></Icon>;
const Mail = (p) => <Icon {...p}><rect width="20" height="16" x="2" y="4" rx="2"/><path d="m22 7-8.97 5.7a1.94 1.94 0 0 1-2.06 0L2 7"/></Icon>;
const Cog = (p) => <Icon {...p}><path d="M12 20a8 8 0 1 0 0-16 8 8 0 0 0 0 16Z"/><path d="M12 14a2 2 0 1 0 0-4 2 2 0 0 0 0 4Z"/><path d="M12 2v2"/><path d="M12 22v-2"/><path d="m17 20.66-1-1.73"/><path d="M11 10.27 7 3.34"/><path d="m20.66 17-1.73-1"/><path d="m3.34 7 1.73 1"/><path d="M14 12h8"/><path d="M2 12h2"/><path d="m20.66 7-1.73 1"/><path d="m3.34 17 1.73-1"/><path d="m17 3.34-1 1.73"/><path d="m11 13.73-4 6.93"/></Icon>;
const Wrench = (p) => <Icon {...p}><path d="M14.7 6.3a1 1 0 0 0 0 1.4l1.6 1.6a1 1 0 0 0 1.4 0l3.77-3.77a6 6 0 0 1-7.94 7.94l-6.91 6.91a2.12 2.12 0 0 1-3-3l6.91-6.91a6 6 0 0 1 7.94-7.94l-3.76 3.76z"/></Icon>;
const Shield = (p) => <Icon {...p}><path d="M20 13c0 5-3.5 7.5-7.66 8.95a1 1 0 0 1-.67-.01C7.5 20.5 4 18 4 13V6a1 1 0 0 1 1-1c2 0 4.5-1.2 6.24-2.72a1.17 1.17 0 0 1 1.52 0C14.51 3.81 17 5 19 5a1 1 0 0 1 1 1z"/></Icon>;
const Users = (p) => <Icon {...p}><path d="M16 21v-2a4 4 0 0 0-4-4H6a4 4 0 0 0-4 4v2"/><circle cx="9" cy="7" r="4"/><path d="M22 21v-2a4 4 0 0 0-3-3.87"/><path d="M16 3.13a4 4 0 0 1 0 7.75"/></Icon>;
const CheckCircle = (p) => <Icon {...p}><path d="M21.801 10A10 10 0 1 1 17 3.335"/><path d="m9 11 3 3L22 4"/></Icon>;
const Quote = (p) => <Icon {...p}><path d="M16 3a2 2 0 0 0-2 2v6a2 2 0 0 0 2 2h2.5l.5 2 .5-2H21a2 2 0 0 0 2-2V5a2 2 0 0 0-2-2z"/><path d="M3 3a2 2 0 0 0-2 2v6a2 2 0 0 0 2 2h2.5l.5 2 .5-2H8a2 2 0 0 0 2-2V5a2 2 0 0 0-2-2z"/></Icon>;
const MapPin = (p) => <Icon {...p}><path d="M20 10c0 4.993-5.539 10.193-7.399 11.799a1 1 0 0 1-1.202 0C9.539 20.193 4 14.993 4 10a8 8 0 0 1 16 0"/><circle cx="12" cy="10" r="3"/></Icon>;
const X = (p) => <Icon {...p}><path d="M18 6 6 18"/><path d="m6 6 12 12"/></Icon>;
const Menu = (p) => <Icon {...p}><line x1="4" x2="20" y1="6" y2="6"/><line x1="4" x2="20" y1="12" y2="12"/><line x1="4" x2="20" y1="18" y2="18"/></Icon>;
const Globe = (p) => <Icon {...p}><circle cx="12" cy="12" r="10"/><path d="M12 2a14.5 14.5 0 0 0 0 20 14.5 14.5 0 0 0 0-20"/><path d="M2 12h20"/></Icon>;
const Gauge = (p) => <Icon {...p}><path d="m12 14 4-4"/><path d="M3.34 19a10 10 0 1 1 17.32 0"/></Icon>;

Object.assign(window, {
  RmsIcons: { ArrowRight, Phone, Mail, Cog, Wrench, Shield, Users, CheckCircle, Quote, MapPin, X, Menu, Globe, Gauge },
});
