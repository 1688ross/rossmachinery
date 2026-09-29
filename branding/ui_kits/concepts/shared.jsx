// Ross Machinery — concept explorer: shared data + chrome.
const React = window.React;
const { useState } = React;
const DS = window.RossMachineryDesignSystem_610e0e;
const { Button, Badge, Eyebrow, Input } = DS;
const I = window.RmsIcons;
const A = '../../assets';

/* ---------------- Builders ---------------- */
const BUILDERS = {
  'Fives Giddings & Lewis': { logo: 'fives-giddings-lewis.png', origin: 'USA', blurb: 'Heavy-duty horizontal boring mills, machining & vertical turning centers.' },
  'Mitsui Seiki':           { logo: 'mitsui-seiki.webp',        origin: 'Japan', blurb: 'High-precision 4 & 5 axis centers, jig bores & grinders. 5-yr accuracy guarantee.' },
  'Breton':                 { logo: 'breton.jpg',               origin: 'Italy', blurb: 'Gantry machine tools for composites & aerospace alloys, large-format additive.' },
  'Index':                  { logo: 'index.png',                origin: 'Germany', blurb: 'Multi-spindle lathes & 5-axis turn-mill centers for high-volume production.' },
};

/* ---------------- Machine catalog ----------------
   application: structural | engine | composite | precision
   process:     boring | 5axis | turning | gantry
   material:    aluminum | titanium | composite | steel
*/
const MACHINES = [
  { id:'gl-v1250', builder:'Fives Giddings & Lewis', name:'V1250 Vertical Turning Center', photo:'giddings-lewis-v1250.png',
    process:'turning', application:['structural','precision'], material:['aluminum','steel','titanium'], axes:'4-axis',
    specs:[{label:'Swing',value:'1250 mm'},{label:'Max Height',value:'900 mm'},{label:'Table Load',value:'5,000 kg'},{label:'Origin',value:'USA'}] },
  { id:'gl-hbm130', builder:'Fives Giddings & Lewis', name:'HBM-130 Horizontal Boring Mill',
    process:'boring', application:['structural'], material:['steel','aluminum'], axes:'4-axis',
    specs:[{label:'Spindle Dia.',value:'130 mm'},{label:'X/Y/Z',value:'4000×2500×1600'},{label:'Spindle',value:'40T · 3,000 rpm'},{label:'Origin',value:'USA'}] },
  { id:'gl-ram5000', builder:'Fives Giddings & Lewis', name:'RAM 5000 Floor-Type Mill',
    process:'boring', application:['structural'], material:['steel'], axes:'5-axis',
    specs:[{label:'X Travel',value:'12,000 mm'},{label:'Ram Stroke',value:'1,500 mm'},{label:'Spindle',value:'50T'},{label:'Origin',value:'USA'}] },

  { id:'ms-hpx150', builder:'Mitsui Seiki', name:'HPX150 5-Axis Machining Center', photo:'mitsui-seiki-hpx150.webp',
    process:'5axis', application:['engine','precision'], material:['titanium','aluminum'], axes:'5-axis',
    specs:[{label:'X/Y/Z',value:'1500×1300×1400'},{label:'Spindle',value:'50T · 12,000 rpm'},{label:'Accuracy',value:'±0.003 mm'},{label:'Origin',value:'Japan'}] },
  { id:'ms-vertex55x', builder:'Mitsui Seiki', name:'Vertex 55X 5-Axis VMC',
    process:'5axis', application:['precision','engine'], material:['titanium','aluminum','steel'], axes:'5-axis',
    specs:[{label:'X/Y/Z',value:'550×620×510'},{label:'Spindle',value:'40T · 20,000 rpm'},{label:'Accuracy',value:'±0.002 mm'},{label:'Origin',value:'Japan'}] },
  { id:'ms-j350g', builder:'Mitsui Seiki', name:'J350G Jig Grinder',
    process:'5axis', application:['precision'], material:['steel','titanium'], axes:'4-axis',
    specs:[{label:'Table',value:'500×350 mm'},{label:'Spindle',value:'60,000 rpm'},{label:'Accuracy',value:'±0.001 mm'},{label:'Origin',value:'Japan'}] },

  { id:'br-ultrix1000', builder:'Breton', name:'Ultrix 1000 5-Axis Gantry',
    process:'gantry', application:['composite','structural'], material:['composite','aluminum'], axes:'5-axis',
    specs:[{label:'Work Area',value:'10,000×3,000'},{label:'Spindle',value:'HSK-A63 · 24k rpm'},{label:'Heads',value:'Mill + Turn'},{label:'Origin',value:'Italy'}] },
  { id:'br-genesi', builder:'Breton', name:'Genesi Trunnion Mill-Turn', photo:'breton-genesi.webp',
    process:'gantry', application:['composite','engine'], material:['composite','titanium'], axes:'5-axis',
    specs:[{label:'Swing',value:'1,600 mm'},{label:'Trunnion',value:'±120°'},{label:'Spindle',value:'HSK-A100'},{label:'Origin',value:'Italy'}] },
  { id:'br-xceeder', builder:'Breton', name:'Xceeder Large-Format Additive',
    process:'gantry', application:['composite','structural'], material:['composite'], axes:'5-axis',
    specs:[{label:'Build Vol.',value:'6,000×2,000'},{label:'Process',value:'Hybrid additive'},{label:'Heads',value:'Deposit + Mill'},{label:'Origin',value:'Italy'}] },

  { id:'ix-g220', builder:'Index', name:'G220 Turn-Mill Center',
    process:'turning', application:['precision','engine'], material:['titanium','steel','aluminum'], axes:'5-axis',
    specs:[{label:'Swing',value:'220 mm'},{label:'Bar Cap.',value:'65 mm'},{label:'Spindles',value:'Main + Counter'},{label:'Origin',value:'Germany'}] },
  { id:'ix-ms40', builder:'Index', name:'MS40 Multi-Spindle Lathe',
    process:'turning', application:['precision'], material:['steel','aluminum'], axes:'4-axis',
    specs:[{label:'Spindles',value:'6 × Ø40 mm'},{label:'Bar Cap.',value:'40 mm'},{label:'Output',value:'High volume'},{label:'Origin',value:'Germany'}] },
  { id:'ix-c200', builder:'Index', name:'C200 Production Turn-Mill',
    process:'turning', application:['precision','structural'], material:['aluminum','steel'], axes:'4-axis',
    specs:[{label:'Swing',value:'200 mm'},{label:'Bar Cap.',value:'51 mm'},{label:'Spindle',value:'6,000 rpm'},{label:'Origin',value:'Germany'}] },
];

