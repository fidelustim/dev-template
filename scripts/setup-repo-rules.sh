#!/usr/bin/env bash
# Приводит репозиторий к правилам gitflow средствами самого GitHub.
# На публичных репозиториях работает на бесплатном плане.
#
# Использование:  ./scripts/setup-repo-rules.sh [owner/repo]
set -euo pipefail

REPO="${1:-$(gh repo view --json nameWithOwner -q .nameWithOwner)}"
echo "Репозиторий: $REPO"

echo "→ Разрешаю только squash-merge, ветка удаляется после мерджа"
gh api -X PATCH "repos/$REPO" \
  -F allow_squash_merge=true \
  -F allow_merge_commit=false \
  -F allow_rebase_merge=false \
  -F delete_branch_on_merge=true >/dev/null

PAYLOAD="$(mktemp)"
cat > "$PAYLOAD" <<'JSON'
{
  "name": "gitflow",
  "target": "branch",
  "enforcement": "active",
  "conditions": {
    "ref_name": {
      "include": ["refs/heads/main", "refs/heads/develop"],
      "exclude": []
    }
  },
  "rules": [
    { "type": "deletion" },
    { "type": "non_fast_forward" },
    {
      "type": "pull_request",
      "parameters": {
        "required_approving_review_count": 0,
        "dismiss_stale_reviews_on_push": true,
        "require_code_owner_review": false,
        "require_last_push_approval": false,
        "required_review_thread_resolution": true
      }
    },
    {
      "type": "required_status_checks",
      "parameters": {
        "strict_required_status_checks_policy": true,
        "do_not_enforce_on_create": false,
        "required_status_checks": [{ "context": "Lint & tests" }]
      }
    }
  ]
}
JSON

echo "→ Правила для main и develop (только через PR + зелёный CI)"
RULESET_ID="$(gh api "repos/$REPO/rulesets" --jq '.[] | select(.name=="gitflow") | .id' 2>/dev/null | head -1 || true)"
if [ -n "${RULESET_ID:-}" ]; then
  gh api -X PUT "repos/$REPO/rulesets/$RULESET_ID" --input "$PAYLOAD" >/dev/null
  echo "   обновлён ruleset #$RULESET_ID"
else
  gh api -X POST "repos/$REPO/rulesets" --input "$PAYLOAD" >/dev/null
  echo "   создан ruleset gitflow"
fi
rm -f "$PAYLOAD"

echo "Готово. Прямой пуш в main/develop отклоняет сам GitHub."
