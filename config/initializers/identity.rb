# Identity subsystem configuration.
#
# identity.mode controls which login paths are available:
#
#   "local_only"      — Only password login. OIDC routes exist but are inert.
#                       Use during initial setup and break-glass recovery.
#
#   "local_plus_oidc" — Password login and OIDC login both work.
#                       Recommended during rollout: validate OIDC before enforcing it.
#
#   "oidc_required"   — OIDC is the only path for non-break-glass users.
#                       Password login is blocked except for break_glass_admin accounts.
#                       Enable only after at least one successful enterprise admin login
#                       and a tested break-glass login.
#
# Set via IDENTITY_MODE environment variable or Rails credentials:
#   Rails.application.credentials.dig(:identity, :mode)
#
Rails.application.configure do
  mode = ENV.fetch("IDENTITY_MODE") {
    credentials.dig(:identity, :mode) || "local_only"
  }

  unless %w[local_only local_plus_oidc oidc_required].include?(mode)
    raise "Invalid IDENTITY_MODE: #{mode.inspect}. " \
          "Must be local_only, local_plus_oidc, or oidc_required."
  end

  config.x.identity.mode = mode
end

# Lockbox encryption key for IdentityProvider.client_secret.
# Falls back to secret_key_base in development; must be set explicitly in production.
Lockbox.master_key = ENV.fetch("LOCKBOX_MASTER_KEY") {
  if Rails.env.production?
    Rails.application.credentials.dig(:lockbox, :master_key) ||
      raise("LOCKBOX_MASTER_KEY or credentials[:lockbox][:master_key] must be set in production")
  else
    # Derive a stable dev key from secret_key_base so dev DB is portable.
    Digest::SHA256.hexdigest("lockbox-dev-#{Rails.application.secret_key_base}")
  end
}

if Rails.env.production? && Rails.application.credentials.dig(:scim_hmac_key).blank?
  raise "credentials[:scim_hmac_key] must be set in production"
end