const APPLICATIONS = [
  { id:'structural', label:'Aerospace Structural', icon:'Shield', desc:'Large frames, spars, bulkheads' },
  { id:'engine',     label:'Turbine / Engine',     icon:'Gauge',  desc:'Blades, discs, casings' },
  { id:'composite',  label:'Composites',           icon:'Globe',  desc:'Layups, trimming, additive' },
  { id:'precision',  label:'General Precision',    icon:'Cog',    desc:'Tight-tolerance components' },
];
const PROCESSES = [
  { id:'boring',  label:'Boring / Milling' },
  { id:'5axis',   label:'5-Axis Machining' },
  { id:'turning', label:'Turning / Turn-Mill' },
  { id:'gantry',  label:'Gantry / Large-Format' },
];
const MATERIALS = [
  { id:'aluminum',  label:'Aluminum' },
  { id:'titanium',  label:'Titanium / Inconel' },
  { id:'composite', label:'Composites' },
  { id:'steel',     label:'Steel' },
];

function builderLogo(name, h = 26) {
  return <img src={`${A}/vendors/${BUILDERS[name].logo}`} alt={name} style={{ maxHeight: h, maxWidth: 130, objectFit: 'contain' }} />;
}

/* ---------------- Quote modal ---------------- */
function QuoteModal({ open, machine, onClose }) {
  const [sent, setSent] = useState(false);
  React.useEffect(() => { if (open) setSent(false); }, [open]);
  if (!open) return null;
  return (
    <div onClick={onClose} style={{ position:'fixed', inset:0, zIndex:110, background:'rgba(15,20,27,0.6)', display:'flex', alignItems:'center', justifyContent:'center', padding:20 }}>
      <div onClick={(e)=>e.stopPropagation()} style={{ background:'#fff', borderRadius:'var(--radius-md)', borderTop:'var(--edge-accent)', width:'min(540px,100%)', boxShadow:'var(--shadow-lg)', maxHeight:'90vh', overflow:'auto' }}>
        <div style={{ display:'flex', justifyContent:'space-between', alignItems:'flex-start', padding:'var(--space-5) var(--space-6)', borderBottom:'1px solid var(--border-subtle)' }}>
          <div>
            <Eyebrow>Request a Quote</Eyebrow>
            <h3 style={{ font:'var(--type-h2)', color:'var(--rms-navy)', margin:'8px 0 0' }}>{machine ? machine.name : 'Tell us about your project'}</h3>
            {machine && <p style={{ font:'var(--type-body-sm)', color:'var(--text-muted)', margin:'4px 0 0' }}>{machine.builder}</p>}
          </div>
          <button onClick={onClose} style={{ border:'none', background:'var(--steel-100)', borderRadius:'var(--radius-md)', width:38, height:38, cursor:'pointer', color:'var(--rms-navy)', display:'flex', alignItems:'center', justifyContent:'center' }}><I.X size={20}/></button>
        </div>
        {sent ? (
          <div style={{ padding:'var(--space-8) var(--space-6)', textAlign:'center' }}>
            <div style={{ color:'var(--status-success)', display:'flex', justifyContent:'center', marginBottom:14 }}><I.CheckCircle size={48}/></div>
            <h3 style={{ font:'var(--type-h2)', color:'var(--rms-navy)', margin:'0 0 8px' }}>Request received</h3>
            <p style={{ font:'var(--type-body)', color:'var(--text-body)', margin:'0 0 22px' }}>A Ross Machinery specialist will be in touch within one business day.</p>
            <Button variant="primary" onClick={onClose}>Done</Button>
          </div>
        ) : (
          <form onSubmit={(e)=>{e.preventDefault(); setSent(true);}} style={{ padding:'var(--space-6)', display:'grid', gap:16 }}>
            <div style={{ display:'grid', gridTemplateColumns:'1fr 1fr', gap:16 }}>
              <Input label="Full name" placeholder="Jane Doe" required />
              <Input label="Company" placeholder="Acme Aerospace" required />
            </div>
            <Input label="Email" type="email" placeholder="you@company.com" required />
            <Input label="Application notes" multiline placeholder="Materials, tolerances, volumes…" />
            <div style={{ display:'flex', justifyContent:'flex-end', gap:12 }}>
              <Button variant="ghost" type="button" onClick={onClose}>Cancel</Button>
              <Button variant="accent" type="submit" iconRight={<I.ArrowRight size={17}/>}>Submit request</Button>
            </div>
          </form>
        )}
      </div>
    </div>
  );
}

