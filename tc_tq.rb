# Copyright 2014 Diogo Kollross
# 
# Permission is hereby granted, free of charge, to any person obtaining
# a copy of this software and associated documentation files (the
# "Software"), to deal in the Software without restriction, including
# without limitation the rights to use, copy, modify, merge, publish,
# distribute, sublicense, and/or sell copies of the Software, and to
# permit persons to whom the Software is furnished to do so, subject to
# the following conditions:
# 
# The above copyright notice and this permission notice shall be
# included in all copies or substantial portions of the Software.
# 
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
# MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
# NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
# LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
# OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
# WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.


require 'test/unit'
require_relative 'tq'


class TestTaskBooking < Test::Unit::TestCase
  def test_inverse_reference
    t1 = Task.new('t1', 1)
    assert_equal(0, t1.task_bookings.size)
    
    tb1 = TaskBooking.new(t1, 0.5, nil)
    assert_equal(1, t1.task_bookings.size)
    
    tb2 = TaskBooking.new(t1, 0.5, nil)
    assert_equal(2, t1.task_bookings.size)
  end
end


class TestDayBooking < Test::Unit::TestCase
  def setup
    @db = DayBooking.new(Date.today, '2'.to_d)
  end
  
  def test_empty
    assert_equal('2'.to_d, @db.available_hours)
    assert(!@db.full?)
    assert_equal(0, @db.task_bookings.size)
  end
  
  def test_whole_tasks_partial_day
    t1 = Task.new('t1', '0.3'.to_d)
    assert_equal('0'.to_d, @db.book_task(t1, t1.effort))
    assert_equal('1.7'.to_d, @db.available_hours)
    assert(!@db.full?)
    assert_equal(1, @db.task_bookings.size)
    
    t2 = Task.new('t2', '0.5'.to_d)
    assert_equal('0'.to_d, @db.book_task(t2, t2.effort))
    assert_equal('1.2'.to_d, @db.available_hours)
    assert(!@db.full?)
    assert_equal(2, @db.task_bookings.size)
  end
  
  def test_whole_task_fills_day_exactly
    t1 = Task.new('t1', '2'.to_d)
    assert_equal('0'.to_d, @db.book_task(t1, t1.effort))
    assert_equal('0'.to_d, @db.available_hours)
    assert(@db.full?)
    assert_equal(1, @db.task_bookings.size)
  end
  
  def test_partial_task_fills_day_remaining
    t1 = Task.new('t1', '2.6'.to_d)
    assert_equal('0.6'.to_d, @db.book_task(t1, t1.effort))
    assert_equal('0'.to_d, @db.available_hours)
    assert(@db.full?)
    assert_equal(1, @db.task_bookings.size)
  end
  
  def test_empty_task_is_booked_on_empty_day
    t1 = Task.new('t1', '0'.to_d)
    assert_equal('0'.to_d, @db.book_task(t1, t1.effort))
    assert_equal('2'.to_d, @db.available_hours)
    assert(!@db.full?)
    assert_equal(1, @db.task_bookings.size)
  end
  
  def test_empty_task_is_booked_on_full_day
    t1 = Task.new('t1', @db.available_hours)
    assert_equal('0'.to_d, @db.book_task(t1, t1.effort))
    assert_equal('0'.to_d, @db.available_hours)
    assert(@db.full?)

    t2 = Task.new('t2', '0'.to_d)
    assert_equal('0'.to_d, @db.book_task(t2, t2.effort))
    assert_equal('0'.to_d, @db.available_hours)
    assert(@db.full?)
    assert_equal(2, @db.task_bookings.size)
  end
end


