-- Jalankan sekali pada proyek Supabase baru melalui SQL Editor.
begin;
revoke create on schema public from public, anon, authenticated;
create table public.profiles (
 id uuid primary key default gen_random_uuid(), email text not null unique check(email=lower(email)),
 name text not null check(length(trim(name))>0), role text not null check(role in ('admin','teacher','student')),
 class_name text not null default '', active boolean not null default true, created_at timestamptz not null default now()
);
create table public.students (
 id uuid primary key default gen_random_uuid(), nis text not null unique check(length(trim(nis))>0),
 profile_id uuid not null unique references public.profiles(id), teacher_id uuid not null references public.profiles(id),
 class_name text not null check(length(trim(class_name))>0), created_at timestamptz not null default now()
);
create table public.transactions (
 id uuid primary key default gen_random_uuid(), student_id uuid not null references public.students(id),
 kind text not null check(kind in ('deposit','withdrawal')), amount bigint not null check(amount>0 and amount<=1000000000),
 occurred_at timestamptz not null, note text not null check(length(trim(note))>0), actor_id uuid not null references public.profiles(id),
 voided_at timestamptz, void_reason text, voided_by uuid references public.profiles(id), created_at timestamptz not null default now()
);
create index transactions_student on public.transactions(student_id);
create index students_teacher on public.students(teacher_id);
create function public.my_profile_id() returns uuid language sql stable security definer set search_path=public as $$
 select id from profiles where email=lower(auth.jwt()->>'email') and active and auth.uid() is not null
$$;
create function public.my_role() returns text language sql stable security definer set search_path=public as $$
 select role from profiles where id=public.my_profile_id()
$$;
create function public.can_access_student(sid uuid) returns boolean language sql stable security definer set search_path=public as $$
 select exists(select 1 from students s where s.id=sid and (public.my_role()='admin' or (public.my_role()='teacher' and s.teacher_id=public.my_profile_id()) or (public.my_role()='student' and s.profile_id=public.my_profile_id())))
$$;
alter table public.profiles enable row level security;
alter table public.students enable row level security;
alter table public.transactions enable row level security;
create policy profiles_read on public.profiles for select to authenticated using (
 id=public.my_profile_id() or public.my_role()='admin' or (public.my_role()='teacher' and exists(select 1 from students s where s.profile_id=profiles.id and s.teacher_id=public.my_profile_id()))
);
create policy students_read on public.students for select to authenticated using(public.can_access_student(id));
create policy transactions_read on public.transactions for select to authenticated using(public.can_access_student(student_id));
revoke all on public.profiles,public.students,public.transactions from anon,authenticated;
grant select on public.profiles,public.students,public.transactions to authenticated;
-- Hanya RPC yang dapat menulis. Semua RPC mengecek role di server.
create function public.import_students(rows jsonb, assigned_teacher uuid default null) returns integer
language plpgsql security definer set search_path=public as $$
declare me uuid:=public.my_profile_id(); r text:=public.my_role(); t uuid; item jsonb; pid uuid; total integer:=0; mail text;
begin
 if r is null or r not in ('admin','teacher') then raise exception 'Akses ditolak'; end if;
 if rows is null or jsonb_typeof(rows)<>'array' or jsonb_array_length(rows)<1 or jsonb_array_length(rows)>500 then raise exception 'Isi 1–500 siswa'; end if;
 t:=case when r='teacher' then me else coalesce(assigned_teacher,me) end;
 if not exists(select 1 from profiles where id=t and active and role in ('teacher','admin')) then raise exception 'Wali kelas tidak valid'; end if;
 for item in select value from jsonb_array_elements(rows) loop
 mail:=lower(trim(item->>'email'));
 if coalesce(trim(item->>'name'),'')='' or coalesce(trim(item->>'nis'),'')='' or coalesce(trim(item->>'class_name'),'')='' or mail is null or mail!~'^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$' then raise exception 'Data siswa tidak lengkap atau email tidak valid'; end if;
 insert into profiles(email,name,role,class_name) values(mail,trim(item->>'name'),'student',trim(item->>'class_name')) returning id into pid;
 insert into students(nis,profile_id,teacher_id,class_name) values(trim(item->>'nis'),pid,t,trim(item->>'class_name'));
 total:=total+1;
 end loop;
 return total;
end $$;
create function public.update_student(sid uuid, new_nis text, new_name text, new_class text, assigned_teacher uuid default null) returns void
language plpgsql security definer set search_path=public as $$
declare s students; r text:=public.my_role(); t uuid;
begin
 select * into s from students where id=sid for update;
 if s.id is null or r is null or r not in ('admin','teacher') or not public.can_access_student(sid) then raise exception 'Akses ditolak'; end if;
 if coalesce(trim(new_nis),'')='' or coalesce(trim(new_name),'')='' or coalesce(trim(new_class),'')='' then raise exception 'Lengkapi semua kolom'; end if;
 t:=case when r='admin' then coalesce(assigned_teacher,s.teacher_id) else s.teacher_id end;
 if not exists(select 1 from profiles where id=t and active and role in ('teacher','admin')) then raise exception 'Wali kelas tidak valid'; end if;
 update students set nis=trim(new_nis),class_name=trim(new_class),teacher_id=t where id=sid;
 update profiles set name=trim(new_name),class_name=trim(new_class) where id=s.profile_id;
