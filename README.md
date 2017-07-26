taskqueuer
==========

taskqueuer (or "tq" for short) is a very simple task scheduler. It processes a Ruby source file written in a tiny DSL and calculates the planned start and end dates for each sequential task, or how much work will be made in each task for every day of the plan.

## usage

```tq COMMAND INPUT [OUTPUT]```

Where `COMMAND` is one of:

| Command | Description |
|---------|-------------|
| dates | Schedule all tasks from file `INPUT` and print the start and end date of each one. |
| bookings | Schedule all tasks from file `INPUT` and print the planned amount of work for each task in each day. |

If `OUTPUT` is not specified, STDOUT will be assumed.

## DSL

At the very least every project should have:

* The starting date (defined with `start`)
* The number of hours available each day (declared with one or more `daily_working_hours`)
* One or more tasks (declared with `task`)

Daily working hours definitions are matched first to last, so they should be ordered from the most specific to the most generic. Usually this means:

1. daily_working_hours N, :on => 'YYYY-MM-DD'
1. daily_working_hours N, :on => 'DAY OF WEEK'
1. daily_working_hours N, :from => 'YYYY-MM-DD', :to => 'YYYY-MM-DD'
1. daily_working_hours N

### start 'YYYY-MM-DD'

Set the first day of the plan.

### daily_working_hours N

Set the number of working hours that are available every day.

### daily_working_hours N, :on => 'YYYY-MM-DD'

Set the number of working hours that are available on the specified day.

### daily_working_hours N, :on => 'DAY OF WEEK'

Set the number of working hours of the specified day of week (eg: `'sunday'`).

### daily_working_hours N, :from => 'YYYY-MM-DD', :to => 'YYYY-MM-DD'

Set the number of working hours of a range of days, including the first and last days of the range.

### non_working_day :on => 'YYYY-MM-DD'

Add a day to the list of non working day. The planner will skip non working days in the plan.

### non_working_day :on => 'DAY OF WEEK'

Makes every specified day of week a non-working day  (eg: `'sunday'`).

### non_working_day :from => 'YYYY-MM-DD', :to => 'YYYY-MM-DD'

Add a range of non working days, including the first and last days of the range.

### task 'DESCRIPTION', EFFORT

Add a task to the sequence of tasks. The `DESCRIPTION` is a free form string that describes the task. It doesn't need to be unique.

`EFFORT` is the number of hours of effort of the task (zero or any positive decimal number). Tasks that can't be completed in one day will be broken in many days, respecting the specified daily working hours.

## Output

TODO

## Example

TODO
