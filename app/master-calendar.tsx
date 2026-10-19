'use client';
import {useState} from 'react';
import {ArrowLeft, ChevronRight, Plus, Search, Pencil} from 'lucide-react';
import type {CalendarEvent, Production} from '../lib/loon-types';
import {addDays, calendarItems, displayDay, displayTime, localDay, matchesProduction, weekSegments} from '../lib/calendar';

type Props = {
  productions: Production[]; events: CalendarEvent[];
  onEdit: (event: CalendarEvent) => void;
  onOpenProduction: (id: string) => void;
  onAdd: (day: string, productionId: string) => void;
};
export default function MasterCalendar({productions, events, onEdit, onOpenProduction, onAdd}: Props) {
  const [view, setView] = useState('calendar');
  const [start, setStart] = useState(() => localDay(new Date()));
  const [productionId, setProductionId] = useState('');
  const [series, setSeries] = useState('');
  const [query, setQuery] = useState('');
  const end = addDays(start, 29), today = localDay(new Date());
  const seriesOptions = [...new Set(productions.map(p => p.series || 'Unassigned'))].sort();
  const availableProductions = productions.filter(p => !series || (p.series || 'Unassigned') === series);
  const filteredProductions = productions.filter(p => matchesProduction(p, productionId, series));
  const ids = new Set(filteredProductions.map(p => p.id));
  const filteredEvents = events.filter(e => ids.has(e.production_id) && `${e.title} ${e.category} ${e.event_details || ''}`.toLowerCase().includes(query.toLowerCase()));
  const items = calendarItems(filteredProductions, filteredEvents).filter(item => !query || `${item.label} ${item.category} ${item.event?.event_details || ''}`.toLowerCase().includes(query.toLowerCase()));
  const rangeCount = items.filter(item => item.startDay <= end && item.endDay >= start).length;
  const activeFilters = Boolean(productionId || series || query);
  function changeSeries(value: string) {
    setSeries(value);
    if (productionId && !productions.some(p => p.id === productionId && (!value || (p.series || 'Unassigned') === value))) setProductionId('');
  }
  return <section className="master-calendar" aria-label="Master calendar">
    <div className="calendar-filters">
      <label>View<select value={view} onChange={e => setView(e.target.value)}><option value="calendar">30-day calendar</option><option value="list">List view</option></select></label>
      <label>Production series<select value={series} onChange={e => changeSeries(e.target.value)}><option value="">All series</option>{seriesOptions.map(value => <option key={value}>{value}</option>)}</select></label>
      <label>Production<select value={productionId} onChange={e => setProductionId(e.target.value)}><option value="">All productions</option>{availableProductions.map(p => <option key={p.id} value={p.id}>{p.title}</option>)}</select></label>
      <button className="primary" onClick={() => onAdd(start, productionId || (filteredProductions.length === 1 ? filteredProductions[0].id : ''))}><Plus size={16}/>Add activity</button>
    </div>
    <div className="calendar-navigation">
      {view === 'calendar' ? <>
        <div className="calendar-range"><button className="calendar-nav-button" aria-label="Previous 30 days" onClick={() => setStart(addDays(start, -30))}><ArrowLeft size={17}/></button><h2>{displayDay(start)} — {displayDay(end, {month: 'short', day: 'numeric', year: 'numeric'})}</h2><button className="calendar-nav-button" aria-label="Next 30 days" onClick={() => setStart(addDays(start, 30))}><ChevronRight size={19}/></button></div>
        <button className="secondary" onClick={() => setStart(today)}>Today</button>
        <label className="calendar-date"><span className="sr-only">Start date</span><input aria-label="Start date" type="date" required value={start} onInput={e => {if (e.currentTarget.value) setStart(e.currentTarget.value);}} onChange={e => {if (e.target.value) setStart(e.target.value);}}/></label>
      </> : <h2>Scheduled events <span className="muted">{filteredEvents.length} · All dates</span></h2>}
      <label className="search"><Search size={16}/><input aria-label="Search calendar" placeholder="Search events…" value={query} onChange={e => setQuery(e.target.value)}/></label>
      {activeFilters && <button className="text-button calendar-clear" onClick={() => {setProductionId(''); setSeries(''); setQuery('');}}>Clear filters</button>}
    </div>
    {view === 'calendar' ? <>
      <div className="calendar-legend"><span data-kind="Performance run">Performance run</span><span data-kind="Performance">Performance</span><span data-kind="Rehearsal">Rehearsal</span><span data-kind="Tech">Tech / Load-in</span><span data-kind="Strike">Strike</span><span data-kind="Meeting">Meeting / Other</span></div>
      <p className="calendar-caption">30 days · Eastern time. Run bars show opening through closing; timed events show actual calls. Select a run to open its production or an event to edit it.</p>
      <div className="calendar-scroll" tabIndex={0} aria-label="30-day calendar, scroll horizontally on small screens">
        <div className="calendar-grid">
          <div className="calendar-weekdays">{Array.from({length: 7}, (_, index) => <div key={index}>{displayDay(addDays(start, index), {weekday: 'short'})}</div>)}</div>
          {Array.from({length: 5}, (_, week) => {
            const weekStart = addDays(start, week * 7);
            const segments = weekSegments(items, weekStart, end);
            const lanes = Math.max(3, ...segments.map(segment => segment.lane + 1));
            return <section key={weekStart} className="calendar-week" aria-label={`Week starting ${displayDay(weekStart)}`} style={{minHeight: 42 + lanes * 31 + 14}}>
              <div className="calendar-day-grid">{Array.from({length: 7}, (_, day) => {
                const date = addDays(weekStart, day), outside = date > end;
                return <div key={date} className={`calendar-day${date === today ? ' is-today' : ''}${outside ? ' outside-range' : ''}`}>
                  {!outside && <div className="calendar-day-heading"><time dateTime={date}>{displayDay(date, {month: 'short', day: 'numeric'})}</time><button aria-label={`Add activity on ${displayDay(date, {month: 'long', day: 'numeric', year: 'numeric'})}`} onClick={() => onAdd(date, productionId || (filteredProductions.length === 1 ? filteredProductions[0].id : ''))}><Plus size={13}/></button></div>}
                </div>;
              })}</div>
              <div className="calendar-bars">{segments.map(({item, column, span, lane, continuesBefore, continuesAfter}) => <button key={item.id} className={`calendar-bar${item.event?.call_status === 'Canceled' ? ' is-canceled' : ''}${continuesBefore ? ' continues-before' : ''}${continuesAfter ? ' continues-after' : ''}`} data-kind={item.category} style={{gridColumn: `${column} / span ${span}`, gridRow: lane + 1}} title={`${item.label} · ${item.category} · ${displayDay(item.startDay)} – ${displayDay(item.endDay)}${item.event ? ` · ${item.event.call_status}` : ''}`} aria-label={`${item.label}, ${item.category}, ${displayDay(item.startDay)} to ${displayDay(item.endDay)}${item.event?.call_status === 'Canceled' ? ', canceled' : ''}`} onClick={() => item.event ? onEdit(item.event) : onOpenProduction(item.productionId)}>{continuesBefore && '‹ '}{item.event?.call_status === 'Canceled' && 'Canceled · '}{item.label}{continuesAfter && ' ›'}</button>)}</div>
            </section>;
          })}
        </div>
      </div>
      {rangeCount === 0 && <div className="calendar-empty" role="status">No runs or events match this 30-day range. Change the dates or clear your filters.</div>}
    </> : <div className="table-wrap"><table><thead><tr><th>Date & time <small>ET</small></th><th>Production / Event</th><th>Type</th><th>State</th><th><span className="sr-only">Edit</span></th></tr></thead><tbody>{[...filteredEvents].sort((a,b) => a.start.localeCompare(b.start)).map(event => <tr key={event.id} className={event.call_status === 'Canceled' ? 'canceled' : ''}><td><strong>{displayDay(localDay(event.start), {weekday: 'short', month: 'short', day: 'numeric', year: 'numeric'})}</strong><span>{displayTime(event.start)} — {localDay(event.start) !== localDay(event.end) ? `${displayDay(localDay(event.end))}, ` : ''}{displayTime(event.end)}</span></td><td><strong>{productions.find(p => p.id === event.production_id)?.title}</strong><p className="event-note">{event.title}</p>{event.event_details && <p className="event-note">{event.event_details}</p>}{event.is_special_event && <span className="event-tag">Special event</span>}{event.accessibility.length > 0 && <div className="table-tags">{event.accessibility.map(label => <span className="access-tag" key={label}>{label}</span>)}</div>}</td><td><span className="calendar-type" data-kind={event.category}>{event.category}</span></td><td><span className={`pill state-${event.call_status}`}>{event.call_status}</span></td><td><button className="edit-button" onClick={() => onEdit(event)}><Pencil size={14}/>Edit</button></td></tr>)}</tbody></table>{filteredEvents.length === 0 && <div className="empty" role="status">No scheduled events match your filters.</div>}</div>}
  </section>;
}
