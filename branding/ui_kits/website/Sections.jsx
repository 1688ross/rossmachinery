// Ross Machinery — marketing website sections.
// Composes design-system primitives from the bundle + RmsIcons.
const React = window.React;
const { useState } = React;
const DS = window.RossMachineryDesignSystem_610e0e;
const { Button, Badge, Card, Eyebrow, SpecList, Input } = DS;
const I = window.RmsIcons;

const A = '../../assets';
const MAXW = 'var(--container-max)';

const wrap = { maxWidth: MAXW, margin: '0 auto', padding: '0 var(--container-pad)' };

/* ---------------- Header ---------------- */
function Header({ onQuote, active = 'Home' }) {
  const nav = ['Machines', 'Services', 'About', 'Contact'];
  return (
    <header style={{ position: 'sticky', top: 0, zIndex: 50 }}>
      <div style={{ background: 'var(--rms-navy)', color: '#fff' }}>
        <div style={{ ...wrap, display: 'flex', justifyContent: 'space-between', alignItems: 'center', height: 38, fontSize: 13 }}>
          <div style={{ display: 'flex', gap: 24, alignItems: 'center' }}>
            <span style={{ display: 'flex', alignItems: 'center', gap: 7 }}><I.Phone size={14}/> +1.203.269.2950</span>
            <span style={{ display: 'flex', alignItems: 'center', gap: 7 }}><I.Mail size={14}/> office@rossmachinery.com</span>
          </div>
          <span style={{ color: 'var(--rms-yellow)', fontWeight: 600, letterSpacing: '0.04em', textTransform: 'uppercase', fontSize: 12 }}>
            Serving Aerospace &amp; Advanced Manufacturing
          </span>
        </div>
      </div>
      <div style={{ background: '#fff', borderBottom: '1px solid var(--border-subtle)', boxShadow: 'var(--shadow-xs)' }}>
        <div style={{ ...wrap, display: 'flex', justifyContent: 'space-between', alignItems: 'center', height: 76 }}>
          <img src={`${A}/logos/rms-logo-color.png`} alt="Ross Machinery" style={{ height: 44 }} />
          <nav style={{ display: 'flex', gap: 34, alignItems: 'center' }}>
            {['Home', ...nav].map((n) => (
              <a key={n} href="#" onClick={(e) => e.preventDefault()} style={{
                fontWeight: 600, fontSize: 15, textDecoration: 'none',
                color: n === active ? 'var(--rms-navy)' : 'var(--text-body)',
                borderBottom: n === active ? '3px solid var(--rms-yellow)' : '3px solid transparent',
                paddingBottom: 4,
              }}>{n}</a>
            ))}
          </nav>
          <Button variant="accent" onClick={onQuote}>Request Consultation</Button>
        </div>
      </div>
    </header>
  );
}

/* ---------------- Hero ---------------- */
function Hero({ onQuote }) {
  return (
    <section style={{ position: 'relative', background: 'var(--rms-navy-900)', color: '#fff', overflow: 'hidden' }}>
      <img src={`${A}/images/world-map.png`} alt="" style={{ position: 'absolute', inset: 0, width: '100%', height: '100%', objectFit: 'cover', opacity: 0.08 }} />
      <div style={{ ...wrap, position: 'relative', display: 'grid', gridTemplateColumns: '1.05fr 0.95fr', gap: 'var(--space-8)', alignItems: 'center', padding: '84px var(--container-pad)' }}>
        <div>
          <Eyebrow color="var(--rms-yellow)">Aerospace &amp; Advanced Manufacturing</Eyebrow>
          <h1 style={{ font: 'var(--type-display-lg)', lineHeight: 1.04, fontStyle: 'italic', textTransform: 'uppercase', letterSpacing: '-0.01em', margin: '18px 0 0' }}>
            Your Partner in<br/><span style={{ color: 'var(--rms-yellow)' }}>Advanced</span> Manufacturing
          </h1>
          <p style={{ font: 'var(--type-body-lg)', color: 'var(--steel-300)', maxWidth: 520, margin: '22px 0 32px' }}>
            World-class industrial equipment and comprehensive support services for leading aerospace and advanced manufacturing companies.
          </p>
          <div style={{ display: 'flex', gap: 14 }}>
            <Button variant="accent" size="lg" iconRight={<I.ArrowRight size={18}/>} onClick={onQuote}>Explore Our Machines</Button>
            <Button variant="outline" size="lg" iconLeft={<I.Phone size={18}/>}
              style={{ color: '#fff', borderColor: 'rgba(255,255,255,0.4)', background: 'rgba(255,255,255,0.06)' }}>Get In Touch</Button>
          </div>
        </div>
        <div style={{ position: 'relative' }}>
          <div style={{ position: 'absolute', top: 18, left: 18, width: '100%', height: '100%', border: '3px solid var(--rms-yellow)', borderRadius: 'var(--radius-md)' }} />
          <img src={`${A}/images/hero-machining.webp`} alt="CNC machining" style={{ position: 'relative', width: '100%', height: 380, objectFit: 'cover', borderRadius: 'var(--radius-md)', boxShadow: 'var(--shadow-lg)' }} />
        </div>
      </div>
    </section>
  );
}

