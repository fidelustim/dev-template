#!/usr/bin/env bash
# Приводит репозиторий к правилам gitflow.
#
# Часть 1 — настройки репозитория: разрешён только squash-merge, ветка удаляется
#            после мерджа. Работает и на бесплатном плане (проверено).
# Часть 2 — защита веток main/develop: для ПРИВАТНЫХ репозиториев нужен платный
#            план (Pro и выше), иначе GitHub отвечает HTTP 403.
#
# Использование:  ./scripts/setup-branch-protection.sh [owner/repo]
# Переменные:     REQUIRED_APPROVALS=1 — требовать одобрение ревью.
#   Только если в репозитории есть ВТОРОЙ аккаунт с правом записи: GitHub
#   запрещает одобрять собственный PR, поэтому при одном аккаунте
#   (агенте и владельце) REQUIRED_APPROVALS=1 заблокирует все мерджи.
set -euo pipefail

REPO="${1:-$(gh repo view --json nameWithOwner -q .nameWithOwner)}"
APPROVALS="${REQUIRED_APPROVALS:-0}"

echo "Репозиторий: $REPO"
echo "→ Только squash-merge + авто-удаление ветки"
gh api -X PATCH "repos/$REPO" \
  -F allow_squash_merge=true \
  -F allow_merge_commit=false \
  -F allow_rebase_merge=false \
  -F delete_branch_on_merge=true >/dev/null

echo "→ Защита веток main и develop (приватный репо без Pro — откажет)"
for BRANCH in main develop; do
  echo "   • $BRANCH"
  if gh api -X PUT "repos/$REPO/branches/$BRANCH/protection" \
      -H "Accept: application/vnd.github+json" \
      -f "required_status_checks[strict]=true" \
      -f "required_status_checks[contexts][]=Lint & tests" \
      -f "enforce_admins=true" \
      -f "required_pull_request_reviews[required_approving_review_count]=$APPROVALS" \
      -f "required_pull_request_reviews[dismiss_stale_reviews]=true" \
      -f "required_conversation_resolution=true" \
      -f "restrictions=" \
      -F "allow_force_pushes=false" \
      -F "allow_deletions=false" >/dev/null 2>&1; then
    echo "     ✓ защита включена (одобрений требуется: $APPROVALS)"
  else
    echo "     ✗ GitHub отказал — для приватного репозитория нужен платный план." >&2
    exit 1
  fi
done

echo "Готово."
