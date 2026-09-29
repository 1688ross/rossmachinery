// Direction A — Capability Finder. Tool-first: narrow by application, process,
// material and matching machines filter in live.
const React = window.React;
const { useState, useMemo } = React;
const DS = window.RossMachineryDesignSystem_610e0e;
const { Button, Badge, Card, Eyebrow, SpecList } = DS;
const I = window.RmsIcons;
const A = '../../assets';
const { BUILDERS, MACHINES, APPLICATIONS, PROCESSES, MATERIALS, builderLogo } = window.RmsData;

function Facet({ label, children }) {
  return (
    <div style={{ marginBottom: 26 }}>
      <div style={{ font:'var(--type-eyebrow)', textTransform:'uppercase', letterSpacing:'0.12em', color:'var(--rms-yellow)', marginBottom:12 }}>{label}</div>
      {children}
    </div>
  );
}

function Chip({ active, onClick, children }) {
  return (
    <button onClick={onClick} style={{
      border: active ? '1.5px solid var(--rms-yellow)' : '1.5px solid rgba(255,255,255,0.18)',
      background: active ? 'rgba(251,181,28,0.16)' : 'rgba(255,255,255,0.04)',
      color:'#fff', cursor:'pointer', borderRadius:'var(--radius-md)', padding:'9px 14px',
      font:'var(--type-body-sm)', fontWeight:600, transition:'all var(--dur-fast) var(--ease-standard)',
    }}>{children}</button>
  );
}

