<!-- LOVABLE:BEGIN -->

> [!IMPORTANT]
> This project is connected to [Lovable](https://lovable.dev). Avoid rewriting
> published git history — force pushing, or rebasing/amending/squashing commits
> that are already pushed — as it rewrites history on Lovable's side and the
> user will likely lose their project history.
>
> Commits you push to the connected branch sync back to Lovable and show up in
> the editor, so keep the branch in a working state.

<!-- LOVABLE:END -->

- Keep farm modules as route-level views under the shared portrait-tablet shell so navigation and safe-area behavior stay consistent.
- Keep AI calls behind the `/api/chat` server route and use route-derived thread IDs so model credentials never reach the browser.
- Store Techi case-thread UI history in browser localStorage because consultation history is device-specific and does not require account sync.
- Store shared poultry case status and Suspection results in a separate browser-local case state so History, case details, and Techi remain synchronized on one device.
- Declare every library that app code imports directly in package.json; a library that only arrives transitively works in the sandbox but fails a clean publish build with an unresolved-import error.
- Keep treatment data, reminders, and notification read state in src/lib/futechi-treatments.ts so Treatment, its detail page, and Notifications stay consistent.
- Reference uploaded application photos through Lovable Assets JSON pointers so replacement media is served consistently without storing binaries in the repository.
