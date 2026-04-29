import assert from "node:assert/strict"
import { describe, test } from "node:test"

import { createDiscordWebhookBody } from "./discord-notify.ts"

describe("createDiscordWebhookBody", () => {
  test("puts readable text in content when mentioning so iOS previews are useful", () => {
    const body = createDiscordWebhookBody({
      title: "✅ [dotfiles] Update notifier",
      summary: "Removed Discord mentions from opencode idle notifications.",
      url: "http://100.64.0.1:4096/project/session/ses_example",
      userID: "123456789012345678",
    })

    assert.equal(
      body.content,
      "<@123456789012345678> ✅ [dotfiles] Update notifier",
    )
    assert.deepEqual(body.allowed_mentions, { users: ["123456789012345678"] })
    assert.deepEqual(body.embeds[0], {
      title: "✅ [dotfiles] Update notifier",
      url: "http://100.64.0.1:4096/project/session/ses_example",
      color: 0x57f287,
      description: "Removed Discord mentions from opencode idle notifications.",
    })
  })

  test("uses readable content without allowed mentions when user ID is absent", () => {
    const body = createDiscordWebhookBody({
      title: "✅ [dotfiles] Update notifier",
    })

    assert.equal(body.content, "✅ [dotfiles] Update notifier")
    assert.equal(Object.hasOwn(body, "allowed_mentions"), false)
  })
})
