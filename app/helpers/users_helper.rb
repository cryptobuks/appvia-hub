module UsersHelper
  def update_user_role_link(text, user, role)
    link_to text,
      user_role_path(user),
      remote: true,
      method: :put,
      class: 'btn btn-primary float-right',
      data: {
        params: { role: role }.to_param,
        turbolinks: false,
        'disable-with': 'Processing...'
      },
      role: 'button'
  end
end