class TestAliases < Test::Unit::TestCase
  def setup
    @p = Project.new
    $tq_current_project = @p
  end
  
  def test_task
    assert_equal(0, @p.tasks.size)
    
    task 't1'
    assert_equal(1, @p.tasks.size)
    t1 = @p.tasks[0]
    assert_equal('t1', t1.description)
    assert_equal('0'.to_d, t1.effort)
    
    task 't2', 0.5
    assert_equal(2, @p.tasks.size)
    t2 = @p.tasks[1]
    assert_equal('t2', t2.description)
    assert_equal('0.5'.to_d, t2.effort)
  end
  
  def test_start
    start '2014-05-11'
    
    assert_equal(Date.strptime('2014-05-11', '%Y-%m-%d'), @p.day_enumerator.start)
  end
  
  def test_working_hours_1
    daily_working_hours 8
    
    assert_equal('8'.to_d, @p.working_hours_registry.working_hours(Date.strptime('2014-05-11', '%Y-%m-%d')))
  end
  
  def test_working_hours_2
    daily_working_hours 7, on: '2014-05-12'
    daily_working_hours 8
    
    assert_equal('8'.to_d, @p.working_hours_registry.working_hours(Date.strptime('2014-05-11', '%Y-%m-%d')))
    assert_equal('7'.to_d, @p.working_hours_registry.working_hours(Date.strptime('2014-05-12', '%Y-%m-%d')))
  end
  
  def test_working_hours_3
    daily_working_hours 6, on: 'sunday'
    daily_working_hours 7, on: '2014-05-12'
    daily_working_hours 8
    
    assert_equal('8'.to_d, @p.working_hours_registry.working_hours(Date.strptime('2014-05-10', '%Y-%m-%d')))
    assert_equal('7'.to_d, @p.working_hours_registry.working_hours(Date.strptime('2014-05-12', '%Y-%m-%d')))
    assert_equal('6'.to_d, @p.working_hours_registry.working_hours(Date.strptime('2014-05-18', '%Y-%m-%d')))
  end
  
  def test_working_hours_4
    daily_working_hours 6, on: 'sunday'
    daily_working_hours 7, on: '2014-05-12'
    daily_working_hours 5, from: '2014-05-11', to: '2014-05-19'
    daily_working_hours 8
    
    assert_equal('8'.to_d, @p.working_hours_registry.working_hours(Date.strptime('2014-05-10', '%Y-%m-%d')))
    assert_equal('7'.to_d, @p.working_hours_registry.working_hours(Date.strptime('2014-05-12', '%Y-%m-%d')))
    assert_equal('6'.to_d, @p.working_hours_registry.working_hours(Date.strptime('2014-05-18', '%Y-%m-%d')))
    assert_equal('5'.to_d, @p.working_hours_registry.working_hours(Date.strptime('2014-05-19', '%Y-%m-%d')))
  end
  
  def test_non_working_day
    assert_equal(0, @p.day_enumerator.non_working_days.size)
    
    non_working_day on: '2014-05-12'
    assert_equal(1, @p.day_enumerator.non_working_days.size)
    
    non_working_day from: '2014-06-01', to: '2014-06-03'
    assert_equal(2, @p.day_enumerator.non_working_days.size)
    
    non_working_day on: 'sunday'
    assert_equal(3, @p.day_enumerator.non_working_days.size)
  end
end


class TestDayEnumerator < Test::Unit::TestCase
  def setup
    @e = DayEnumerator.new
    @e.start = Date.strptime('2014-05-11', '%Y-%m-%d')
  end
  
  def test_simple
    assert_equal(Date.strptime('2014-05-11', '%Y-%m-%d'), @e.next)
    assert_equal(Date.strptime('2014-05-12', '%Y-%m-%d'), @e.next)
    assert_equal(Date.strptime('2014-05-13', '%Y-%m-%d'), @e.next)
  end
  
  def test_single_day
    @e.add_non_working_day SingleDayDefinition.new('2014-05-12')
    
    assert_equal(Date.strptime('2014-05-11', '%Y-%m-%d'), @e.next)
    assert_equal(Date.strptime('2014-05-13', '%Y-%m-%d'), @e.next)
    assert_equal(Date.strptime('2014-05-14', '%Y-%m-%d'), @e.next)
    
    @e.add_non_working_day SingleDayDefinition.new('2014-05-15')
    assert_equal(Date.strptime('2014-05-16', '%Y-%m-%d'), @e.next)
    assert_equal(Date.strptime('2014-05-17', '%Y-%m-%d'), @e.next)
  end
  
  def test_interval
    @e.add_non_working_day IntervalDayDefinition.new('2014-05-12', '2014-05-14')
    assert_equal(Date.strptime('2014-05-11', '%Y-%m-%d'), @e.next)
    assert_equal(Date.strptime('2014-05-15', '%Y-%m-%d'), @e.next)
  end
  
  def test_day_of_week
    @e.add_non_working_day DayOfWeekDefinition.new('sunday')
    assert_equal(Date.strptime('2014-05-12', '%Y-%m-%d'), @e.next)
    assert_equal(Date.strptime('2014-05-13', '%Y-%m-%d'), @e.next)
    assert_equal(Date.strptime('2014-05-14', '%Y-%m-%d'), @e.next)
    assert_equal(Date.strptime('2014-05-15', '%Y-%m-%d'), @e.next)
    assert_equal(Date.strptime('2014-05-16', '%Y-%m-%d'), @e.next)
    assert_equal(Date.strptime('2014-05-17', '%Y-%m-%d'), @e.next)
    assert_equal(Date.strptime('2014-05-19', '%Y-%m-%d'), @e.next)
  end
end


