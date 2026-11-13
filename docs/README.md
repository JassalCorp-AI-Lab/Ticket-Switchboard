# Docs

- `architecture.html` / `architecture.svg` — the architecture diagram.
- `manual-setup.md` — build the stack by hand in the AWS Console.

## The diagram

`architecture.html` is the system architecture diagram. Open it directly in a
browser; it is a single self-contained file with inline SVG, so there are no
images, fonts or scripts to load.

Because the diagram is SVG it scales to any width without blurring, the text
stays selectable and searchable, and **Ctrl/Cmd+P prints it cleanly** (a print
stylesheet drops the page chrome). Hovering a service lifts it, which helps
when tracing a path on screen.

## Icons

The service tiles are the **official AWS Architecture Icons** (asset package
dated 07/31/2026, from <https://aws.amazon.com/architecture/icons/>), inlined
as `<symbol>` definitions so the file stays self-contained.

Each card's border and background tint are derived from the icon's own
category colour, which is why some differ from a hand-picked palette:

| Category | Colour | Services here |
|---|---|---|
| Networking & Content Delivery | `#8C4FFF` | CloudFront, **API Gateway** |
| Compute | `#ED7100` | Lambda (both) |
| Storage | `#7AA116` | S3 |
| Databases | `#C925D1` | DynamoDB |
| Security, Identity & Compliance | `#DD344C` | Cognito |
| Business Applications | `#DD344C` | SES |
| Application Integration | `#E7157B` | SNS |
| Artificial Intelligence | `#01A88D` | Bedrock |

API Gateway is purple rather than orange: it is a Networking service, not a
Compute one. The two non-AWS actors (the browser and the team inbox) use the
generic AWS resource icons on squid-ink `#232F3E`.

AWS provides these icons for use in architecture diagrams under the AWS
Architecture Icons terms on the page linked above. Check them before
publishing externally.

## Exporting a PNG

Open it and screenshot, or:

```bash
chrome --headless --screenshot=architecture.png --window-size=1560,1320 architecture.html
```

## Keeping it current

Resource names in the boxes (`ticket-switchboard-handler`,
`ticket-switchboard-tickets`, the Bedrock model) come from `project/terraform`
and are written into the SVG by hand — they do not update themselves.
