// Hugrún audio review — light client-side handlers for Approve / Re-record / bulk approve.

document.querySelectorAll('button.approve').forEach(btn => {
  btn.addEventListener('click', async (e) => {
    const row = e.target.closest('article.row');
    const key = row.dataset.key;
    const notes = row.querySelector('textarea').value;
    const res = await fetch(`/approve/${encodeURIComponent(key)}`, {
      method: 'POST',
      headers: {'content-type': 'application/json'},
      body: JSON.stringify({notes}),
    });
    if (!res.ok) {
      alert(`Approve failed: ${await res.text()}`);
      return;
    }
    row.classList.remove('state-unreviewed', 'state-stale', 'state-rerecord');
    row.classList.add('state-approved');
    const badge = row.querySelector('.badge');
    if (badge) badge.textContent = 'approved';
    // Auto-advance to next unreviewed.
    const next = Array.from(document.querySelectorAll('article.row.state-unreviewed'))[0];
    if (next) next.scrollIntoView({behavior: 'smooth', block: 'center'});
  });
});

document.querySelectorAll('button.rerecord').forEach(btn => {
  btn.addEventListener('click', async (e) => {
    const row = e.target.closest('article.row');
    const key = row.dataset.key;
    const issue = prompt(`What's wrong with ${key}? (e.g. "ð sounds like d")`);
    if (!issue) return;
    const res = await fetch(`/rerecord/${encodeURIComponent(key)}`, {
      method: 'POST',
      headers: {'content-type': 'application/json'},
      body: JSON.stringify({issue}),
    });
    if (!res.ok) {
      alert(`Re-record failed: ${await res.text()}`);
      return;
    }
    row.classList.remove('state-unreviewed', 'state-approved', 'state-stale');
    row.classList.add('state-rerecord');
    const badge = row.querySelector('.badge');
    if (badge) badge.textContent = 're-record queued';
  });
});

const bulk = document.getElementById('bulk-approve');
if (bulk) {
  bulk.addEventListener('click', async () => {
    const unreviewed = Array.from(document.querySelectorAll('article.row.state-unreviewed'));
    if (!confirm(`Approve all ${unreviewed.length} unreviewed clips? Reviewer: Jon`)) return;
    for (const row of unreviewed) {
      const key = row.dataset.key;
      const notes = row.querySelector('textarea').value || '';
      try {
        const res = await fetch(`/approve/${encodeURIComponent(key)}`, {
          method: 'POST',
          headers: {'content-type': 'application/json'},
          body: JSON.stringify({notes}),
        });
        if (res.ok) {
          row.classList.remove('state-unreviewed');
          row.classList.add('state-approved');
          const badge = row.querySelector('.badge');
          if (badge) badge.textContent = 'approved';
        }
      } catch (e) {
        console.error(`Bulk approve failed for ${key}:`, e);
      }
    }
    location.reload();
  });
}
