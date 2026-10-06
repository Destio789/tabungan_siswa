-- Jalankan di SQL Editor setelah schema.sql, idealnya proyek pengujian.
-- Seluruh data uji di-ROLLBACK. Jika tes gagal, jalankan ROLLBACK.
begin;
insert into public.profiles(id,email,name,role,class_name) values
('10000000-0000-0000-0000-000000000001','rls-admin@example.test','Admin Uji','admin',''),
('10000000-0000-0000-0000-000000000002','rls-teacher@example.test','Wali A','teacher','VII A'),
('10000000-0000-0000-0000-000000000003','rls-teacher-b@example.test','Wali B','teacher','VII B'),
('10000000-0000-0000-0000-000000000004','rls-student@example.test','Siswa A','student','VII A'),
('10000000-0000-0000-0000-000000000005','rls-student-b@example.test','Siswa B','student','VII B');
insert into public.students(id,nis,profile_id,teacher_id,class_name) values
('20000000-0000-0000-0000-000000000001','__RLS_TEST_A__','10000000-0000-0000-0000-000000000004','10000000-0000-0000-0000-000000000002','VII A'),
('20000000-0000-0000-0000-000000000002','__RLS_TEST_B__','10000000-0000-0000-0000-000000000005','10000000-0000-0000-0000-000000000003','VII B');
select set_config('request.jwt.claims','{"sub":"90000000-0000-0000-0000-000000000002","email":"rls-teacher@example.test","role":"authenticated"}',true);
set local role authenticated;
do $$
begin
 if public.my_role() is distinct from 'teacher' then raise exception 'FAIL: role wali kelas'; end if;
 if not public.can_access_student('20000000-0000-0000-0000-000000000001') or public.can_access_student('20000000-0000-0000-0000-000000000002') then raise exception 'FAIL: batas kelas'; end if;
 if exists(select 1 from public.students where id='20000000-0000-0000-0000-000000000002') then raise exception 'FAIL: RLS siswa kelas lain'; end if;
 begin
  perform public.record_transaction('20000000-0000-0000-0000-000000000002','deposit',1,now(),'Tes');
  raise exception 'FAIL: transaksi kelas lain diizinkan';
 exception when others then if sqlerrm like 'FAIL:%' then raise; end if; end;
 perform public.record_transaction('20000000-0000-0000-0000-000000000001','deposit',50000,now(),'Setoran');
 perform public.record_transaction('20000000-0000-0000-0000-000000000001','withdrawal',20000,now(),'Buku');
 begin
  perform public.record_transaction('20000000-0000-0000-0000-000000000001','withdrawal',40000,now(),'Buku');
  raise exception 'FAIL: saldo negatif diizinkan';
 exception when others then if sqlerrm like 'FAIL:%' then raise; end if; end;
 begin
  perform public.manage_member('rls-hacker@example.test','Hacker','admin','');
  raise exception 'FAIL: wali membuat admin';
 exception when others then if sqlerrm like 'FAIL:%' then raise; end if; end;
 begin
  perform public.import_students('[{"nis":"__RLS_DUP__","name":"A","class_name":"VII A","email":"rls-import@example.test"},{"nis":"__RLS_DUP__","name":"B","class_name":"VII A","email":"rls-import-b@example.test"}]'::jsonb,null);
  raise exception 'FAIL: impor duplikat diterima';
 exception when unique_violation then null; end;
 if exists(select 1 from public.profiles where email in ('rls-import@example.test','rls-import-b@example.test')) then raise exception 'FAIL: impor tidak atomik'; end if;
end $$;
reset role;
select set_config('request.jwt.claims','{"sub":"90000000-0000-0000-0000-000000000004","email":"rls-student@example.test","role":"authenticated"}',true);
set local role authenticated;
do $$
begin
 if public.my_role() is distinct from 'student' then raise exception 'FAIL: role siswa'; end if;
 if exists(select 1 from public.students where id='20000000-0000-0000-0000-000000000002') then raise exception 'FAIL: siswa melihat akun lain'; end if;
 begin
  perform public.record_transaction('20000000-0000-0000-0000-000000000001','deposit',1,now(),'Tes');
  raise exception 'FAIL: siswa menulis';
 exception when others then if sqlerrm like 'FAIL:%' then raise; end if; end;
 begin
  update public.profiles set role='admin' where email='rls-student@example.test';
  raise exception 'FAIL: siswa menaikkan role';
 exception when insufficient_privilege then null; end;
end $$;
reset role;
select set_config('request.jwt.claims','{"sub":"90000000-0000-0000-0000-000000000001","email":"rls-admin@example.test","role":"authenticated"}',true);
set local role authenticated;
do $$
declare tid uuid;
begin
 if not public.can_access_student('20000000-0000-0000-0000-000000000002') then raise exception 'FAIL: admin tidak dapat semua kelas'; end if;
 select id into tid from public.transactions where student_id='20000000-0000-0000-0000-000000000001' and kind='deposit';
 begin
  perform public.void_transaction(tid,'Salah input');
  raise exception 'FAIL: pembatalan membuat saldo negatif';
 exception when others then if sqlerrm like 'FAIL:%' then raise; end if; end;
 select id into tid from public.transactions where student_id='20000000-0000-0000-0000-000000000001' and kind='withdrawal';
 perform public.void_transaction(tid,'Salah input');
 if (select coalesce(sum(case when kind='deposit' then amount else -amount end),0) from public.transactions where student_id='20000000-0000-0000-0000-000000000001' and voided_at is null)<>50000 then raise exception 'FAIL: saldo pembatalan'; end if;
 perform public.set_member_active('10000000-0000-0000-0000-000000000004',false);
end $$;
reset role;
select set_config('request.jwt.claims','{"sub":"90000000-0000-0000-0000-000000000004","email":"rls-student@example.test","role":"authenticated"}',true);
set local role authenticated;
do $$ begin
 if public.my_profile_id() is not null or exists(select 1 from public.students) then raise exception 'FAIL: akun nonaktif masih punya akses'; end if;
end $$;
reset role;
rollback;
select 'PASS: RLS, role, impor atomik, saldo, pembatalan, dan akun nonaktif' as hasil;
