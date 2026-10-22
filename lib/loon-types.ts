export type Production = {
  id: string; theater_id: string; season_id: string; venue_id: string | null; title: string;
  full_description: string; opening_date: string; closing_date: string;
  runtime: string; runtime_minutes: number; rating: string; is_demo: boolean;
  content_warnings: string[]; series: string | null; is_aea: boolean | null;
  aea_tier: string | null; rehearsal_start: string | null;
  scripts?: {musical: boolean; composer: string | null} | null;
  import_metadata?: {test_seed?: string; script_musical?: boolean; script_composer?: string};
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

export const personTypes = ['Cast', 'Creative', 'Staff', 'Crew', 'Other'] as const;
export type PersonType = typeof personTypes[number];
export type Person = {
  id: string; theater_id: string; source_key: string; display_name: string; first_name: string;
  last_name: string; known_as: string; person_types: PersonType[]; job_title: string;
  departments: string[]; area: string; hometown: string; bio: string; favorite_shakespeare: string;
  portfolio_url: string; unions: string[]; intern: boolean; is_demo: boolean; updated_at: string;
  profile_avatar?: string | null; intake_headshot?: boolean;
  headshot_kind: 'demo' | 'uploaded' | null; headshot_path: string | null;
  headshot_source_url: string | null; headshot_credit: string | null;
  headshot_license: string | null; headshot_license_url: string | null;
};
export type ProductionCredit = {id: string; theater_id: string; production_id: string; person_id: string; role: string; credit_type: PersonType; billing_order: number};
export type PersonDraft = Pick<Person, 'display_name' | 'first_name' | 'last_name' | 'known_as' | 'person_types' | 'job_title' | 'departments' | 'area' | 'hometown' | 'bio' | 'favorite_shakespeare' | 'unions' | 'intern' | 'portfolio_url'>;

export type RehearsalCall = {event_id: string; theater_id: string; production_id: string; work: string; act: string; scene: string; location: string};
export type CallCast = {event_id: string; person_id: string; theater_id: string; production_id: string};
export type CallDraft = {id: string; production_id: string; expected_updated_at: string | null; start: string; end: string; venue_id: string | null; work: string; act: string; scene: string; location: string; notes: string; person_ids: string[]; call_status: 'Published' | 'Canceled'};
export type SavedCall = {event: CalendarEvent; call: RehearsalCall; cast: CallCast[]};
