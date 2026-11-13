# Preview

`index-preview.html` is a **static mock of the deployed front end**. Open it
directly in a browser — double-click it, no server needed.

It is generated from
[`../terraform/frontend/index.html.tftpl`](../terraform/frontend/index.html.tftpl)
with placeholder config values, plus a small harness at the bottom of the file
that stubs Cognito and the API. Nothing here talks to AWS.

Use the bar at the bottom of the page to switch between:

- **Signed out** — the landing card with the *Login with Cognito* button
- **Employee** — the ticket form (no *View All Tickets* button; that is
  `it-staff` only)
- **IT staff** — the ticket form plus *View All Tickets*, which renders five
  sample tickets

Submitting the form returns a canned classification after a short delay, so you
can see the success banner with the category / priority pills.

> This file is **not deployed**. Terraform renders the real page from the
> `.tftpl` at apply time and uploads it to S3. If you change the template,
> regenerate this preview rather than editing it directly.