function Finder({ onQuote }) {
  const [app, setApp] = useState(null);
  const [proc, setProc] = useState(null);
  const [mat, setMat] = useState(null);
  const toggle = (cur, val, set) => set(cur === val ? null : val);

  const results = useMemo(() => MACHINES.filter(m =>
    (!app || m.application.includes(app)) &&
    (!proc || m.process === proc) &&
    (!mat || m.material.includes(mat))
  ), [app, proc, mat]);

  const any = app || proc || mat;

  return (
    <div style={{ display:'grid', gridTemplateColumns:'400px 1fr', minHeight:'calc(100vh - 68px)' }}>
      {/* Left selector rail */}
      <aside style={{ position:'relative', background:'var(--rms-navy-900)', color:'#fff', padding:'40px 34px', overflow:'hidden' }}>
        <img src={`${A}/images/world-map.png`} alt="" style={{ position:'absolute', inset:0, width:'100%', height:'100%', objectFit:'cover', opacity:0.06 }} />
        <div style={{ position:'relative' }}>
          <Eyebrow color="var(--rms-yellow)">Find your machine</Eyebrow>
          <h1 style={{ font:'var(--type-display-sm)', fontStyle:'italic', textTransform:'uppercase', lineHeight:1.05, margin:'14px 0 10px' }}>
            What are you<br/>machining?
          </h1>
          <p style={{ font:'var(--type-body-sm)', color:'var(--steel-300)', margin:'0 0 30px' }}>
            Tell us the job. We'll match it to the right builder and platform from our aerospace-proven lineup.
          </p>

          <Facet label="Application">
            <div style={{ display:'grid', gridTemplateColumns:'1fr 1fr', gap:10 }}>
              {APPLICATIONS.map(a => {
                const Ic = I[a.icon]; const active = app===a.id;
                return (
                  <button key={a.id} onClick={()=>toggle(app,a.id,setApp)} style={{
                    textAlign:'left', cursor:'pointer', borderRadius:'var(--radius-md)', padding:'12px 13px',
                    border: active ? '1.5px solid var(--rms-yellow)' : '1.5px solid rgba(255,255,255,0.18)',
                    background: active ? 'rgba(251,181,28,0.16)' : 'rgba(255,255,255,0.04)', color:'#fff',
                    transition:'all var(--dur-fast) var(--ease-standard)',
                  }}>
                    <span style={{ color: active ? 'var(--rms-yellow)' : 'var(--rms-blue-400)', display:'block', marginBottom:7 }}><Ic size={22}/></span>
                    <span style={{ font:'var(--type-body-sm)', fontWeight:700, display:'block', lineHeight:1.2 }}>{a.label}</span>
                    <span style={{ font:'var(--type-caption)', color:'var(--steel-400)' }}>{a.desc}</span>
                  </button>
                );
              })}
            </div>
          </Facet>

          <Facet label="Process">
            <div style={{ display:'flex', flexWrap:'wrap', gap:9 }}>
              {PROCESSES.map(p => <Chip key={p.id} active={proc===p.id} onClick={()=>toggle(proc,p.id,setProc)}>{p.label}</Chip>)}
            </div>
          </Facet>

          <Facet label="Material">
            <div style={{ display:'flex', flexWrap:'wrap', gap:9 }}>
              {MATERIALS.map(m => <Chip key={m.id} active={mat===m.id} onClick={()=>toggle(mat,m.id,setMat)}>{m.label}</Chip>)}
            </div>
          </Facet>

          {any && (
            <button onClick={()=>{setApp(null);setProc(null);setMat(null);}} style={{
              border:'none', background:'transparent', color:'var(--rms-blue-400)', cursor:'pointer',
              font:'var(--type-body-sm)', fontWeight:600, padding:0, textDecoration:'underline',
            }}>Reset filters</button>
          )}
        </div>
      </aside>

      {/* Results */}
      <main style={{ background:'var(--steel-50)', padding:'34px 40px' }}>
        <div style={{ display:'flex', alignItems:'baseline', justifyContent:'space-between', marginBottom:22 }}>
          <h2 style={{ font:'var(--type-h2)', color:'var(--rms-navy)', margin:0 }}>
            {results.length} {results.length===1?'machine':'machines'} match
          </h2>
          <span style={{ font:'var(--type-body-sm)', color:'var(--text-muted)' }}>{any ? 'Refine further on the left' : 'Showing the full lineup'}</span>
        </div>

        <div style={{ display:'grid', gridTemplateColumns:'1fr 1fr', gap:20 }}>
          {results.map(m => (
            <Card key={m.id} accentEdge interactive padding="0">
              {m.photo
                ? <img src={`${A}/images/${m.photo}`} alt={m.name} style={{ width:'100%', height:150, objectFit:'cover', borderRadius:'var(--radius-md) var(--radius-md) 0 0' }} />
                : <div style={{ height:64, background:'var(--steel-100)', borderRadius:'var(--radius-md) var(--radius-md) 0 0', display:'flex', alignItems:'center', padding:'0 var(--space-5)' }}>{builderLogo(m.builder, 28)}</div>}
              <div style={{ padding:'var(--space-5)' }}>
                <div style={{ display:'flex', justifyContent:'space-between', alignItems:'center', marginBottom:6 }}>
                  {m.photo ? builderLogo(m.builder, 22) : <span style={{ font:'var(--type-caption)', color:'var(--text-muted)' }}>{m.builder}</span>}
                  <Badge tone="navy" variant="soft">{m.axes}</Badge>
                </div>
                <h3 style={{ font:'var(--type-h3)', color:'var(--rms-navy)', margin:'0 0 14px' }}>{m.name}</h3>
                <SpecList items={m.specs} />
                <div style={{ marginTop:16 }}>
                  <Button size="sm" variant="secondary" iconRight={<I.ArrowRight size={15}/>} onClick={()=>onQuote(m)}>Request a quote</Button>
                </div>
              </div>
            </Card>
          ))}
        </div>

        {results.length===0 && (
          <Card style={{ textAlign:'center', padding:'var(--space-8)' }}>
            <h3 style={{ font:'var(--type-h3)', color:'var(--rms-navy)', margin:'0 0 8px' }}>No exact match</h3>
            <p style={{ font:'var(--type-body)', color:'var(--text-body)', margin:'0 0 18px' }}>Our specialists source custom configurations every day. Tell us what you need.</p>
            <Button variant="accent" onClick={()=>onQuote(null)}>Talk to a specialist</Button>
          </Card>
        )}
      </main>
    </div>
  );
}

Object.assign(window, { RmsFinder: Finder });
