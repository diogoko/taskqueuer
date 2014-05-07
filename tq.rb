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


require 'date'
require 'singleton'


class Task
  attr_accessor :description, :effort
  
  def initialize(description, effort)
    @description = description
    @effort = effort
  end
end


class TaskBooking
  attr_reader :task, :hours

  def initialize(task, hours)
    @task = task
    @hours = hours
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
    @task_bookings << TaskBooking.new(task, hours)
    @booked_hours += hours
    
    return remaining_effort - hours
  end
end


class Project
  include Singleton

  attr_accessor :start, :daily_working_hours
  
  def initialize
    @tasks = []
  end
  
  def add_task(description, effort)
    @tasks << Task.new(description, effort)
  end
  
  def plan
    days = Enumerator.new do |yielder|
      d = Date.strptime(@start, '%Y-%m-%d')
      loop do
        yielder.yield d
        d = d.next_day
      end
    end
  
    bookings = [DayBooking.new(days.next, @daily_working_hours)]
    @tasks.each do |t|
      remaining_effort = t.effort
      
      begin
        if bookings.last.full? then
          bookings << DayBooking.new(days.next, @daily_working_hours)
        end
        
        remaining_effort = bookings.last.book_task(t, remaining_effort)
      end while remaining_effort > 0
    end
    
    return bookings
  end
end


def export_bookings(bookings)
  bookings.each do |b|
    day = b.date.strftime('%Y-%m-%d')
    b.task_bookings.each do |t|
      puts "#{day}\t#{t.hours}\t#{t.task.description}"
    end
  end
end


def task(description, effort = 0)
  Project.instance.add_task(description, effort)
end


def start(date)
  Project.instance.start = date
end


def daily_working_hours(hours)
  Project.instance.daily_working_hours = hours
end


load 'example'

bookings = Project.instance.plan
export_bookings(bookings)