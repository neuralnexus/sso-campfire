# Enqueue a metadata refresh on boot if any provider hasn't been refreshed
# within the last 12 hours. This covers the case where the scheduled cron
# missed a run (e.g. server restart) without hammering the IdP on every boot.
#
# The job itself is idempotent and safe to enqueue multiple times.
Rails.application.config.after_initialize do
  if Rails.env.production? || Rails.env.development?
    begin
      stale_threshold = 12.hours.ago

      stale = IdentityProvider.enabled.where(
        "last_metadata_refresh_at IS NULL OR last_metadata_refresh_at < ?",
        stale_threshold
      )

      if stale.any?
        Identity::RefreshMetadataJob.perform_later
        Rails.logger.info("[identity] Enqueued metadata refresh for #{stale.count} stale provider(s)")
      end
    rescue => e
      # Never block boot due to a scheduling failure.
      Rails.logger.warn("[identity] Could not enqueue metadata refresh on boot: #{e.message}")
    end
  end
end
