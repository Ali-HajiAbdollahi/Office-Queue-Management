RETROSPECTIVE TEAM 05
=====================================

## PROCESS MEASURES 

### Macro statistics

- Number of stories committed vs done: **2 committed / 2 done**
- Total points committed vs done: **10 / 10**
- Nr of hours planned vs spent (as a team): **42h 00m planned / 66h 30m spent**

### Detailed statistics

| Story                  | # Tasks | Points | Hours est. | Hours actual |
|------------------------|---------|--------|------------|--------------|
| _#0_                   | 6       |    -   | 8h 00m     | 28h 00m      |
| 1 - Get ticket         | 10      | 5      | 18h 00m    | 20h 30m      |
| 2 - Next customer      | 8       | 5      | 16h 00m    | 18h 00m      |
| **Total**              | **24**  | **10** | **42h 00m**| **66h 30m**  |


- Hours per task average, standard deviation (estimate and actual)

|            | Mean   | StDev  |
|------------|--------|--------|
| Estimation | 1.75h  | 0.74h  | 
| Actual     | 2.77h  | 2.49h  |

- Total estimation error ratio: sum of total hours spent / sum of total hours effort - 1

    $$\frac{\sum_i spent_{task_i}}{\sum_i estimation_{task_i}} - 1 = \frac{66.5}{42} - 1 = 0.58$$
    
- Absolute relative task estimation error: sum( abs( spent-task-i / estimation-task-i - 1))/n

    $$\frac{1}{n}\sum_i^n \left| \frac{spent_{task_i}}{estimation_{task_i}}-1 \right| = 0.82$$

  
## QUALITY MEASURES 

- Unit Testing:
  - Total hours estimated: 2h 00m
  - Total hours spent: 2h 00m
  - Nr of automated unit test cases: 134 (54 backend + 80 frontend)
  - Coverage: backend 44.5% lines, frontend 92.5% lines
    - Backend unit tests mock the persistence layer (`dao/`, `repositories/`, `db.js`), so that code is never executed by unit tests and lowers the line coverage. It is covered by the 31 backend integration tests, which run on a real Postgres instance.
- E2E testing:
  - Total hours estimated: 2h 00m
  - Total hours spent: 3h 00m
  - Nr of test cases: 17
- Code review 
  - Total hours estimated: 1h 00m
  - Total hours spent: 6h 00m


## ASSESSMENT

- What caused your errors in estimation (if any)?

Our estimation errors had three main causes. First, group activities (meetings, code review) were estimated by their duration rather than in person-hours: for example, a 2-hour meeting with 6 members was estimated as 2h but logged as 12h.  Second, due to the team's inexperience, our initial understanding of what we would actually have to build was unclear; only later in the week did we realize what the work concretely involved. Finally, we did not plan for integration: some of us had to spend unplanned time resolving conflicts between parts developed separately by different team members.

- What lessons did you learn (both positive and negative) in this sprint?

On the negative side, we learned not to underestimate tasks that look simple at first glance. We also learned that leaving tasks to the last minute creates stress and increases the risk of errors, and that communication between team members is essential to build a shared understanding of what we are going to develop. On the positive side, we learned that splitting stories into small, well-defined technical tasks leads to accurate estimates.

- Improvement goals for the next sprint and how to achieve them (technical tasks, team coordination, etc.)

We think we should improve communication within the team and plan a code freeze a few days before the deadline, so that we have time to review all the code and make sure the different parts integrate consistently. We could achieve this with short regular check-ins and by agreeing on an internal deadline earlier than the official one. We also think we should be more precise in logging the time spent on each task in the Agile Board, for example by updating it at the end of every work session instead of all at once at the end of the sprint.

- One thing you are proud of as a Team!!

Despite our inexperience and some communication issues, we managed to deliver a working product as a team. This shows that we are capable of building solid and reliable software, and that with better communication we can do even more.
