-- 뮤됴구 온라인 계정 기록 (Supabase → SQL Editor 에서 한 번 실행)
-- 계정(이메일/비밀번호)은 Supabase Auth 가 관리하고, 게임 기록은 계정당 한 줄로 여기 저장한다.
-- 내 줄만 읽고 쓸 수 있다 (RLS: auth.uid() = user_id).

create table if not exists public.mud_saves (
  user_id    uuid primary key references auth.users (id) on delete cascade,
  data       jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now()
);

alter table public.mud_saves enable row level security;

drop policy if exists "내 기록 보기"   on public.mud_saves;
drop policy if exists "내 기록 만들기" on public.mud_saves;
drop policy if exists "내 기록 고치기" on public.mud_saves;
drop policy if exists "내 기록 지우기" on public.mud_saves;

create policy "내 기록 보기"   on public.mud_saves for select using (auth.uid() = user_id);
create policy "내 기록 만들기" on public.mud_saves for insert with check (auth.uid() = user_id);
create policy "내 기록 고치기" on public.mud_saves for update using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "내 기록 지우기" on public.mud_saves for delete using (auth.uid() = user_id);

-- 한 계정 기록이 너무 커지지 않게 (게임 기록 전체가 보통 수백 KB 이하)
alter table public.mud_saves drop constraint if exists mud_saves_size;
alter table public.mud_saves add constraint mud_saves_size check (pg_column_size(data) < 5000000);
