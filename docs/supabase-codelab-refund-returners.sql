-- ⚠️ 2026-11-06 이미 한 번 실행함 — 다시 실행하지 말 것.
-- ⚠️ 이 SQL 은 정상 탈주와 잘못된 벌점을 구분하지 못한다: 염버지의 정상 탈주 1회까지 지워 31점을 돌려줬고,
--    이어서 수동으로 rating −15, games +2 로 바로잡음 (정상 탈주 한 번만 남김). 범저시말랑카우는 대상 기록 없음.
-- 코드랩: 소급 탈주 처리(supabase-codelab-fix-quitters.sql)로 잘못 깎인 사람 되돌리기
-- 2026-11-06: 염버지 · 범저시말랑카우 는 끊겼다가 게임이 끝나기 전에 돌아왔는데,
-- 30초가 지나 다른 사람들 기록에 '기권'으로 남아서 소급 처리에 걸렸음.
-- 그때 들어간 줄(내 줄이 left=true 인 기록)을 지우고, 깎인 점수와 판수를 돌려준다.
with bad as (
  delete from public.codelab_matches m
   using public.codelab_profiles p
   where m.user_id = p.user_id
     and p.nickname in ('염버지', '범저시말랑카우')
     and exists (select 1 from jsonb_array_elements(m.detail) d
                  where lower(d->>'nick') = lower(p.nickname) and coalesce((d->>'left')::boolean, false))
  returning m.user_id, m.rating_before - m.rating_after as lost
)
update public.codelab_profiles p
   set rating = p.rating + b.lost, games = greatest(0, p.games - b.n), updated_at = now()
  from (select user_id, sum(lost) as lost, count(*) as n from bad group by user_id) b
 where p.user_id = b.user_id
returning p.nickname as "닉네임", b.n as "지운 기록", b.lost as "돌려준 점수", p.rating as "지금 레이팅", p.games as "판수";
