---
description: "Check AI TestList connection status, token, MCP Playwright, and payment config"
---

Verify the following components and report status for each:

1. **Token**: Run `echo $AITESTLIST_TOKEN` - is it defined?
2. **API**: Call `curl -s -H "Authorization: Bearer $AITESTLIST_TOKEN" "http://localhost:8001/api/status"` - is the server reachable?
3. **Language**: Call `curl -s -H "Authorization: Bearer $AITESTLIST_TOKEN" "http://localhost:8001/api/language"` - what language is configured?
4. **MCP Playwright**: Try `browser_navigate` to a simple page - is Playwright available?
5. **Exec Mode**: Call `curl -s -H "Authorization: Bearer $AITESTLIST_TOKEN" "http://localhost:8001/api/settings/exec-mode"` - what mode and payment config?
6. **Teams Mode**: Check `~/.claude/settings.json` for `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS`

Display a summary table with status icons for each component.