end $$;
create function public.record_transaction(sid uuid, transaction_kind text, transaction_amount bigint, transaction_date timestamptz, description text) returns uuid
language plpgsql security definer set search_path=public as $$
declare s students; saldo bigint; tid uuid; r text:=public.my_role();
begin
 if r is null or r not in ('admin','teacher') then raise exception 'Siswa hanya boleh membaca'; end if;
 select * into s from students where id=sid for update;
 if s.id is null or not public.can_access_student(sid) then raise exception 'Akses siswa ditolak'; end if;
 if not exists(select 1 from profiles where id=s.profile_id and active) then raise exception 'Siswa dinonaktifkan'; end if;
 if transaction_kind not in ('deposit','withdrawal') or transaction_kind is null or transaction_amount is null or transaction_amount<1 or transaction_amount>1000000000 or transaction_date is null then raise exception 'Transaksi tidak valid'; end if;
 if transaction_kind='withdrawal' and coalesce(trim(description),'')='' then raise exception 'Keterangan pengeluaran wajib diisi'; end if;
 select coalesce(sum(case when kind='deposit' then amount else -amount end),0) into saldo from transactions where student_id=sid and voided_at is null;
 if transaction_kind='withdrawal' and saldo<transaction_amount then raise exception 'Saldo tidak mencukupi'; end if;
 insert into transactions(student_id,kind,amount,occurred_at,note,actor_id) values(sid,transaction_kind,transaction_amount,transaction_date,coalesce(nullif(trim(description),''),'Setoran tabungan'),public.my_profile_id()) returning id into tid;
 return tid;
end $$;
create function public.void_transaction(tid uuid, reason text) returns void language plpgsql security definer set search_path=public as $$
declare t transactions; saldo bigint;
begin
 if public.my_role() is distinct from 'admin' then raise exception 'Hanya admin dapat membatalkan transaksi'; end if;
 if coalesce(trim(reason),'')='' then raise exception 'Alasan pembatalan wajib diisi'; end if;
 select * into t from transactions where id=tid;
 if t.id is null then raise exception 'Transaksi tidak ditemukan'; end if;
 perform 1 from students where id=t.student_id for update;
 select * into t from transactions where id=tid for update;
 if t.voided_at is not null then raise exception 'Transaksi sudah dibatalkan'; end if;
 select coalesce(sum(case when kind='deposit' then amount else -amount end),0) into saldo from transactions where student_id=t.student_id and voided_at is null;
 if t.kind='deposit' and saldo<t.amount then raise exception 'Pembatalan setoran akan membuat saldo negatif'; end if;
 update transactions set voided_at=now(),void_reason=trim(reason),voided_by=public.my_profile_id() where id=tid;
end $$;
create function public.manage_member(member_email text, member_name text, member_role text, member_class text default '') returns uuid
language plpgsql security definer set search_path=public as $$
declare pid uuid; mail text:=lower(trim(member_email));
begin
 if public.my_role() is distinct from 'admin' then raise exception 'Hanya admin dapat mengelola pengguna'; end if;
 if member_role is null or member_role not in ('admin','teacher') or coalesce(trim(member_name),'')='' or mail is null or mail!~'^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$' then raise exception 'Pengguna tidak valid'; end if;
 if exists(select 1 from profiles where email=mail and role='student') then raise exception 'Email terdaftar sebagai siswa'; end if;
 insert into profiles(email,name,role,class_name) values(mail,trim(member_name),member_role,coalesce(member_class,'')) returning id into pid;
 return pid;
end $$;
create function public.set_member_active(pid uuid, enabled boolean) returns void language plpgsql security definer set search_path=public as $$
begin
 if public.my_role() is distinct from 'admin' then raise exception 'Hanya admin dapat mengubah status pengguna'; end if;
 if pid=public.my_profile_id() then raise exception 'Anda tidak dapat menonaktifkan akun sendiri'; end if;
 if enabled is null then raise exception 'Status tidak valid'; end if;
 update profiles set active=enabled where id=pid;
 if not found then raise exception 'Pengguna tidak ditemukan'; end if;
end $$;
revoke all on function public.my_profile_id(),public.my_role(),public.can_access_student(uuid),public.import_students(jsonb,uuid),public.update_student(uuid,text,text,text,uuid),public.record_transaction(uuid,text,bigint,timestamptz,text),public.void_transaction(uuid,text),public.manage_member(text,text,text,text),public.set_member_active(uuid,boolean) from public,anon;
grant execute on function public.my_profile_id(),public.my_role(),public.can_access_student(uuid),public.import_students(jsonb,uuid),public.update_student(uuid,text,text,text,uuid),public.record_transaction(uuid,text,bigint,timestamptz,text),public.void_transaction(uuid,text),public.manage_member(text,text,text,text),public.set_member_active(uuid,boolean) to authenticated;
commit;
