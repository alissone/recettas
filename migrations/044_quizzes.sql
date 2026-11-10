-- Quizzes (multiple choice, A-E, with an explanation per option) and the
-- attempts people make at them. Format of `content`: docs/quiz-format.md.
--
-- Quizzes are written outside the app (the /quiz Claude skill) and
-- uploaded with scripts/upload_quiz.py using the service-role key, so
-- clients only ever read them. Title, topic and question count are
-- generated from `content`, so the list can select just those without
-- pulling every question, and they can never drift from the JSON.
create table public.quizzes (
  id uuid primary key default gen_random_uuid(),
  content jsonb not null,
  title text generated always as (content->>'title') stored,
  topic text generated always as (content->>'topic') stored,
  description text generated always as (content->>'description') stored,
  question_count int
    generated always as (jsonb_array_length(content->'questions')) stored,
  created_at timestamptz default now(),
  check (content ? 'title' and jsonb_typeof(content->'questions') = 'array')
);

create index quizzes_created_idx on public.quizzes (created_at desc);

alter table public.quizzes enable row level security;

create policy "Signed-in users can view quizzes"
  on public.quizzes for select
  to authenticated
  using (true);

-- One row per finished attempt. `answers` holds one letter per question,
-- in question order ("ABADC"), '-' for a question left blank. Scores are
-- computed by the client from `answers` + the quiz's answer key, so a
-- corrected key re-scores old attempts too.
--
-- quiz_id has no foreign key on purpose: the app ships a few quizzes
-- bundled as assets (assets/quizzes/), with fixed ids, and attempts at
-- them must save even before they are uploaded to `quizzes`.
create table public.quiz_attempts (
  id uuid primary key default gen_random_uuid(),
  quiz_id uuid not null,
  user_id uuid references public.profiles(id) on delete cascade not null
    default auth.uid(),
  user_email text,
  answers text not null check (answers ~ '^[A-E-]*$'),
  duration_seconds int,
  created_at timestamptz default now()
);

create index quiz_attempts_user_quiz_idx
  on public.quiz_attempts (user_id, quiz_id, created_at);

alter table public.quiz_attempts enable row level security;

create policy "Users can view their own quiz attempts"
  on public.quiz_attempts for select
  using (auth.uid() = user_id);

create policy "Users can record their own quiz attempts"
  on public.quiz_attempts for insert
  with check (auth.uid() = user_id);

create policy "Users can delete their own quiz attempts"
  on public.quiz_attempts for delete
  using (auth.uid() = user_id);
