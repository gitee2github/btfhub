#!/usr/bin/env bash

set -e

SCRIPT_NAME="$(basename "$0")"
GITEE_API_BASE_URL="https://gitee.com/api/v5"

info() {
    echo "$SCRIPT_NAME: info:" "$@"
}

error() {
    echo "$SCRIPT_NAME: error:" "$@"
}

prepare_api_token() {
    if [[ -z "$BTFHUB_GITEE_API_TOKEN" ]]; then
        error "missing required BTFHUB_GITEE_API_TOKEN"
        exit 1
    fi
    info "using BTFHUB_GITEE_API_TOKEN: $BTFHUB_GITEE_API_TOKEN"
}

prepare_archive_repo() {
    if [[ -z "$BTFHUB_ARCHIVE_REPO" ]]; then
        BTFHUB_ARCHIVE_REPO="$(git remote get-url origin \
            | sed 's/^https:\/\/gitee.com\///' \
            | sed 's/^git@gitee.com://' \
            | sed 's/.git$//')"
    fi
    info "using BTFHUB_ARCHIVE_REPO: $BTFHUB_ARCHIVE_REPO"
}

prepare_pr_head() {
    if [[ -z "$BTFHUB_ARCHIVE_PR_HEAD" ]]; then
        BTFHUB_ARCHIVE_PR_HEAD="$(git branch --show-current)"
    fi
    info "using BTFHUB_ARCHIVE_PR_HEAD: $BTFHUB_ARCHIVE_PR_HEAD"
}

prepare_pr_base() {
    if [[ -z "$BTFHUB_ARCHIVE_PR_BASE" ]]; then
        # Try to find the default branch; if that fails, try 'master' or 'main'.
        if git rev-parse --abbrev-ref origin/HEAD > /dev/null 2>&1; then
            BTFHUB_ARCHIVE_PR_BASE="$(git rev-parse --abbrev-ref origin/HEAD | sed 's/^origin\///')"
        elif git ls-remote --exit-code --heads origin master; then
            BTFHUB_ARCHIVE_PR_BASE=master
        elif git ls-remote --exit-code --heads origin main; then
            BTFHUB_ARCHIVE_PR_BASE=main
        else
            error "cannot determine base branch for the PR"
            exit 1
        fi
    fi
    info "using BTFHUB_ARCHIVE_PR_BASE: $BTFHUB_ARCHIVE_PR_BASE"
}

prepare_pr_title() {
    if [[ -z "$BTFHUB_ARCHIVE_PR_TITLE" ]]; then
        BTFHUB_ARCHIVE_PR_TITLE="Update BTF files"
    fi
    info "using BTFHUB_ARCHIVE_PR_TITLE: $BTFHUB_ARCHIVE_PR_TITLE"
}

prepare_pr_body() {
    if [[ -z "$BTFHUB_ARCHIVE_PR_BODY" ]]; then
        BTFHUB_ARCHIVE_PR_BODY="$(printf '%s\n' \
            'This PR updates BTF files in this repository.' \
            '' \
            "Commits and changes included in this PR are created by an automated CI pipeline; visit [**$JOB_NAME**]($JOB_URL) for details.")"
    fi
    info "$(printf 'using BTFHUB_ARCHIVE_PR_BODY: %q' "$BTFHUB_ARCHIVE_PR_BODY")"
}

check_branches() {
    if git rev-parse --is-inside-work-tree > /dev/null 2>&1 && \
        [[ "$(git rev-list --count "origin/$BTFHUB_ARCHIVE_PR_BASE..origin/$BTFHUB_ARCHIVE_PR_HEAD")" == "0" ]]; then
        info "no need to create PR: the base branch $BTFHUB_ARCHIVE_PR_BASE is already up-to-date with the head branch $BTFHUB_ARCHIVE_PR_HEAD"
        exit 0
    fi
}

check_existing_pr() {
    local existing_pr_url
    existing_pr_url="$(printf '%s/repos/%s/pulls?state=open&head=%s&base=%s' \
        "$GITEE_API_BASE_URL" \
        "$BTFHUB_ARCHIVE_REPO" \
        "$BTFHUB_ARCHIVE_PR_HEAD" \
        "$BTFHUB_ARCHIVE_PR_BASE" \
        | xargs curl -sS --fail-with-body \
        | jq -r '.[].html_url')"
    if [[ -n "$existing_pr_url" ]]; then
        info "no need to create PR: PR already exists and is still open: $existing_pr_url"
        exit 0
    fi
}

do_create_pr() {
    local create_pr_request create_pr_response
    create_pr_request="$(echo '{}' \
        | jq -c ".access_token = \"$BTFHUB_GITEE_API_TOKEN\"" \
        | jq -c ".head = \"$BTFHUB_ARCHIVE_PR_HEAD\"" \
        | jq -c ".base = \"$BTFHUB_ARCHIVE_PR_BASE\"" \
        | jq -c ".title = \"$BTFHUB_ARCHIVE_PR_TITLE\"" \
        | jq -c ".body = \"$BTFHUB_ARCHIVE_PR_BODY\"")"
    if ! create_pr_response="$(curl -sS --fail-with-body -X POST -d "$create_pr_request" \
        -H 'Content-Type: application/json;charset=UTF-8' \
        -H 'Accept: application/json;charset=UTF-8' \
        "$GITEE_API_BASE_URL/repos/$BTFHUB_ARCHIVE_REPO/pulls")"; then
        error "failed to create PR: $(echo "$create_pr_response" | jq -r .message)"
        exit 1
    fi
    info "successfully created PR: $(echo "$create_pr_response" | jq -r '.html_url')"
}

prepare_variables() {
    info "preparing variables"

    prepare_api_token
    prepare_archive_repo
    prepare_pr_head
    prepare_pr_base
    prepare_pr_title
    prepare_pr_body
}

create_pr() {
    info "creating PR"

    check_branches
    check_existing_pr

    do_create_pr
}

main() {
    prepare_variables
    create_pr
}

main "$@"
