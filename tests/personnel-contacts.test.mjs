import test from 'node:test';
import assert from 'node:assert/strict';
import {cleanPersonnelContact,emptyContact,canManagePersonnelContacts} from '../lib/personnel-contacts.ts';
test('contact fields are optional and preserve postal codes and international phones as text',()=>{
 const contact=cleanPersonnelContact({...emptyContact,zip:' 02108-1234 ',emergency_contact_phone:'+44 (0)20 1234 5678',email:' person@example.invalid ',address_line_2:' Apt 2B '});
 assert.equal(contact.zip,'02108-1234');assert.equal(contact.emergency_contact_phone,'+44 (0)20 1234 5678');assert.equal(contact.address_line_2,'Apt 2B');assert.equal(contact.email,'person@example.invalid');assert.ok(!('revision' in contact));assert.equal(contact.city,'');
});
test('contact validation rejects malformed email and overlong fields',()=>{
 assert.throws(()=>cleanPersonnelContact({...emptyContact,email:'not an email'}),/valid email/);
 assert.throws(()=>cleanPersonnelContact({...emptyContact,address_line_1:'a'.repeat(301)}),/too long/);
 assert.doesNotThrow(()=>cleanPersonnelContact(emptyContact));
});
test('only administrators or active stage management with stage edit permission see contacts',()=>{
 const ctx=(role,permission='edit',active=true)=>({admin:false,member:{roles:[role],active},permissions:{stage:permission}});
 for(const role of ['Stage Manager','Assistant Stage Manager','Company Manager'])assert.equal(canManagePersonnelContacts(ctx(role)),true);
 for(const role of ['Cast','Guest','Director','Marketing','Box Office','Production','Production Manager'])assert.equal(canManagePersonnelContacts(ctx(role)),false);
 assert.equal(canManagePersonnelContacts(ctx('Stage Manager','none')),false);assert.equal(canManagePersonnelContacts(ctx('Stage Manager','view')),false);assert.equal(canManagePersonnelContacts(ctx('Stage Manager','edit',false)),false);assert.equal(canManagePersonnelContacts({...ctx('Cast'),admin:true}),true);assert.equal(canManagePersonnelContacts(null),false);
});
