import test from 'node:test';
import assert from 'node:assert/strict';
import {parseProductionCSV,blankProductionCSV} from '../lib/imports.ts';
const header='title,season_name,opening_date,closing_date';
test('Google CSV handles BOM, CRLF, quoted commas, newlines and escaped quotes',()=>{
 const rows=parseProductionCSV('\uFEFF'+header+',full_description\r\n"Hamlet, Prince",26-27 Season,2027-01-01,2027-02-01,"Act 1\nA ""quote"""\r\n');
 assert.equal(rows[0].title,'Hamlet, Prince');assert.equal(rows[0].full_description,'Act 1\nA "quote"');
});
test('rejects malformed, legacy, duplicate, unknown and missing headers',()=>{
 for(const s of [header+'\n"broken',header+'\n"a"x,b,c,d','title,title\na,b','post_title\na',header+',oops\na,b,c,d,e',header+'\na,b,c'])assert.throws(()=>parseProductionCSV(s));
});
test('rejects blank, oversized and over-limit files',()=>{
 assert.throws(()=>parseProductionCSV(blankProductionCSV()));assert.throws(()=>parseProductionCSV('x'.repeat(1000001)));
 assert.throws(()=>parseProductionCSV(header+'\n'+Array(101).fill('New,Season,2027-01-01,2027-01-02').join('\n')));
});
test('blank template can be filled with only required data, blank lines are ignored',()=>{
 const csv=blankProductionCSV();const cols=csv.trim().split(',');const row=cols.map(c=>({title:'New Show',season_name:'26-27 Season',opening_date:'2027-01-01',closing_date:'2027-02-01',script_playwright:'A. Writer'}[c]||''));
 const rows=parseProductionCSV(csv+row.join(',')+'\n\n');assert.equal(rows.length,1);assert.equal(rows[0].script_playwright,'A. Writer');
});
