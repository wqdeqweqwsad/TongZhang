const expenses = [
  { title: '晚餐', meta: '餐饮 · 今天 19:30', amount: 168, payer: '小明', icon: '◒', tone: 'terra' },
  { title: '打车', meta: '交通 · 今天 18:10', amount: 42, payer: '小红', icon: '↗', tone: '' },
  { title: '电影票', meta: '娱乐 · 16 Sep', amount: 120, payer: '小明', icon: '◇', tone: 'terra' },
  { title: '周末咖啡', meta: '餐饮 · 15 Sep', amount: 58, payer: '小红', icon: '◒', tone: '' },
  { title: '便利店', meta: '日常 · 14 Sep', amount: 86, payer: '小明', icon: '＋', tone: 'terra' },
];

const $ = (selector) => document.querySelector(selector);
const $$ = (selector) => [...document.querySelectorAll(selector)];
const money = (value) => `¥${value.toLocaleString('zh-CN')}`;

function renderActivity() {
  $('#recent-list').innerHTML = expenses.slice(0, 3).map(item => `
    <div class="activity-item"><span class="activity-icon ${item.tone}">${item.icon}</span><div class="activity-copy"><strong>${item.title}</strong><small>${item.meta} · ${item.payer}支付</small></div><span class="activity-amount">${money(item.amount)}</span></div>`).join('');
}

function renderBills() {
  const groups = { '18 SEPTEMBER': expenses.slice(0, 2), '16 SEPTEMBER': expenses.slice(2, 3), '15 SEPTEMBER': expenses.slice(3) };
  $('#bill-list').innerHTML = Object.entries(groups).map(([date, items]) => `<div class="bill-group-title">${date}</div>${items.map(item => `
    <div class="bill-item"><span class="activity-icon ${item.tone}">${item.icon}</span><div class="activity-copy"><strong>${item.title}</strong><small><span class="payer-dot ${item.payer === '小红' ? 'her' : ''}"></span>${item.payer}支付 · ${item.meta.split(' · ')[0]}</small></div><span class="activity-amount">${money(item.amount)}</span></div>`).join('')}`).join('');
}

function showScreen(name) {
  $$('.screen').forEach(screen => screen.classList.toggle('hidden', screen.id !== `${name}-screen`));
  $$('.tab').forEach(tab => tab.classList.toggle('active', tab.dataset.screen === name));
  window.scrollTo({ top: 0, behavior: 'smooth' });
}

function showSheet(id) { $('#sheet-backdrop').classList.remove('hidden'); $(id).classList.remove('hidden'); }
function closeSheets() { $('#sheet-backdrop').classList.add('hidden'); $$('.sheet').forEach(sheet => sheet.classList.add('hidden')); }
function toast(message) { const el = $('#toast'); el.textContent = message; el.classList.add('show'); setTimeout(() => el.classList.remove('show'), 2200); }

$$('[data-screen]').forEach(button => button.addEventListener('click', () => showScreen(button.dataset.screen)));
$('#add-btn').addEventListener('click', () => showSheet('#expense-sheet'));
$('#settle-btn').addEventListener('click', () => showSheet('#settle-sheet'));
$('#close-sheet').addEventListener('click', closeSheets);
$$('.close-settle').forEach(button => button.addEventListener('click', closeSheets));
$('#sheet-backdrop').addEventListener('click', closeSheets);
$$('.choice, .category').forEach(button => button.addEventListener('click', () => { const group = button.parentElement; group.querySelectorAll('button').forEach(item => item.classList.remove('selected')); button.classList.add('selected'); }));
$('#save-expense').addEventListener('click', () => {
  const amount = parseFloat($('#amount').value) || 0;
  if (!amount) { toast('先输入一个金额吧'); return; }
  const category = document.querySelector('.category.selected')?.dataset.category || '其他';
  expenses.unshift({ title: $('#note').value.trim() || category, meta: `${category} · 刚刚`, amount, payer: document.querySelector('.payer-grid .selected')?.dataset.value === '对方' ? '小红' : '小明', icon: category === '交通' ? '↗' : category === '娱乐' ? '◇' : '◒', tone: 'terra' });
  renderActivity(); renderBills(); closeSheets(); $('#amount').value = '0.00'; $('#note').value = ''; toast('已记下，这笔一起生活的记录');
});
$('#confirm-settle').addEventListener('click', () => { closeSheets(); $('.settlement-panel h2').textContent = '今天已平账'; $('.settlement-amount').textContent = '一起生活，刚刚好'; $('#settle-btn').textContent = '已完成'; $('#settle-btn').disabled = true; toast('已平账，原始记录已保留'); });
$$('.filter').forEach(button => button.addEventListener('click', () => { $$('.filter').forEach(item => item.classList.remove('active')); button.classList.add('active'); toast(`${button.textContent}账单`); }));
renderActivity(); renderBills();
