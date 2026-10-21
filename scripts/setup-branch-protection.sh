#!/usr/bin/env bash
# Включает защиту веток main и develop в текущем репозитории GitHub.
# Требуется scope 'repo' у gh-токена.
#
# Использование:  ./scripts/setup-branch-protection.sh [owner/repo]
set -euo pipefail

REPO="${1:-$(gh repo view --json nameWithOwner -q .nameWithOwner)}"
echo "Настраиваю защиту веток для: $REPO"

for BRANCH in main develop; do
  echo "  → $BRANCH"
  gh api -X PUT "repos/$REPO/branches/$BRANCH/protection" \
    -H "Accept: application/vnd.github+json" \
    -f "required_status_checks[strict]=true" \
    -f "required_status_checks[contexts][]=Lint & tests" \
    -f "enforce_admins=true" \
    -f "required_pull_request_reviews[required_approving_review_count]=1" \
    -f "required_pull_request_reviews[dismiss_stale_reviews]=true" \
    -f "restrictions=" \
    -F "allow_force_pushes=false" \
    -F "allow_deletions=false" >/dev/null
done

echo "Готово. Прямые пуши в main/develop теперь запрещены."
