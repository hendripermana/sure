require "test_helper"

class ActiveStorage::SecureUrlServiceTest < ActiveSupport::TestCase
  test "creates a signed URL for an attached profile image" do
    user = users(:family_admin)
    image = Rack::Test::UploadedFile.new(Rails.root.join("test/fixtures/files/profile_image.png"), "image/png")
    user.profile_image.attach(image)

    url = ActiveStorage::SecureUrlService.for_attachment(user.profile_image, variant: :small, expires_in: 5.minutes, disposition: :inline)

    assert_not_nil url
    assert_includes url, "https://"
    assert_match %r{/rails/active_storage/}, url
  end

  test "returns nil for an unattached attachment" do
    user = users(:family_admin)

    assert_nil ActiveStorage::SecureUrlService.for_attachment(user.profile_image, expires_in: 5.minutes)
  end
end
