export const productionHeaders=['title','import_status','full_description','hero_image_url','season_name','production_status','series_name','script_playwright','script_musical','script_composer','rating_name','content_warnings','runtime','opening_date','closing_date','venue_name','program_file_url','sponsor_names','school_trip_sponsor_names','runtime_minutes'];
export type ImportRow=Record<string,string>;
export type ImportPreview={fingerprint:string;rows:{row:number;title:string;season:string;venue:string;opening:string;closing:string;script:string;warnings:string[]}[];created?:number};
// Strict CSV parsing preserves quoted commas, newlines and escaped quotes.
export function parseProductionCSV(source:string):ImportRow[]{
 if(source.length>1_000_000)throw Error('Choose a CSV smaller than 1 MB.');
 const text=source.replace(/^\uFEFF/,'');const grid:string[][]=[];let row:string[]=[],cell='',quoted=false,closed=false;
 for(let i=0;i<text.length;i++){const c=text[i];if(quoted){if(c==='"'){if(text[i+1]==='"'){cell+='"';i++;}else{quoted=false;closed=true;}}else cell+=c;}else if(c==='"'){if(cell||closed)throw Error('Unexpected quote in CSV. Export the Data tab as CSV again.');quoted=true;}else if(c===','||c==='\n'||c==='\r'){row.push(cell);cell='';closed=false;if(c!==','){grid.push(row);row=[];if(c==='\r'&&text[i+1]==='\n')i++;}}else{if(closed)throw Error('Unexpected text after a quoted CSV value.');cell+=c;}}
 if(quoted)throw Error('CSV has an unclosed quote.');if(cell||row.length||closed){row.push(cell);grid.push(row);}
 const headers=grid.shift()?.map(h=>h.trim())||[];
 if(!headers.length||headers.some(h=>!h)||new Set(headers).size!==headers.length)throw Error('CSV headers must be present and unique. Export only the Data tab.');
 const unknown=headers.filter(h=>!productionHeaders.includes(h));if(unknown.length)throw Error(`Unrecognized columns: ${unknown.join(', ')}. Use the production template.`);
 for(const key of ['title','season_name','opening_date','closing_date'])if(!headers.includes(key))throw Error(`Missing column: ${key}.`);
 const rows=grid.filter(r=>r.some(v=>v.trim())).map((values,i)=>{if(values.length!==headers.length)throw Error(`Data row ${i+2} has ${values.length} values; expected ${headers.length}.`);return Object.fromEntries(headers.map((h,j)=>[h,values[j].trim()]));});
 if(!rows.length||rows.length>100)throw Error('Include between 1 and 100 productions.');return rows;
}
export function blankProductionCSV(){return productionHeaders.join(',')+'\r\n';}
