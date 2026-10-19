'use client';
import {useState} from 'react';
import {Check, X} from 'lucide-react';
import {activityCategories, type ActivityCategory, type ActivityDraft, type CalendarEvent, type Production, type Venue} from '../lib/loon-types';
import {zoneLabel,toUTC, wallTime} from '../lib/calendar';
type Props = {event?: CalendarEvent; day: string; productionId: string; productions: Production[]; venues: Venue[]; onSave: (draft: ActivityDraft) => Promise<void>; onClose: () => void};
export default function CalendarActivityDialog({event, day, productionId, productions, venues, onSave, onClose}: Props) {
  const [form, setForm] = useState({production_id: event?.production_id || productionId || productions[0]?.id || '', title: event?.title || '', category: (event?.category || 'Strike') as ActivityCategory, start: event ? wallTime(event.start) : `${day}T09:00`, end: event ? wallTime(event.end) : `${day}T17:00`, venue_id: event?.venue_id || '', event_details: event?.event_details || '', call_status: event?.call_status || 'Draft'});
  const [saving, setSaving] = useState(false), [error, setError] = useState('');
  async function submit(e: React.FormEvent) {
    e.preventDefault(); if (saving) return;
    setSaving(true); setError('');
    try {
      const start = toUTC(form.start), end = toUTC(form.end);
      if (end <= start) throw Error('End must be after start.');
      const title = form.title.trim(); if (!title) throw Error('Enter an activity title.');
      await onSave({...form, title, start, end, venue_id: form.venue_id || null});
      onClose();
    } catch (error) {setError((error as Error).message);} finally {setSaving(false);}
  }
  return <div className="modal-shade"><section className="modal activity-modal" role="dialog" aria-modal="true" aria-labelledby="activity-title"><button className="modal-close" disabled={saving} aria-label="Close activity" onClick={onClose}><X/></button><div className="eyebrow">MASTER CALENDAR</div><h2 id="activity-title">{event ? 'Edit activity' : 'Add activity'}</h2><p>Schedule strike, load-in, rehearsals, tech, meetings, and other production work.</p><form onSubmit={submit}>
    <label>Production<select required value={form.production_id} onChange={e => setForm({...form, production_id: e.target.value})}>{productions.map(p => <option value={p.id} key={p.id}>{p.title}</option>)}</select></label>
    <label>Activity type<select value={form.category} onChange={e => setForm({...form, category: e.target.value as ActivityCategory})}>{activityCategories.map(category => <option key={category}>{category}</option>)}</select></label>
    <label>Title<input required maxLength={200} placeholder="e.g. Titus scenic strike" value={form.title} onChange={e => setForm({...form, title: e.target.value})}/></label>
    <label>Start <small>{zoneLabel()} time</small><input type="datetime-local" required value={form.start} onInput={e => setForm({...form, start: e.currentTarget.value})} onChange={e => setForm({...form, start: e.target.value})}/></label>
    <label>End <small>{zoneLabel()} time</small><input type="datetime-local" required value={form.end} onInput={e => setForm({...form, end: e.currentTarget.value})} onChange={e => setForm({...form, end: e.target.value})}/></label>
    <p className="form-help">An activity can span multiple days. An end at midnight does not include the following day.</p>
    <label>Book a venue<select value={form.venue_id} onChange={e => setForm({...form, venue_id: e.target.value})}><option value="">No venue booking</option>{venues.map(venue => <option value={venue.id} key={venue.id}>{venue.name}</option>)}</select></label>
    <p className="form-help">Choosing a venue reserves it for the entire activity. Overlapping bookings are rejected.</p>
    <label>Notes<textarea value={form.event_details} onChange={e => setForm({...form, event_details: e.target.value})}/></label>
    <label>Publication state<select value={form.call_status} onChange={e => setForm({...form, call_status: e.target.value as CalendarEvent['call_status']})}>{['Draft','Published','Canceled'].map(state => <option key={state}>{state}</option>)}</select></label>
    {error && <div className="error" role="alert">{error}</div>}
    <div className="modal-actions"><button className="secondary" type="button" disabled={saving} onClick={onClose}>Cancel</button><button className="primary" disabled={saving}>{saving ? 'Saving…' : 'Save activity'}<Check size={16}/></button></div>
  </form></section></div>;
}
