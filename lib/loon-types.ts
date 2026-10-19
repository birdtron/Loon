export type Production = {
  id: string; theater_id: string; venue_id: string | null; title: string;
  full_description: string; opening_date: string; closing_date: string;
  runtime: string; runtime_minutes: number; rating: string;
  content_warnings: string[]; series: string | null; is_aea: boolean | null;
  aea_tier: string | null; rehearsal_start: string | null;
  venues: {name: string} | null; seasons: {name: string} | null;
};
export const activityCategories = ['Rehearsal', 'Tech', 'Load-in', 'Strike', 'Meeting', 'Other'] as const;
export type ActivityCategory = typeof activityCategories[number];
export type CalendarEvent = {
  id: string; production_id: string; theater_id: string; venue_id: string | null;
  title: string; category: 'Performance' | ActivityCategory; start: string; end: string;
  accessibility: string[]; is_special_event: boolean; event_details: string;
  call_status: 'Draft' | 'Published' | 'Canceled'; updated_at: string;
};
export type Venue = {id: string; name: string; capacity: number; stage_style: string; description: string};
export type ActivityDraft = Pick<CalendarEvent, 'production_id' | 'venue_id' | 'title' | 'start' | 'end' | 'event_details' | 'call_status'> & {category: ActivityCategory};
