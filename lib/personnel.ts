import type {Person, ProductionCredit} from './loon-types';
export function personName(person: Pick<Person, 'known_as' | 'display_name'>) { return person.known_as || person.display_name; }
export function initials(name: string) { return name.trim().split(/\s+/).slice(0,2).map(part=>part[0]).join('').toUpperCase(); }
export function splitLabels(value: string) {return [...new Set(value.split(/[,|]/).map(label=>label.trim()).filter(Boolean))];}
export function filterPeople(people: Person[], credits: ProductionCredit[], filters: {query: string; type: string; production: string; department: string}) {
  const query=filters.query.trim().toLocaleLowerCase();
  return people.filter(person=> {
    const assignments=credits.filter(credit=>credit.person_id===person.id);
    return (!filters.type || person.person_types.includes(filters.type as Person['person_types'][number]))
      && (!filters.production || assignments.some(credit=>credit.production_id===filters.production))
      && (!filters.department || person.departments.includes(filters.department))
      && (!query || [person.display_name,person.known_as,person.job_title,...person.departments,...assignments.map(credit=>credit.role)].join(' ').toLocaleLowerCase().includes(query));
  }).sort((a,b)=>personName(a).localeCompare(personName(b)));
}
export function validateHeadshot(file: {size: number; type: string}) {
  if (!['image/jpeg','image/png','image/webp'].includes(file.type)) throw Error('Choose a JPG, PNG, or WebP image.');
  if (!file.size || file.size>4*1024*1024) throw Error('Choose an image smaller than 4 MB.');
}
