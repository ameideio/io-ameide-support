# Wrapper job invoked weekly by Sidekiq Cron (see config/schedule.yml).
# Delegates to the `audit:prune` Rake task so the same code path is reachable
# from a manual `bundle exec rails audit:prune`.

class Internal::AuditPruneJob < ApplicationJob
  queue_as :scheduled_jobs

  def perform
    require 'rake'
    Rails.application.load_tasks unless Rake::Task.task_defined?('audit:prune')
    Rake::Task['audit:prune'].reenable
    Rake::Task['audit:prune'].invoke
  end
end
