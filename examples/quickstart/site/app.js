/* Spec Agent Kibo demo – renders a cute spy-bot badge as inline SVG */
(function () {
  function el(tag, attrs, children) {
    const n = document.createElementNS('http://www.w3.org/2000/svg', tag);
    if (attrs) for (const k in attrs) n.setAttribute(k, attrs[k]);
    (children || []).forEach(c => n.appendChild(c));
    return n;
  }

  function text(x, y, value, props) {
    const t = document.createElementNS('http://www.w3.org/2000/svg', 'text');
    t.setAttribute('x', x); t.setAttribute('y', y);
    t.setAttribute('fill', props?.fill || '#e6e9ff');
    t.setAttribute('font-family', 'ui-sans-serif, system-ui, -apple-system, Segoe UI, Roboto, Helvetica, Arial');
    t.setAttribute('font-size', props?.size || '14');
    t.setAttribute('font-weight', props?.weight || '600');
    if (props?.letterSpacing) t.setAttribute('letter-spacing', props.letterSpacing);
    t.textContent = value;
    return t;
  }

  function renderKiboAgentBadge(opts) {
    const width = 280, height = 140;
    const svg = el('svg', { width, height, viewBox: '0 0 280 140', role: 'img', 'aria-labelledby': 'title desc', class: 'kibo-badge' });
    const title = document.createElementNS('http://www.w3.org/2000/svg', 'title'); title.id = 'title'; title.textContent = 'Spec Agent Kibo badge';
    const desc = document.createElementNS('http://www.w3.org/2000/svg', 'desc'); desc.id = 'desc'; desc.textContent = 'A cute spy robot with a hat and monocle holding a spec file.';
    svg.appendChild(title); svg.appendChild(desc);

    // Card background
    svg.appendChild(el('rect', { x: 0, y: 0, width, height, rx: 12, fill: '#111427' }));
    const grad = el('linearGradient', { id: 'g', x1: '0%', y1: '0%', x2: '100%', y2: '0%' }, [
      el('stop', { offset: '0%', 'stop-color': '#7c9cff'}),
      el('stop', { offset: '100%', 'stop-color': '#60e6a8'})
    ]);
    const defs = el('defs', {}, [grad]); svg.appendChild(defs);
    svg.appendChild(el('rect', { x: 8, y: 8, width: width-16, height: height-16, rx: 10, fill: 'url(#g)', opacity: 0.08 }));

    // Spy-bot body
    svg.appendChild(el('rect', { x: 26, y: 28, width: 88, height: 64, rx: 10, fill: '#1d2240', stroke: '#3b4170', 'stroke-width': 2 }));
    // Eyes
    svg.appendChild(el('circle', { cx: 54, cy: 54, r: 8, fill: '#e6e9ff' }));
    svg.appendChild(el('circle', { cx: 86, cy: 54, r: 8, fill: '#e6e9ff' }));
    // Monocle
    svg.appendChild(el('circle', { cx: 86, cy: 54, r: 12, fill: 'none', stroke: '#60e6a8', 'stroke-width': 2 }));
    svg.appendChild(el('line', { x1: 98, y1: 62, x2: 110, y2: 82, stroke: '#60e6a8', 'stroke-width': 2 }));
    // Smile
    svg.appendChild(el('path', { d: 'M50 72 Q70 84 90 72', fill: 'none', stroke: '#e6e9ff', 'stroke-width': 2, 'stroke-linecap': 'round' }));
    // Fedora hat
    svg.appendChild(el('rect', { x: 34, y: 16, width: 72, height: 10, rx: 5, fill: '#0d0f1a', stroke: '#3b4170', 'stroke-width': 2 }));
    svg.appendChild(el('rect', { x: 46, y: 8, width: 48, height: 12, rx: 4, fill: '#0d0f1a', stroke: '#3b4170', 'stroke-width': 2 }));

    // Spec file icon in hand
    svg.appendChild(el('rect', { x: 126, y: 48, width: 28, height: 36, rx: 3, fill: '#e6e9ff', opacity: 0.95 }));
    svg.appendChild(el('path', { d: 'M126 62 L154 62', stroke: '#7c9cff', 'stroke-width': 2 }));
    svg.appendChild(el('path', { d: 'M126 70 L154 70', stroke: '#7c9cff', 'stroke-width': 2 }));
    svg.appendChild(el('path', { d: 'M126 78 L146 78', stroke: '#7c9cff', 'stroke-width': 2 }));

    // Title
    svg.appendChild(text(22, 120, 'Spec Agent Kibo', { size: 16, weight: 700 }));
    svg.appendChild(text(164, 66, 'SPEC', { size: 10, weight: 700, fill: '#0f1221', letterSpacing: '1px' }));

    return svg;
  }

  function mountBadge() {
    const wrap = document.getElementById('kibo-agent-badge-container');
    if (!wrap) return;
    // Clear old
    wrap.innerHTML = '';
    // Accessible label
    const sr = document.createElement('span'); sr.className = 'kibo-sr-only'; sr.textContent = 'Spec Agent Kibo badge';
    wrap.appendChild(sr);
    // Render
    wrap.appendChild(renderKiboAgentBadge());
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', mountBadge);
  } else {
    mountBadge();
  }
})();
