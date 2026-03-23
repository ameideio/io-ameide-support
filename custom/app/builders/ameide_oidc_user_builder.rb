class AmeideOidcUserBuilder
  class AuthenticationFailed < StandardError; end

  def initialize(auth_hash)
    @auth_hash = auth_hash
  end

  def perform
    validate_authorization!
    @user = find_or_create_user
    add_user_to_account if @user.persisted?
    @user
  end

  private

  def find_or_create_user
    user = User.from_email(email)
    return create_user unless user
    return existing_user_for_account(user) if user_can_join_target_account?(user)

    raise AuthenticationFailed, I18n.t('errors.signup.invalid')
  end

  def existing_user_for_account(user)
    confirm_user_if_required(user)
    user.update!(provider: 'ameide_oidc', uid: uid)
    user
  end

  def create_user
    User.create!(
      email: email,
      name: name,
      display_name: first_name,
      provider: 'ameide_oidc',
      uid: uid,
      password: SecureRandom.hex(32),
      confirmed_at: Time.current
    )
  end

  def add_user_to_account
    account_user = AccountUser.find_or_create_by!(user: @user, account: target_account)
    account_user.update!(role: mapped_role) if account_user.role != mapped_role
    sync_user_inbox_memberships!
  end

  def sync_user_inbox_memberships!
    target_account.inboxes.find_each do |inbox|
      next if inbox.inbox_members.exists?(user_id: @user.id)

      inbox.add_members([@user.id])
    end
  end

  def user_can_join_target_account?(user)
    return true if user.account_users.blank?

    user.account_users.exists?(account_id: target_account.id)
  end

  def confirm_user_if_required(user)
    return if user.confirmed?

    user.skip_confirmation!
    user.save!
  end

  def validate_authorization!
    validate_email_domain!
    validate_required_roles!
  end

  def validate_email_domain!
    return if AmeideOidcConfig.allowed_email_domains.blank?

    domain = email.split('@').last.to_s.downcase
    allowed = AmeideOidcConfig.allowed_email_domains.map(&:downcase)
    raise AuthenticationFailed unless allowed.include?(domain)
  end

  def validate_required_roles!
    return if AmeideOidcConfig.required_roles.blank?

    return if roles.intersect?(AmeideOidcConfig.required_roles)

    raise AuthenticationFailed
  end

  def mapped_role
    return 'administrator' if roles.intersect?(AmeideOidcConfig.admin_roles)

    AmeideOidcConfig.default_role
  end

  def target_account
    @target_account ||= Account.find_by!(name: AmeideOidcConfig.account_name)
  end

  def raw_info
    @raw_info ||= @auth_hash.dig('extra', 'raw_info') || {}
  end

  def email
    @email ||= @auth_hash.dig('info', 'email').to_s.downcase
  end

  def name
    @name ||= @auth_hash.dig('info', 'name').presence || [first_name, last_name].compact.join(' ').presence || email.split('@').first
  end

  def first_name
    @auth_hash.dig('info', 'first_name').presence || raw_info['given_name']
  end

  def last_name
    @auth_hash.dig('info', 'last_name').presence || raw_info['family_name']
  end

  def uid
    @auth_hash['uid'].presence || email
  end

  def roles
    @roles ||= begin
      info_roles = Array.wrap(@auth_hash.dig('info', 'roles')).compact.map(&:to_s)
      info_roles.presence || AmeideOidcConfig.roles_from(raw_info)
    end
  end
end