class TestWorkingHoursRegistry < Test::Unit::TestCase
  def setup
    @r = WorkingHoursRegistry.new
  end
  
  def test_every_day
    @r.add WorkingHoursDefinition.new(EveryDayDefinition.new, 5)
    
    assert_equal(5, @r.working_hours(Date.strptime('2014-05-12', '%Y-%m-%d')))
    assert_equal(5, @r.working_hours(Date.strptime('2014-05-13', '%Y-%m-%d')))
  end
  
  def test_single_day
    @r.add WorkingHoursDefinition.new(SingleDayDefinition.new('2014-05-12'), 6)
    
    assert_equal(6, @r.working_hours(Date.strptime('2014-05-12', '%Y-%m-%d')))
    assert_equal(nil, @r.working_hours(Date.strptime('2014-05-13', '%Y-%m-%d')))
  end
  
  def test_interval
    @r.add WorkingHoursDefinition.new(IntervalDayDefinition.new('2014-05-12', '2014-05-14'), 7)
    
    assert_equal(nil, @r.working_hours(Date.strptime('2014-05-11', '%Y-%m-%d')))
    assert_equal(7, @r.working_hours(Date.strptime('2014-05-12', '%Y-%m-%d')))
    assert_equal(7, @r.working_hours(Date.strptime('2014-05-13', '%Y-%m-%d')))
    assert_equal(7, @r.working_hours(Date.strptime('2014-05-14', '%Y-%m-%d')))
    assert_equal(nil, @r.working_hours(Date.strptime('2014-05-15', '%Y-%m-%d')))
  end
  
  def test_day_of_week
    @r.add WorkingHoursDefinition.new(DayOfWeekDefinition.new('sunday'), 8)
    
    assert_equal(nil, @r.working_hours(Date.strptime('2014-05-12', '%Y-%m-%d')))
    assert_equal(nil, @r.working_hours(Date.strptime('2014-05-13', '%Y-%m-%d')))
    assert_equal(nil, @r.working_hours(Date.strptime('2014-05-14', '%Y-%m-%d')))
    assert_equal(nil, @r.working_hours(Date.strptime('2014-05-15', '%Y-%m-%d')))
    assert_equal(nil, @r.working_hours(Date.strptime('2014-05-16', '%Y-%m-%d')))
    assert_equal(nil, @r.working_hours(Date.strptime('2014-05-17', '%Y-%m-%d')))
    assert_equal(8, @r.working_hours(Date.strptime('2014-05-18', '%Y-%m-%d')))
    assert_equal(nil, @r.working_hours(Date.strptime('2014-05-19', '%Y-%m-%d')))
  end
end


class TestProject < Test::Unit::TestCase
  def setup
    @p = Project.new
    $tq_current_project = @p
    
    start '2014-05-11'
  end

  def test_single_day
    daily_working_hours 2
    
    task 't1', 0.2
    task 't2', 0.5
    task 't3', 0.4
    
    p = @p.plan
    assert_equal(1, p.bookings.size)
    
    assert_equal(Date.strptime('2014-05-11', '%Y-%m-%d'), @p.tasks[0].first_day)
    assert_equal(Date.strptime('2014-05-11', '%Y-%m-%d'), @p.tasks[0].last_day)
    assert_equal(Date.strptime('2014-05-11', '%Y-%m-%d'), @p.tasks[2].first_day)
    assert_equal(Date.strptime('2014-05-11', '%Y-%m-%d'), @p.tasks[2].last_day)
  end
  
  def test_many_days
    daily_working_hours 2
    
    task 't1', 2.2
    task 't2', 1.5
    task 't3', 3.4
    
    p = @p.plan
    assert_equal(4, p.bookings.size)
    
    assert_equal(Date.strptime('2014-05-11', '%Y-%m-%d'), @p.tasks[0].first_day)
    assert_equal(Date.strptime('2014-05-12', '%Y-%m-%d'), @p.tasks[0].last_day)
    assert_equal(Date.strptime('2014-05-12', '%Y-%m-%d'), @p.tasks[1].first_day)
    assert_equal(Date.strptime('2014-05-12', '%Y-%m-%d'), @p.tasks[1].last_day)
    assert_equal(Date.strptime('2014-05-12', '%Y-%m-%d'), @p.tasks[2].first_day)
    assert_equal(Date.strptime('2014-05-14', '%Y-%m-%d'), @p.tasks[2].last_day)
  end
  
  def test_working_hours
    daily_working_hours 4, on: '2014-05-12'
    daily_working_hours 2
    
    task 't1', 2.2
    task 't2', 1.5
    task 't3', 2.0
    
    p = @p.plan
    assert_equal(2, p.bookings.size)
    
    assert_equal(Date.strptime('2014-05-11', '%Y-%m-%d'), @p.tasks[0].first_day)
    assert_equal(Date.strptime('2014-05-12', '%Y-%m-%d'), @p.tasks[0].last_day)
    assert_equal(Date.strptime('2014-05-12', '%Y-%m-%d'), @p.tasks[1].first_day)
    assert_equal(Date.strptime('2014-05-12', '%Y-%m-%d'), @p.tasks[1].last_day)
    assert_equal(Date.strptime('2014-05-12', '%Y-%m-%d'), @p.tasks[2].first_day)
    assert_equal(Date.strptime('2014-05-12', '%Y-%m-%d'), @p.tasks[2].last_day)
  end
end
