# Seeds a sample "Website relaunch" project, starting last week.
#
#     mix run priv/repo/seeds.exs
alias LiveGantt.Planning

Planning.reset!()

today = Date.utc_today()
monday = Date.add(today, 1 - Date.day_of_week(today) - 7)
at = fn offset -> NaiveDateTime.new!(Date.add(monday, offset), ~T[00:00:00]) end

insert = fn attrs ->
  {:ok, task} = Planning.create_task(attrs)
  task
end

project = fn text, position ->
  insert.(%{text: text, type: :project, start_date: at.(0), duration: 1, position: position})
end

# The baseline is the original plan: `slip` days earlier than the current dates.
task = fn parent, position, text, offset, duration, opts ->
  {slip, opts} = Keyword.pop(opts, :slip, 0)

  insert.(
    Map.merge(
      %{
        text: text,
        parent_id: parent.id,
        position: position,
        start_date: at.(offset),
        duration: duration,
        planned_start: at.(offset - slip),
        planned_end: at.(offset - slip + duration)
      },
      Map.new(opts)
    )
  )
end

discovery = project.("Discovery", 0)
kickoff = task.(discovery, 0, "Kickoff meeting", 0, 0, type: :milestone)
interviews = task.(discovery, 1, "Stakeholder interviews", 0, 3, owner: "Ana", progress: 1.0)
research = task.(discovery, 2, "Competitive analysis", 1, 4, owner: "Luis", progress: 0.8)
signoff = task.(discovery, 3, "Requirements sign-off", 5, 0, type: :milestone)

design = project.("Design", 1)
ia = task.(design, 0, "Information architecture", 5, 3, owner: "Marta", progress: 0.6, slip: 1)
wireframes = task.(design, 1, "Wireframes", 8, 5, owner: "Marta", progress: 0.2, slip: 2)
visual = task.(design, 2, "Visual design", 10, 6, owner: "Kenji", slip: 2, deadline: at.(14))
review = task.(design, 3, "Design review", 16, 0, type: :milestone, slip: 2)

development = project.("Development", 2)
frontend = task.(development, 0, "Frontend build", 16, 10, owner: "Luis")
cms = task.(development, 1, "CMS integration", 18, 7, owner: "Sofía")
api = task.(development, 2, "API & integrations", 17, 8, owner: "Ana")

launch = project.("Launch", 3)
qa = task.(launch, 0, "QA & accessibility", 26, 5, owner: "Sofía")
content = task.(launch, 1, "Content migration", 24, 4, owner: "Kenji")
go_live = task.(launch, 2, "Go live", 31, 0, type: :milestone, deadline: at.(32))

for {source, target, type} <- [
      {kickoff, interviews, :finish_to_start},
      {interviews, signoff, :finish_to_start},
      {research, signoff, :finish_to_start},
      {signoff, ia, :finish_to_start},
      {ia, wireframes, :finish_to_start},
      {wireframes, visual, :start_to_start},
      {visual, review, :finish_to_start},
      {review, frontend, :finish_to_start},
      {frontend, cms, :start_to_start},
      {api, qa, :finish_to_start},
      {frontend, qa, :finish_to_start},
      {cms, content, :finish_to_start},
      {qa, go_live, :finish_to_start},
      {content, go_live, :finish_to_finish}
    ] do
  {:ok, _link} = Planning.create_link(%{source_id: source.id, target_id: target.id, type: type})
end

IO.puts(
  "Seeded #{length(Planning.list_tasks())} tasks and #{length(Planning.list_links())} links"
)
