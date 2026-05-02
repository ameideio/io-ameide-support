# Prunes old `Audited::Audit` rows so the audits table doesn't grow unbounded.
#
# Retention is sourced (in priority order) from:
#   1. `AmeideOidcConfig.audit_retention_days` (if defined)
#   2. `ENV['AMEIDE_AUDIT_RETENTION_DAYS']`
#   3. 365 days (default)
#
# Run via the Sidekiq cron entry in `config/schedule.yml`:
#   bundle exec rails audit:prune

namespace :audit do
  desc 'Prune Audited::Audit rows older than the configured retention window'
  task prune: :environment do
    retention_days =
      if defined?(AmeideOidcConfig) && AmeideOidcConfig.respond_to?(:audit_retention_days)
        AmeideOidcConfig.audit_retention_days.to_i
      else
        ENV.fetch('AMEIDE_AUDIT_RETENTION_DAYS', 365).to_i
      end
    retention_days = 365 if retention_days <= 0

    cutoff = Time.current - retention_days.days
    Rails.logger.info(
      "[audit:prune] deleting Audited::Audit rows created before #{cutoff.iso8601} (retention=#{retention_days}d)"
    )

    deleted = Audited::Audit.where('created_at < ?', cutoff).delete_all
    Rails.logger.info("[audit:prune] deleted #{deleted} audit row(s)")
    deleted
  end
end