/* ---------------- Top bar + concept switcher ---------------- */
function TopBar({ concept, setConcept, onQuote }) {
  return (
    <header style={{ position:'sticky', top:0, zIndex:60, background:'#fff', borderBottom:'1px solid var(--border-subtle)', boxShadow:'var(--shadow-xs)' }}>
      <div style={{ maxWidth:1280, margin:'0 auto', padding:'0 28px', height:68, display:'flex', alignItems:'center', justifyContent:'space-between', gap:24 }}>
        <img src={`${A}/logos/rms-logo-color.png`} alt="Ross Machinery" style={{ height:40 }} />
        <div style={{ display:'flex', alignItems:'center', gap:6, background:'var(--steel-100)', borderRadius:'var(--radius-pill)', padding:4 }}>
          {[['finder','Capability Finder'],['showroom','Partner Showroom']].map(([id,label]) => (
            <button key={id} onClick={()=>setConcept(id)} style={{
              border:'none', cursor:'pointer', borderRadius:'var(--radius-pill)', padding:'8px 16px',
              font:'var(--type-body-sm)', fontWeight:600,
              background: concept===id ? 'var(--rms-navy)' : 'transparent',
              color: concept===id ? '#fff' : 'var(--text-muted)',
              transition:'all var(--dur-fast) var(--ease-standard)',
            }}>{label}</button>
          ))}
        </div>
        <div style={{ display:'flex', alignItems:'center', gap:18 }}>
          <span style={{ display:'flex', alignItems:'center', gap:7, font:'var(--type-body-sm)', fontWeight:600, color:'var(--rms-navy)' }}><I.Phone size={15}/> +1.203.269.2950</span>
          <Button variant="accent" onClick={()=>onQuote(null)}>Request a Quote</Button>
        </div>
      </div>
    </header>
  );
}

Object.assign(window, { RmsData: { BUILDERS, MACHINES, APPLICATIONS, PROCESSES, MATERIALS, builderLogo }, RmsConcepts: { QuoteModal, TopBar } });
