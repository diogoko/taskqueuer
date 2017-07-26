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


require 'bigdecimal'
require 'bigdecimal/util'
require 'date'


class Task
  attr_accessor :description, :effort, :task_bookings
  
  def initialize(description, effort)
    @description = description
    @effort = effort
    @task_bookings = []
  end
  
  def first_day
    @task_bookings.first.day_booking.date
  end
  
  def last_day
    @task_bookings.last.day_booking.date
  end
end


class TaskBooking
  attr_reader :task, :hours, :day_booking

  def initialize(task, hours, day_booking)
    @task = task
    task.task_bookings << self
    
    @hours = hours
    @day_booking = day_booking
  end
end


class DayBooking
  attr_reader :date, :task_bookings

  def initialize(date, working_hours)
    @date = date
    @working_hours = working_hours
    @booked_hours = 0
    @task_bookings = []
  end
  
  def available_hours
    @working_hours - @booked_hours
  end
  
  def full?
    self.available_hours <= 0
  end
  
  def book_task(task, remaining_effort)
    hours = [self.available_hours, remaining_effort].min
    @task_bookings << TaskBooking.new(task, hours, self)
    @booked_hours += hours
    
    return remaining_effort - hours
  end
end


class Plan
  attr_accessor :project, :bookings
  
  def initialize(project, bookings)
    @project = project
    @bookings = bookings
  end
  
  def export_bookings(f)
    @bookings.each do |b|
      day = b.date.strftime('%Y-%m-%d')
      b.task_bookings.each do |t|
        f.puts "#{day}\t#{t.hours.to_s('F')}\t#{t.task.description}"
      end
    end
  end
  
  def export_dates(f)
    @project.tasks.each do |t|
      f.puts "#{t.description}\t#{t.effort.to_s('F')}\t#{t.first_day}\t#{t.last_day}"
    end
  end
end


class EveryDayDefinition
  def match?(date)
    true
  end
end


class SingleDayDefinition
  def initialize(date)
    @date = Date.strptime(date, '%Y-%m-%d')
  end
  
  def match?(date)
    date == @date
  end
end


class IntervalDayDefinition
  def initialize(first, last)
    @first = Date.strptime(first, '%Y-%m-%d')
    @last = Date.strptime(last, '%Y-%m-%d')
  end
  
  def match?(date)
    (@first <= date) && (date <= @last)
  end
end


class DayOfWeekDefinition
  def initialize(name)
    @name = name.downcase
  end
  
  def match?(date)
    (date.strftime('%a').downcase == @name) || (date.strftime('%A').downcase == @name)
  end
end


class DayEnumerator
  attr_accessor :start

  attr_reader :non_working_days

  def initialize
    @current = nil
    @non_working_days = []
  end
  
  def non_working_day?(date)
    @non_working_days.any? { |d| d.match?(date) }
  end
  
  def next
    if @current == nil then
      @current = @start
    end

    while non_working_day?(@current)
      @current = @current.next_day
    end
    
    day = @current
    @current = @current.next_day
    
    return day
  end
  
  def add_non_working_day(day_definition)
    @non_working_days << day_definition
  end
end


class WorkingHoursDefinition
  attr_reader :day_definition, :working_hours

  def initialize(day_definition, working_hours)
    @day_definition = day_definition
    @working_hours = working_hours
  end
end


class WorkingHoursRegistry
  def initialize
    @definitions = []
  end
  
  def add(definition)
    @definitions << definition
  end
  
  def working_hours(date)
    i = @definitions.index { |d| d.day_definition.match? date }
    
    if i == nil then
      nil
    else
      @definitions[i].working_hours
    end
  end
end


class Project
  attr_reader :tasks, :day_enumerator, :working_hours_registry
  
  def initialize
    @tasks = []
    @day_enumerator = DayEnumerator.new
    @working_hours_registry = WorkingHoursRegistry.new
  end
  
  def add_task(description, effort)
    @tasks << Task.new(description, effort)
  end
  
  def plan
    date = @day_enumerator.next
    working_hours = @working_hours_registry.working_hours date
    bookings = [DayBooking.new(date, working_hours)]
    
    @tasks.each do |t|
      remaining_effort = t.effort
      
      begin
        if bookings.last.full? then
          date = @day_enumerator.next
          working_hours = @working_hours_registry.working_hours date
          bookings << DayBooking.new(date, working_hours)
        end
        
        remaining_effort = bookings.last.book_task(t, remaining_effort)
      end while remaining_effort > 0
    end
    
    return Plan.new(self, bookings)
  end
end


def task(description, effort = 0)
  $tq_current_project.add_task(description, effort.to_d)
end


def start(date)
  $tq_current_project.day_enumerator.start = Date.strptime(date, '%Y-%m-%d')
end


def daily_working_hours(hours, on: nil, from: nil, to: nil)
  if on then
    begin
      d = SingleDayDefinition.new(on)
    rescue ArgumentError
      d = DayOfWeekDefinition.new(on)
    end
  elsif from && to then
    d = IntervalDayDefinition.new(from, to)
  else
    d = EveryDayDefinition.new
  end
  
  whd = WorkingHoursDefinition.new(d, hours.to_d)
  
  $tq_current_project.working_hours_registry.add(whd)
end


def non_working_day(on: nil, from: nil, to: nil)
  if on then
    begin
      d = SingleDayDefinition.new(on)
    rescue ArgumentError
      d = DayOfWeekDefinition.new(on)
    end
    
    $tq_current_project.day_enumerator.add_non_working_day(d)
  elsif from && to then
    d = IntervalDayDefinition.new(from, to)
    $tq_current_project.day_enumerator.add_non_working_day(d)
  end
end


if __FILE__ == $0 then
  if ARGV.length >= 2 then
    command = ARGV.shift
    if ['dates', 'bookings'].include?(command) then
      input_filename = ARGV.shift
      output = ARGV.shift
      if output then
        output = IO.open(output, 'r')
      else
        output = $stdout
      end

      $tq_current_project = Project.new
      load input_filename
      plan = $tq_current_project.plan
      
      case command
        when 'dates'
          plan.export_dates(output)
        when 'bookings'
          plan.export_bookings(output)
      end
    else
      puts "Invalid command: #{command}"
    end
  else
    puts <<-EOF
tq COMMAND INPUT [OUTPUT]

  dates       Schedule all tasks from file INPUT and print the start and end
              date of each one.

  bookings    Schedule all tasks from file INPUT and print the planned amount
              of work for each task in each day.

If OUTPUT is not specified, STDOUT will be assumed.
    EOF
  end
end
