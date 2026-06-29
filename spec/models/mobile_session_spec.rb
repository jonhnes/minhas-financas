require "rails_helper"

RSpec.describe MobileSession, type: :model do
  def expect_expiration_near(time, ttl)
    expect(time).to be_between(ttl.from_now - 5.seconds, ttl.from_now + 5.seconds)
  end

  it "issues regular mobile access tokens for 15 minutes" do
    issued = described_class.issue_for!(
      user: create(:user),
      platform: "ios",
      device_label: "iPhone"
    )

    expect_expiration_near(issued.fetch(:session).expires_at, described_class::ACCESS_TOKEN_TTL)
  end

  it "issues MCP access tokens for 24 hours" do
    issued = described_class.issue_for!(
      user: create(:user),
      platform: "mcp",
      device_label: "Codex MCP"
    )

    expect_expiration_near(issued.fetch(:session).expires_at, described_class::MCP_ACCESS_TOKEN_TTL)
  end

  it "keeps regular mobile access tokens at 15 minutes when rotating" do
    session = described_class.issue_for!(
      user: create(:user),
      platform: "android",
      device_label: "Pixel"
    ).fetch(:session)

    session.rotate_tokens!

    expect_expiration_near(session.reload.expires_at, described_class::ACCESS_TOKEN_TTL)
  end

  it "keeps MCP access tokens at 24 hours when rotating" do
    session = described_class.issue_for!(
      user: create(:user),
      platform: "mcp",
      device_label: "Codex MCP"
    ).fetch(:session)

    session.rotate_tokens!

    expect_expiration_near(session.reload.expires_at, described_class::MCP_ACCESS_TOKEN_TTL)
  end
end
