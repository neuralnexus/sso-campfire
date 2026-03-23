class Rack::Attack
  # ── OIDC auth endpoints ───────────────────────────────────────────────────────
  # Throttle authorization start to prevent enumeration / redirect-loop abuse.
  throttle("auth/oidc/start", limit: 20, period: 5.minutes) do |req|
    req.ip if req.path == "/auth/oidc/start"
  end

  # Throttle callback endpoint to limit code-replay attempts.
  throttle("auth/oidc/callback", limit: 20, period: 5.minutes) do |req|
    req.ip if req.path.start_with?("/auth/oidc/callback")
  end

  # ── SCIM endpoints ────────────────────────────────────────────────────────────
  # SCIM is a server-to-server API; high per-IP limits are appropriate,
  # but we still cap to catch misconfigured IdPs hammering the endpoint.
  throttle("scim/v2", limit: 300, period: 1.minute) do |req|
    req.ip if req.path.start_with?("/scim/v2")
  end

  # ── Admin identity provider actions ──────────────────────────────────────────
  throttle("admin/identity", limit: 60, period: 1.minute) do |req|
    req.ip if req.path.start_with?("/admin/identity_providers")
  end

  # ── Response for throttled requests ──────────────────────────────────────────
  self.throttled_responder = lambda do |env|
    req = Rack::Request.new(env)

    if req.path.start_with?("/scim/")
      [
        429,
        { "Content-Type" => "application/scim+json" },
        [ {
          schemas: [ "urn:ietf:params:scim:api:messages:2.0:Error" ],
          detail:  "Too many requests",
          status:  "429"
        }.to_json ]
      ]
    else
      [
        429,
        { "Content-Type" => "text/plain" },
        [ "Too many requests. Please try again later." ]
      ]
    end
  end
end

Rails.application.config.middleware.use Rack::Attack
