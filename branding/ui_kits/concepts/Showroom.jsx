// Direction B — Partner Showroom. Brand-led browse: enter through the four
// prestige builders, then drill into a filterable spec catalog for each.
const React = window.React;
const { useState } = React;
const DS = window.RossMachineryDesignSystem_610e0e;
const { Button, Badge, Card, Eyebrow, SpecList } = DS;
const I = window.RmsIcons;
const A = '../../assets';
const { BUILDERS, MACHINES, PROCESSES, builderLogo } = window.RmsData;

const PROC_LABEL = Object.fromEntries(PROCESSES.map(p => [p.id, p.label]));

function MarqueGallery({ onOpen }) {
  const heroImg = { 'Fives Giddings & Lewis':'giddings-lewis-v1250.png', 'Mitsui Seiki':'mitsui-seiki-hpx150.webp', 'Breton':'breton-genesi.webp', 'Index':'innovation.jpg' };
  return (
    <div style={{ background:'var(--steel-50)', minHeight:'calc(100vh - 68px)' }}>
      <section style={{ background:'var(--rms-navy)', color:'#fff', padding:'56px 40px 64px' }}>
        <div style={{ maxWidth:1280, margin:'0 auto' }}>
          <Eyebrow color="var(--rms-yellow)">The Showroom</Eyebrow>
          <h1 style={{ font:'var(--type-display-md)', fontStyle:'italic', textTransform:'uppercase', margin:'14px 0 10px', maxWidth:760 }}>
            Four builders.<br/>One standard of <span style={{ color:'var(--rms-yellow)' }}>precision.</span>
          </h1>
          <p style={{ font:'var(--type-body-lg)', color:'var(--steel-300)', maxWidth:600, margin:0 }}>
            We represent the world's finest machine-tool marques. Step into a builder to explore their aerospace-proven lineup.
          </p>
        </div>
      </section>

      <section style={{ maxWidth:1280, margin:'0 auto', padding:'40px', marginTop:-40 }}>
        <div style={{ display:'grid', gridTemplateColumns:'1fr 1fr', gap:24 }}>
          {Object.entries(BUILDERS).map(([name, b]) => {
            const count = MACHINES.filter(m => m.builder===name).length;
            return (
              <Card key={name} interactive padding="0" style={{ overflow:'hidden', cursor:'pointer' }} onClick={()=>onOpen(name)}>
                <div style={{ position:'relative', height:180 }}>
                  <img src={`${A}/images/${heroImg[name]}`} alt={name} style={{ width:'100%', height:'100%', objectFit:'cover' }} />
                  <div style={{ position:'absolute', inset:0, background:'linear-gradient(180deg, rgba(0,38,71,0.15), rgba(0,38,71,0.82))' }} />
                  <div style={{ position:'absolute', left:0, bottom:0, padding:'20px 24px', display:'flex', alignItems:'center', justifyContent:'space-between', width:'100%', boxSizing:'border-box' }}>
                    <div style={{ background:'#fff', borderRadius:'var(--radius-sm)', padding:'8px 12px', display:'flex', alignItems:'center' }}>{builderLogo(name, 28)}</div>
                    <Badge tone="yellow" variant="solid">{b.origin}</Badge>
                  </div>
                </div>
                <div style={{ padding:'var(--space-5) var(--space-6) var(--space-6)' }}>
                  <p style={{ font:'var(--type-body)', color:'var(--text-body)', margin:'0 0 16px' }}>{b.blurb}</p>
                  <div style={{ display:'flex', alignItems:'center', justifyContent:'space-between' }}>
                    <span style={{ font:'var(--type-mono)', color:'var(--text-muted)' }}>{count} platforms</span>
                    <span style={{ display:'inline-flex', alignItems:'center', gap:8, font:'var(--type-body)', fontWeight:700, color:'var(--rms-blue)' }}>Explore lineup <I.ArrowRight size={17}/></span>
                  </div>
                </div>
              </Card>
            );
          })}
        </div>
      </section>
    </div>
  );
}