/* ---------------- Trust bar ---------------- */
function TrustBar() {
  return (
    <section style={{ background: '#fff', borderBottom: '1px solid var(--border-subtle)' }}>
      <div style={{ ...wrap, padding: '34px var(--container-pad)', display: 'flex', alignItems: 'center', gap: 48, flexWrap: 'wrap', justifyContent: 'center' }}>
        <span style={{ font: 'var(--type-eyebrow)', textTransform: 'uppercase', letterSpacing: '0.14em', color: 'var(--text-muted)' }}>Trusted by industry leaders</span>
        <img src={`${A}/vendors/sikorsky.png`} alt="Sikorsky" style={{ height: 30, objectFit: 'contain', filter: 'grayscale(1)', opacity: 0.7 }} />
        {['Collins Aerospace', 'Precision Mfg Corp', 'Aerospace Solutions'].map((c) => (
          <span key={c} style={{ font: 'var(--type-body)', fontWeight: 600, color: 'var(--steel-400)' }}>{c}</span>
        ))}
      </div>
    </section>
  );
}

/* ---------------- Stats ---------------- */
function Stats() {
  const data = [
    { n: '30+', l: 'Years of industrial expertise' },
    { n: '4', l: 'World-class manufacturing partners' },
    { n: '5-Axis', l: 'Precision machining specialists' },
    { n: '24/7', l: 'Service & technical support' },
  ];
  return (
    <section style={{ background: 'var(--rms-navy)', color: '#fff' }}>
      <div style={{ ...wrap, display: 'grid', gridTemplateColumns: 'repeat(4,1fr)', padding: '46px var(--container-pad)' }}>
        {data.map((d, i) => (
          <div key={i} style={{ textAlign: 'center', padding: '0 16px', borderLeft: i ? '1px solid rgba(255,255,255,0.14)' : 'none' }}>
            <div style={{ font: 'var(--type-display-sm)', color: 'var(--rms-yellow)', fontStyle: 'italic' }}>{d.n}</div>
            <div style={{ font: 'var(--type-body-sm)', color: 'var(--steel-300)', marginTop: 6 }}>{d.l}</div>
          </div>
        ))}
      </div>
    </section>
  );
}

/* ---------------- Machines / Partners ---------------- */
const VENDORS = [
  { name: 'Fives Giddings & Lewis', logo: 'fives-giddings-lewis.png', tag: 'Horizontal Boring Mills',
    desc: 'Wisconsin-built heavy-duty horizontal boring mills, machining centers and vertical turning centers with endless custom configurations.',
    specs: [{label:'Type', value:'HBM / VTC'},{label:'Origin', value:'USA'}] },
  { name: 'Mitsui Seiki', logo: 'mitsui-seiki.webp', tag: '4 & 5 Axis Precision',
    desc: 'High-precision 4 & 5 axis horizontal and vertical machining centers, jig bores and jig grinders. 5-year accuracy guarantee on every machine.',
    specs: [{label:'Accuracy', value:'±0.003 mm'},{label:'Origin', value:'Japan'}] },
  { name: 'Breton', logo: 'breton.jpg', tag: 'Gantry Machine Tools',
    desc: 'Highly productive gantry-style machine tools for composites through hard-to-machine aerospace alloys, including large-format additive.',
    specs: [{label:'Type', value:'5-Axis Gantry'},{label:'Origin', value:'Italy'}] },
  { name: 'Index', logo: 'index.png', tag: '5 Axis Turn-Mills',
    desc: 'High-production turning machines, multi-spindle lathes and 5-axis turn-mill centers combining multiple operations into one platform.',
    specs: [{label:'Type', value:'Turn-Mill'},{label:'Origin', value:'Germany'}] },
];

