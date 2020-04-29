#!/bin/bash

set -e

failMerge() {

  COMMAND="curl --location --request POST 'https://api.github.com/repos/$GITHUB_REPOSITORY/issues/$2/comments' \
            --header 'Content-Type: application/json' \
            --header 'Authorization: Bearer $1' \
            --data-raw '{
              \"body\": \"$3\"
            }'
            "
  sh -c "$COMMAND"
}

# skip if no /revert
echo "Checking if contains '/fast-merge' command..."
(jq -r ".comment.body" "$GITHUB_EVENT_PATH" | grep -E "/fast-merge") || exit 78

# skip if not a PR
echo "Checking if a PR command..."
(jq -r ".issue.pull_request.url" "$GITHUB_EVENT_PATH") || exit 78

# get the Branch Name
BRANCH_NAME=$(jq -r ".comment.body" "$GITHUB_EVENT_PATH" | cut -c 13- | tr -d '\n' | tr -d '\r')

if [[ "$(jq -r ".action" "$GITHUB_EVENT_PATH")" != "created" ]]; then
  echo "This is not a new comment event!"
  exit 78
fi

PR_NUMBER=$(jq -r ".issue.number" "$GITHUB_EVENT_PATH")
REPO_FULLNAME=$(jq -r ".repository.full_name" "$GITHUB_EVENT_PATH")
echo "Collecting information about PR #$PR_NUMBER of $REPO_FULLNAME..."

if [[ -z "$GITHUB_TOKEN" ]]; then
  echo "Set the GITHUB_TOKEN env variable."
  exit 1
fi

URI=https://api.github.com
API_HEADER="Accept: application/vnd.github.v3+json"
AUTH_HEADER="Authorization: token $GITHUB_TOKEN"

pr_resp=$(curl -X GET -s -H "${AUTH_HEADER}" -H "${API_HEADER}" \
  "${URI}/repos/$REPO_FULLNAME/pulls/$PR_NUMBER")

HEAD_REPO=$(echo "$pr_resp" | jq -r .head.repo.full_name)
HEAD_BRANCH=$(echo "$pr_resp" | jq -r .head.ref)

git remote set-url origin https://x-access-token:$GITHUB_TOKEN@github.com/$REPO_FULLNAME.git
git config --global user.email "fast-merge@github.com"
git config --global user.name "GitHub Fast Merge Action"

set -o xtrace

git fetch origin $HEAD_BRANCH
git fetch origin $BRANCH_NAME || failMerge $GITHUB_TOKEN $PR_NUMBER "Branch Not Found."
git checkout $BRANCH_NAME
git pull origin $HEAD_BRANCH || failMerge $GITHUB_TOKEN $PR_NUMBER "Fail to Merge."
git push

LABEL_NAME="FAST-MERGED"
label_resp=$(curl -X GET -s -H "${AUTH_HEADER}" -H "${API_HEADER}" \
  "${URI}/repos/$REPO_FULLNAME/labels/$LABEL_NAME")

LABEL_MESSAGE=$(echo "$label_resp" | jq -r .message)
echo "$LABEL_MESSAGE"

if ["$LABEL_MESSAGE" = "Not Found"]; then
  body= "{
    \"name\": \"$LABEL_NAME\",
    \"description\": \"This PR successfully used FAST-MERGE command.\",
    \"color\": \"c0c5ce\"
  }"
  curl -X POST -s --data-raw "$body" -H "${AUTH_HEADER}" -H "${API_HEADER}" \
    "${URI}/repos/$REPO_FULLNAME/issues/$PR_NUMBER/labels"
fi

curl -X POST -s --data-raw "{\"labels\": [\"${LABEL_NAME}\"] }" -H "${AUTH_HEADER}" -H "${API_HEADER}" \
  "${URI}/repos/$REPO_FULLNAME/issues/$PR_NUMBER/labels"

SUCCESS_MSG="Merged with success."
curl -X POST -s --data-raw "{\"body\": \"$SUCCESS_MSG\" }" -H "${AUTH_HEADER}" -H "${API_HEADER}" \
  "${URI}/repos/$REPO_FULLNAME/issues/$PR_NUMBER/comments"

# # do the revert
# git checkout -b $HEAD_BRANCH origin/$HEAD_BRANCH

# # check commit exists
# git cat-file -t $COMMIT_TO_REVERT
# git revert $COMMIT_TO_REVERT --no-edit
# git push origin $HEAD_BRANCH