function Catalog({ builder, onBack, onQuote }) {
  const [proc, setProc] = useState(null);
  const b = BUILDERS[builder];
  const all = MACHINES.filter(m => m.builder===builder);
  const procsAvail = [...new Set(all.map(m => m.process))];
  const list = proc ? all.filter(m => m.process===proc) : all;

  return (
    <div style={{ background:'var(--steel-50)', minHeight:'calc(100vh - 68px)' }}>
      <section style={{ background:'var(--rms-navy)', color:'#fff', padding:'30px 40px 36px' }}>
        <div style={{ maxWidth:1280, margin:'0 auto' }}>
          <button onClick={onBack} style={{ border:'none', background:'transparent', color:'var(--rms-blue-400)', cursor:'pointer', font:'var(--type-body-sm)', fontWeight:600, padding:0, display:'inline-flex', alignItems:'center', gap:7, marginBottom:18 }}>
            <span style={{ transform:'rotate(180deg)', display:'inline-flex' }}><I.ArrowRight size={15}/></span> All builders
          </button>
          <div style={{ display:'flex', alignItems:'center', gap:20, flexWrap:'wrap' }}>
            <div style={{ background:'#fff', borderRadius:'var(--radius-sm)', padding:'12px 16px', display:'flex', alignItems:'center' }}>{builderLogo(builder, 36)}</div>
            <div>
              <h1 style={{ font:'var(--type-h1)', margin:0 }}>{builder}</h1>
              <p style={{ font:'var(--type-body)', color:'var(--steel-300)', margin:'4px 0 0', maxWidth:560 }}>{b.blurb}</p>
            </div>
            <div style={{ marginLeft:'auto', textAlign:'right' }}>
              <div style={{ font:'var(--type-display-sm)', fontStyle:'italic', color:'var(--rms-yellow)' }}>{b.origin}</div>
            </div>
          </div>
        </div>
      </section>

      <section style={{ maxWidth:1280, margin:'0 auto', padding:'28px 40px 48px' }}>
        <div style={{ display:'flex', gap:9, marginBottom:22, flexWrap:'wrap', alignItems:'center' }}>
          <span style={{ font:'var(--type-eyebrow)', textTransform:'uppercase', letterSpacing:'0.12em', color:'var(--text-muted)', marginRight:6 }}>Filter</span>
          <FilterChip active={!proc} onClick={()=>setProc(null)}>All</FilterChip>
          {procsAvail.map(p => <FilterChip key={p} active={proc===p} onClick={()=>setProc(p)}>{PROC_LABEL[p]}</FilterChip>)}
        </div>

        <div style={{ display:'flex', flexDirection:'column', gap:16 }}>
          {list.map(m => (
            <Card key={m.id} padding="0" style={{ overflow:'hidden' }}>
              <div style={{ display:'grid', gridTemplateColumns: m.photo ? '240px 1fr' : '1fr', alignItems:'stretch' }}>
                {m.photo && <img src={`${A}/images/${m.photo}`} alt={m.name} style={{ width:'100%', height:'100%', minHeight:170, objectFit:'cover' }} />}
                <div style={{ padding:'var(--space-5) var(--space-6)', display:'grid', gridTemplateColumns:'1fr 300px', gap:28, alignItems:'center' }}>
                  <div>
                    <Badge tone="navy" variant="soft" style={{ marginBottom:10 }}>{m.axes} · {PROC_LABEL[m.process]}</Badge>
                    <h3 style={{ font:'var(--type-h2)', color:'var(--rms-navy)', margin:'0 0 14px' }}>{m.name}</h3>
                    <Button size="sm" variant="secondary" iconRight={<I.ArrowRight size={15}/>} onClick={()=>onQuote(m)}>Request a quote</Button>
                  </div>
                  <div style={{ borderLeft:'1px solid var(--border-subtle)', paddingLeft:24 }}><SpecList items={m.specs} /></div>
                </div>
              </div>
            </Card>
          ))}
        </div>
      </section>
    </div>
  );
}

function FilterChip({ active, onClick, children }) {
  return (
    <button onClick={onClick} style={{
      border: active ? '1.5px solid var(--rms-navy)' : '1.5px solid var(--border-default)',
      background: active ? 'var(--rms-navy)' : '#fff', color: active ? '#fff' : 'var(--text-body)',
      cursor:'pointer', borderRadius:'var(--radius-pill)', padding:'7px 15px', font:'var(--type-body-sm)', fontWeight:600,
      transition:'all var(--dur-fast) var(--ease-standard)',
    }}>{children}</button>
  );
}

function Showroom({ onQuote }) {
  const [builder, setBuilder] = useState(null);
  return builder
    ? <Catalog builder={builder} onBack={()=>setBuilder(null)} onQuote={onQuote} />
    : <MarqueGallery onOpen={setBuilder} />;
}

Object.assign(window, { RmsShowroom: Showroom });
