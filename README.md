# Usage

```yml

name: "Fast Merge"
on:
  issue_comment:
    types: [created]

jobs:
  fast-merge:

    runs-on: ubuntu-latest

    if: contains(github.event.comment.body, '/fast-merge')

    steps:
      - uses: actions/checkout@v1
      - name: Fast Merge
        uses: viniciusCSreis/action-fast-merge@master
        with:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}

```
