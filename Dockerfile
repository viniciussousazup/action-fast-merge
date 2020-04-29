FROM alpine:latest

LABEL repository="https://github.com/viniciusCSreis/action-fast-merge"
LABEL homepage="https://github.com/viniciusCSreis/action-fast-merge"
LABEL "com.github.actions.name"="Fast Merge"
LABEL "com.github.actions.description"="Fast merge the branch of a PR on another branch"
LABEL "com.github.actions.icon"="git-pull-request"
LABEL "com.github.actions.color"="red"

RUN apk --no-cache add jq bash curl git

ADD entrypoint.sh /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]