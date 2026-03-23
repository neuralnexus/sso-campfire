class FirstRun
  ACCOUNT_NAME    = "Campfire"
  FIRST_ROOM_NAME = "All Talk"

  def self.create!(user_params)
    account = Account.create!(name: ACCOUNT_NAME)
    room    = Rooms::Open.new(name: FIRST_ROOM_NAME)

    # The first-run administrator is the break-glass account.
    # It is excluded from SCIM deactivation and OIDC-required enforcement,
    # ensuring local operational control is always available.
    administrator = room.creator = User.new(
      user_params.merge(
        role:                :administrator,
        break_glass_admin:   true,
        provisioning_source: "local"
      )
    )
    room.save!

    room.memberships.grant_to administrator

    administrator
  end
end
