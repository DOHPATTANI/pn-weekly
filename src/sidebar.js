// Shared, device-local navigation behavior; never mutates business data.
function mountCollapsibleSidebar() {
  const sidebar = document.querySelector('#app-sidebar');
  if (!sidebar || sidebar.dataset.interactionMounted) return;
  sidebar.dataset.interactionMounted = 'true';
  const toggle = document.querySelector('#sidebar-toggle');
  const search = document.querySelector('#sidebar-search-input');
  const clear = document.querySelector('#sidebar-search-clear');
  const mobile = window.matchMedia('(max-width:850px)');
  const buttons = [...sidebar.querySelectorAll('button[data-view]')];
  let savedCollapsed = document.documentElement.classList.contains('sidebar-is-collapsed');
  try { savedCollapsed = localStorage.getItem('pn-weekly-sidebar-collapsed') === 'true'; } catch {}
  for (const button of buttons) {
    const label = button.querySelector('.nav-text')?.textContent.trim() || '';
    button.setAttribute('aria-label', label);
    button.title = label;
  }
  function filterMenus() {
    const query = search.value.trim().toLocaleLowerCase('th');
    for (const button of buttons) button.hidden = !button.getAttribute('aria-label').toLocaleLowerCase('th').includes(query);
    clear.hidden = !search.value;
    document.querySelector('#sidebar-no-results').hidden = buttons.some(button => !button.hidden);
    const header = sidebar.querySelector('.nav-header');
    if (header) header.hidden = ![...header.nextElementSibling.querySelectorAll('[data-view]')].some(button => !button.hidden);
  }
  function applyState() {
    const collapsed = !mobile.matches && savedCollapsed;
    sidebar.classList.toggle('is-collapsed', collapsed);
    document.documentElement.classList.toggle('sidebar-is-collapsed', collapsed);
    toggle.setAttribute('aria-expanded', String(!collapsed));
    toggle.setAttribute('aria-label', mobile.matches ? 'ปิดเมนู' : collapsed ? 'ขยายเมนู' : 'ย่อเมนู');
    toggle.title = toggle.getAttribute('aria-label');
    if (collapsed) { search.value = ''; filterMenus(); }
    // Reduced motion has no transitionend; still refresh canonical table sizing.
    requestAnimationFrame(() => window.dispatchEvent(new Event('resize')));
  }
  function setCollapsed(value) {
    savedCollapsed = value;
    try { localStorage.setItem('pn-weekly-sidebar-collapsed', String(value)); } catch {}
    applyState();
  }
  function focusSearch() {
    setCollapsed(false);
    if (mobile.matches) sidebar.classList.add('open');
    search.focus({ preventScroll: true });
  }
  toggle.addEventListener('click', () => {
    if (mobile.matches) { sidebar.classList.remove('open'); document.querySelector('#mobile-menu')?.focus(); }
    else setCollapsed(!savedCollapsed);
  });
  document.querySelector('#sidebar-search-open').addEventListener('click', focusSearch);
  search.addEventListener('input', filterMenus);
  clear.addEventListener('click', () => { search.value = ''; filterMenus(); search.focus(); });
  search.addEventListener('keydown', event => {
    if (event.isComposing) return;
    if (event.key === 'Escape') { search.value = ''; filterMenus(); }
    if (event.key === 'Enter') { event.preventDefault(); buttons.find(button => !button.hidden)?.click(); }
  });
  document.addEventListener('keydown', event => {
    if (event.isComposing || event.altKey || event.repeat || document.querySelector('#modal')?.open) return;
    if ((event.ctrlKey || event.metaKey) && event.key.toLowerCase() === 'k') { event.preventDefault(); focusSearch(); }
    if (event.key === 'Escape' && mobile.matches && sidebar.classList.contains('open')) {
      sidebar.classList.remove('open'); document.querySelector('#mobile-menu')?.focus();
    }
  });
  mobile.addEventListener('change', () => { sidebar.classList.remove('open'); applyState(); });
  // Existing pinned columns and sticky header owners recalculate once the width settles.
  sidebar.addEventListener('transitionend', event => {
    if (event.target === sidebar && event.propertyName === 'width') window.dispatchEvent(new Event('resize'));
  });
  applyState();
}
if (typeof document !== 'undefined') mountCollapsibleSidebar();