function Machines({ onQuote }) {
  const [open, setOpen] = useState(null);
  return (
    <section style={{ background: 'var(--steel-50)' }}>
      <div style={{ ...wrap, padding: '76px var(--container-pad)' }}>
        <div style={{ textAlign: 'center', maxWidth: 720, margin: '0 auto 48px' }}>
          <div style={{ display: 'flex', justifyContent: 'center' }}><Eyebrow>World-Class Partners</Eyebrow></div>
          <h2 style={{ font: 'var(--type-display-md)', color: 'var(--rms-navy)', margin: '14px 0 12px' }}>Manufacturing Partners</h2>
          <p style={{ font: 'var(--type-body-lg)', color: 'var(--text-body)', margin: 0 }}>
            We represent the finest machine-tool builders from Germany, Italy, Japan and the USA — bringing cutting-edge technology to aerospace and advanced manufacturing.
          </p>
        </div>
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(2,1fr)', gap: 24 }}>
          {VENDORS.map((v) => (
            <Card key={v.name} accentEdge interactive padding="0">
              <div style={{ display: 'flex', flexDirection: 'column', height: '100%' }}>
                <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', gap: 16, padding: 'var(--space-5) var(--space-5) var(--space-4)' }}>
                  <div style={{ height: 48, display: 'flex', alignItems: 'center' }}>
                    <img src={`${A}/vendors/${v.logo}`} alt={v.name} style={{ maxHeight: 48, maxWidth: 170, objectFit: 'contain' }} />
                  </div>
                  <Badge tone="yellow" variant="soft">{v.tag}</Badge>
                </div>
                <div style={{ padding: '0 var(--space-5) var(--space-5)', flex: 1 }}>
                  <h3 style={{ font: 'var(--type-h2)', color: 'var(--rms-navy)', margin: '0 0 8px' }}>{v.name}</h3>
                  <p style={{ font: 'var(--type-body-sm)', color: 'var(--text-body)', margin: '0 0 16px' }}>{v.desc}</p>
                  {open === v.name && <div style={{ marginBottom: 16 }}><SpecList items={v.specs} /></div>}
                  <div style={{ display: 'flex', gap: 10 }}>
                    <Button size="sm" variant="outline" onClick={() => setOpen(open === v.name ? null : v.name)}>
                      {open === v.name ? 'Hide specs' : 'View specs'}
                    </Button>
                    <Button size="sm" variant="secondary" iconRight={<I.ArrowRight size={15}/>} onClick={onQuote}>Request a quote</Button>
                  </div>
                </div>
              </div>
            </Card>
          ))}
        </div>
      </div>
    </section>
  );
}

/* ---------------- Media band ---------------- */
function MediaBand() {
  return (
    <section style={{ position: 'relative', height: 360, display: 'flex', alignItems: 'center', justifyContent: 'center', textAlign: 'center', color: '#fff' }}>
      <img src={`${A}/images/quality-control.png`} alt="Precision turning" style={{ position: 'absolute', inset: 0, width: '100%', height: '100%', objectFit: 'cover' }} />
      <div style={{ position: 'absolute', inset: 0, background: 'linear-gradient(180deg, rgba(0,38,71,0.55), rgba(0,38,71,0.78))' }} />
      <div style={{ position: 'relative', maxWidth: 700, padding: '0 24px' }}>
        <h2 style={{ font: 'var(--type-display-md)', fontStyle: 'italic', textTransform: 'uppercase', margin: '0 0 12px' }}>
          Precision <span style={{ color: 'var(--rms-yellow)' }}>Engineered</span>
        </h2>
        <p style={{ font: 'var(--type-body-lg)', opacity: 0.92, margin: 0 }}>
          Every machine we deliver meets the highest standards of precision and reliability — backed by comprehensive support and service excellence.
        </p>
      </div>
    </section>
  );
}

/* ---------------- Services ---------------- */
const SERVICES = [
  { icon: 'Cog', title: 'Machine Sales & Consultation', desc: 'Expert guidance selecting the right machinery for your aerospace and manufacturing needs.' },
  { icon: 'Wrench', title: 'Maintenance & Service', desc: 'Comprehensive maintenance programs and emergency repair to keep your operations running.' },
  { icon: 'Shield', title: 'Parts & Support', desc: 'Fast parts ordering and technical support from our experienced team of specialists.' },
  { icon: 'Users', title: 'Training & Optimization', desc: 'Operator training and process optimization to maximize your equipment investment.' },
];

