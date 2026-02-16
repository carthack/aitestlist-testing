---
description: "Check AI TestList connection status, token, MCP Playwright, and payment config"
---

Verify the following components and report status for each:

1. **URL**: Resolve `${AITESTLIST_URL:-http://localhost:8001}` - store as URL
2. **Token**: Run `echo $AITESTLIST_TOKEN` - is it defined?
3. **API**: Call `curl -s -H "Authorization: Bearer $AITESTLIST_TOKEN" "${URL}/api/status"` - is the server reachable?
4. **Language**: Call `curl -s -H "Authorization: Bearer $AITESTLIST_TOKEN" "${URL}/api/language"` - what language is configured?
5. **MCP Playwright**: Try `browser_navigate` to a simple page - is Playwright available?
6. **Exec Mode**: Call `curl -s -H "Authorization: Bearer $AITESTLIST_TOKEN" "${URL}/api/settings/exec-mode"` - what mode and payment config?
7. **Teams Mode**: Check `~/.claude/settings.json` for `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS`

Display a summary table with status icons for each component.
