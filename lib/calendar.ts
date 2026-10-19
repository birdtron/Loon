import type {CalendarEvent, Production} from './loon-types';
export let calendarZone = 'America/New_York';
export let timeFormat='12';
export function configureCalendar(zone:string,format='12'){new Intl.DateTimeFormat('en-US',{timeZone:zone});calendarZone=zone;timeFormat=format;}
export function zoneLabel(){return calendarZone.replaceAll('_',' ');}
export function localDay(value: string | Date) {
  const parts = new Intl.DateTimeFormat('en-CA', {timeZone: calendarZone, year: 'numeric', month: '2-digit', day: '2-digit'}).formatToParts(new Date(value));
  const part = (type: string) => parts.find(p => p.type === type)!.value;
  return `${part('year')}-${part('month')}-${part('day')}`;
}
export function addDays(day: string, count: number) {
  const date = new Date(`${day}T12:00:00Z`);
  date.setUTCDate(date.getUTCDate() + count);
  return date.toISOString().slice(0, 10);
}
export function dayDifference(from: string, to: string) {
  return Math.round((Date.parse(`${to}T12:00:00Z`) - Date.parse(`${from}T12:00:00Z`)) / 86400000);
}
export function displayDay(day: string, options: Intl.DateTimeFormatOptions = {month: 'short', day: 'numeric'}) {
  return new Intl.DateTimeFormat('en-US', {timeZone: 'UTC', ...options}).format(new Date(`${day}T12:00:00Z`));
}
export function displayTime(value: string) {
  return new Intl.DateTimeFormat('en-US', {timeZone: calendarZone, hour: 'numeric', minute: '2-digit',hour12:timeFormat==='12'}).format(new Date(value));
}
export type CalendarItem = {id: string; productionId: string; label: string; category: string; startDay: string; endDay: string; event?: CalendarEvent};
export function calendarItems(productions: Production[], events: CalendarEvent[]): CalendarItem[] {
  return [
    ...productions.map(p => ({id: `run-${p.id}`, productionId: p.id, label: `${p.title} · Performance run`, category: 'Performance run', startDay: p.opening_date, endDay: p.closing_date})),
    ...events.map(event => ({id: event.id, productionId: event.production_id, label: event.category === 'Performance' ? `${displayTime(event.start)} · ${event.title}` : event.title, category: event.category, startDay: localDay(event.start), endDay: localDay(new Date(new Date(event.end).getTime() - 1)), event})),
  ];
}
export function matchesProduction(p: Production, productionId: string, series: string) {
  return (!productionId || p.id === productionId) && (!series || (p.series || 'Unassigned') === series);
}
export type WeekSegment = {item: CalendarItem; column: number; span: number; lane: number; continuesBefore: boolean; continuesAfter: boolean};
// Each week's bars have their own non-overlapping lanes. End dates are inclusive.
export function weekSegments(items: CalendarItem[], weekStart: string, visibleEnd: string): WeekSegment[] {
  const weekEnd = addDays(weekStart, 6) < visibleEnd ? addDays(weekStart, 6) : visibleEnd;
  const visible = items.filter(item => item.startDay <= weekEnd && item.endDay >= weekStart)
    .sort((a, b) => (a.category === 'Performance run' ? 0 : 1) - (b.category === 'Performance run' ? 0 : 1) || a.startDay.localeCompare(b.startDay) || b.endDay.localeCompare(a.endDay) || a.id.localeCompare(b.id));
  const occupied: number[] = [];
  return visible.map(item => {
    const start = item.startDay > weekStart ? item.startDay : weekStart;
    const end = item.endDay < weekEnd ? item.endDay : weekEnd;
    const column = dayDifference(weekStart, start) + 1;
    const span = dayDifference(start, end) + 1;
    let lane = occupied.findIndex(last => last < column);
    if (lane < 0) lane = occupied.length;
    occupied[lane] = column + span - 1;
    return {item, column, span, lane, continuesBefore: item.startDay < weekStart, continuesAfter: item.endDay > weekEnd};
  });
}
export function wallTime(iso: string) {
  const parts = new Intl.DateTimeFormat('en-CA', {timeZone: calendarZone, year:'numeric', month:'2-digit', day:'2-digit', hour:'2-digit', minute:'2-digit', hourCycle:'h23'}).formatToParts(new Date(iso));
  const part = (key: string) => parts.find(value => value.type === key)?.value;
  return `${part('year')}-${part('month')}-${part('day')}T${part('hour')}:${part('minute')}`;
}
export function toUTC(value: string) {
  const target = new Date(value + 'Z').getTime();
  if (!Number.isFinite(target)) throw Error('Enter a valid date and time.');
  let ms = target;
  for (let i = 0; i < 3; i++) {
    const delta = target - new Date(wallTime(new Date(ms).toISOString()) + 'Z').getTime();
    if (!delta) return new Date(ms).toISOString();
    ms += delta;
  }
  throw Error('That local time does not exist because of daylight saving time.');
}