function Services() {
  return (
    <section style={{ background: '#fff' }}>
      <div style={{ ...wrap, padding: '76px var(--container-pad)' }}>
        <div style={{ textAlign: 'center', maxWidth: 720, margin: '0 auto 48px' }}>
          <div style={{ display: 'flex', justifyContent: 'center' }}><Eyebrow>Full Lifecycle</Eyebrow></div>
          <h2 style={{ font: 'var(--type-display-md)', color: 'var(--rms-navy)', margin: '14px 0 12px' }}>Comprehensive Support</h2>
          <p style={{ font: 'var(--type-body-lg)', color: 'var(--text-body)', margin: 0 }}>
            Beyond machinery sales, we provide complete lifecycle support so your equipment operates at peak performance throughout its service life.
          </p>
        </div>
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(4,1fr)', gap: 22 }}>
          {SERVICES.map((s) => {
            const Ic = I[s.icon];
            return (
              <Card key={s.title} interactive style={{ textAlign: 'center' }}>
                <div style={{ width: 56, height: 56, margin: '0 auto 16px', borderRadius: 'var(--radius-md)', background: 'var(--rms-blue-100)', color: 'var(--rms-blue)', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
                  <Ic size={26} />
                </div>
                <h3 style={{ font: 'var(--type-h4)', color: 'var(--rms-navy)', margin: '0 0 8px' }}>{s.title}</h3>
                <p style={{ font: 'var(--type-body-sm)', color: 'var(--text-body)', margin: 0 }}>{s.desc}</p>
              </Card>
            );
          })}
        </div>
      </div>
    </section>
  );
}

/* ---------------- CTA ---------------- */
function CTA({ onQuote }) {
  return (
    <section style={{ background: 'var(--rms-navy)', color: '#fff' }}>
      <div style={{ ...wrap, padding: '72px var(--container-pad)', textAlign: 'center' }}>
        <h2 style={{ font: 'var(--type-display-md)', fontStyle: 'italic', textTransform: 'uppercase', margin: '0 0 14px' }}>
          Ready to Enhance Your <span style={{ color: 'var(--rms-yellow)' }}>Capabilities?</span>
        </h2>
        <p style={{ font: 'var(--type-body-lg)', color: 'var(--steel-300)', maxWidth: 600, margin: '0 auto 30px' }}>
          Our team of experts is ready to help you find the perfect machinery solution for your aerospace and manufacturing needs.
        </p>
        <div style={{ display: 'flex', gap: 14, justifyContent: 'center' }}>
          <Button variant="accent" size="lg" iconRight={<I.ArrowRight size={18}/>} onClick={onQuote}>Request a Quote</Button>
          <Button variant="outline" size="lg" style={{ color: '#fff', borderColor: 'rgba(255,255,255,0.4)', background: 'rgba(255,255,255,0.06)' }}>Call +1.203.269.2950</Button>
        </div>
      </div>
    </section>
  );
}

/* ---------------- Footer ---------------- */
function Footer() {
  const cols = [
    { h: 'Machines', items: ['Fives Giddings & Lewis', 'Mitsui Seiki', 'Breton', 'Index'] },
    { h: 'Services', items: ['Sales & Consultation', 'Maintenance', 'Parts & Support', 'Training'] },
    { h: 'Company', items: ['About Us', 'Our Process', 'Careers', 'Contact'] },
  ];
  return (
    <footer style={{ background: 'var(--rms-navy-950)', color: 'var(--steel-300)' }}>
      <div style={{ ...wrap, display: 'grid', gridTemplateColumns: '1.4fr 1fr 1fr 1fr', gap: 40, padding: '56px var(--container-pad) 36px' }}>
        <div>
          <img src={`${A}/logos/rms-logo-white.png`} alt="Ross Machinery" style={{ height: 40, marginBottom: 18 }} />
          <p style={{ font: 'var(--type-body-sm)', maxWidth: 280, margin: '0 0 16px' }}>
            Your partner in advanced manufacturing solutions for the aerospace industry.
          </p>
          <div style={{ display: 'flex', flexDirection: 'column', gap: 8, font: 'var(--type-body-sm)' }}>
            <span style={{ display: 'flex', gap: 8, alignItems: 'center' }}><I.Phone size={15}/> +1.203.269.2950</span>
            <span style={{ display: 'flex', gap: 8, alignItems: 'center' }}><I.Mail size={15}/> office@rossmachinery.com</span>
          </div>
        </div>
        {cols.map((c) => (
          <div key={c.h}>
            <h4 style={{ font: 'var(--type-h4)', color: '#fff', margin: '0 0 16px' }}>{c.h}</h4>
            <ul style={{ listStyle: 'none', padding: 0, margin: 0, display: 'flex', flexDirection: 'column', gap: 10 }}>
              {c.items.map((it) => <li key={it}><a href="#" onClick={(e)=>e.preventDefault()} style={{ color: 'var(--steel-300)', textDecoration: 'none', font: 'var(--type-body-sm)' }}>{it}</a></li>)}
            </ul>
          </div>
        ))}
      </div>
      <div style={{ borderTop: '1px solid rgba(255,255,255,0.1)' }}>
        <div style={{ ...wrap, padding: '18px var(--container-pad)', display: 'flex', justifyContent: 'space-between', font: 'var(--type-caption)', color: 'var(--steel-500)' }}>
          <span>© 2026 Ross Machinery Sales. All rights reserved.</span>
          <span>Aerospace &amp; Advanced Manufacturing · Connecticut, USA</span>
        </div>
      </div>
    </footer>
  );
}

/* ---------------- Quote modal ---------------- */
function QuoteModal({ open, onClose }) {
  const [sent, setSent] = useState(false);
  if (!open) return null;
  return (
    <div onClick={onClose} style={{ position: 'fixed', inset: 0, zIndex: 110, background: 'rgba(15,20,27,0.6)', display: 'flex', alignItems: 'center', justifyContent: 'center', padding: 20 }}>
      <div onClick={(e) => e.stopPropagation()} style={{ background: '#fff', borderRadius: 'var(--radius-md)', borderTop: 'var(--edge-accent)', width: 'min(560px, 100%)', boxShadow: 'var(--shadow-lg)', maxHeight: '90vh', overflow: 'auto' }}>
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', padding: 'var(--space-5) var(--space-6)', borderBottom: '1px solid var(--border-subtle)' }}>
          <div>
            <Eyebrow>Request a Quote</Eyebrow>
            <h3 style={{ font: 'var(--type-h2)', color: 'var(--rms-navy)', margin: '8px 0 0' }}>Tell us about your project</h3>
          </div>
          <button onClick={onClose} style={{ border: 'none', background: 'var(--steel-100)', borderRadius: 'var(--radius-md)', width: 38, height: 38, cursor: 'pointer', color: 'var(--rms-navy)', display: 'flex', alignItems: 'center', justifyContent: 'center' }}><I.X size={20}/></button>
        </div>
        {sent ? (
          <div style={{ padding: 'var(--space-8) var(--space-6)', textAlign: 'center' }}>
            <div style={{ color: 'var(--status-success)', display: 'flex', justifyContent: 'center', marginBottom: 14 }}><I.CheckCircle size={48}/></div>
            <h3 style={{ font: 'var(--type-h2)', color: 'var(--rms-navy)', margin: '0 0 8px' }}>Request received</h3>
            <p style={{ font: 'var(--type-body)', color: 'var(--text-body)', margin: '0 0 22px' }}>A Ross Machinery specialist will be in touch within one business day.</p>
            <Button variant="primary" onClick={onClose}>Done</Button>
          </div>
        ) : (
          <form onSubmit={(e) => { e.preventDefault(); setSent(true); }} style={{ padding: 'var(--space-6)', display: 'grid', gap: 16 }}>
            <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 16 }}>
              <Input label="Full name" placeholder="Jane Doe" required />
              <Input label="Company" placeholder="Acme Aerospace" required />
            </div>
            <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 16 }}>
              <Input label="Email" type="email" placeholder="you@company.com" required />
              <Input label="Phone" placeholder="+1 (203) 555-0100" />
            </div>
            <Input label="What are you looking to machine?" multiline placeholder="Application, materials, tolerances, volumes…" />
            <div style={{ display: 'flex', justifyContent: 'flex-end', gap: 12 }}>
              <Button variant="ghost" type="button" onClick={onClose}>Cancel</Button>
              <Button variant="accent" type="submit" iconRight={<I.ArrowRight size={17}/>}>Submit request</Button>
            </div>
          </form>
        )}
      </div>
    </div>
  );
}

Object.assign(window, { RmsSite: { Header, Hero, TrustBar, Stats, Machines, MediaBand, Services, CTA, Footer, QuoteModal } });
