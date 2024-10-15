temporal-workflow-list-ids() {
  temporal workflow list --output json | jq -r '.[] | "\(.execution.workflowId) \(.execution.runId)"'
}

temporal-cancel-all() {
  local r w
  temporal-workflow-list-ids | while read w r; do temporal workflow cancel -w $w -r $r; done
}

temporal-delete-all() {
  local r w
  temporal-workflow-list-ids | while read w r; do temporal workflow delete -w $w -r $r; done
}

temporal-server() {
  temporal --log-format json server start-dev \
    --dynamic-config-value frontend.enableUpdateWorkflowExecution=true \
    --dynamic-config-value frontend.enableUpdateWorkflowExecutionAsyncAccepted=true "$@" |&
    pretty-logs
}

temporal-terminate-all() {
  local r w
  temporal-workflow-list-ids | while read w r; do temporal workflow terminate -w $w -r $r; done
}

temporal-workflow-start() {
  local workflow_type="$1"
  local task_queue="${2:-my-task-queue}"
  read w r < <(
    temporal workflow start --type="$workflow_type" --input "{}" --task-queue="$task_queue" --output json |
      tee 1>&2 |
      rg -v '^Running execution:' |
      jq -r '.[0] | "\(.WorkflowId) \(.RunId)"'
  )
}

temporal-github-actions-delete-runs() {
  for i in $(seq 1 5); do
    gh-api '/repos/temporalio/oss-cicd/actions/runs?branch=OSS-1489-nightly-pipelines-dev' |
      jq -r '.workflow_runs[] | select(.actor.login == "dandavison") | "\(.id) \(.display_title)"' |
      grep -v poll |
      cut -d' ' -f 1 |
      while read run_id; do gh-api --method DELETE /repos/temporalio/oss-cicd/actions/runs/$run_id; done | sort
  done
}

kubectl-set-namespace() {
  until kubectl get namespaces >/dev/null 2>&1; do sleep 1; done
  local namespace=$(kubectl get namespaces | sed 1d | rg -v '(^kube|^default|^local)' | awk '{print $1}')
  if [ -z "$namespace" ]; then
    kubectl get namespaces 1>&2
    return 1
  fi
  echo "setting namespace: $namespace"
  kubectl config set-context --current --namespace $namespace
}

omes-check-metrics() {
  kubectl-set-namespace
  until kubectl get pods | rg omes-worker >/dev/null; do
    echo -n "."
    sleep 1
  done
  echo
  pod=$(kubectl get pods | rg omes-worker | sed 1q | awk '{print $1}')
  echo "pod: $pod"
  echo "curl localhost:7777/metrics"
  until kubectl port-forward $pod 7777:9090; do
    echo -n "."
    sleep 1
  done
}

github-list-prs() {
  curl -H "Authorization: bearer $GITHUB_TOKEN" -X POST -d '
{
  "query": "query {
    search(query: \"is:pr author:dandavison created:>=2023-06-01\", type: ISSUE, first: 100) {
      edges {
        node {
          ... on PullRequest {
            title
            repository {
              nameWithOwner
            }
            createdAt
            url
          }
        }
      }
    }
  }"
}' https://api.github.com/graphql
}

# # omni shell integration
# eval "$(omni hook init zsh)"

# {
#   search(
#     query: "is:pr author:dandavison created:>=2023-06-01"
#     type: ISSUE
#     first: 100
#   ) {
#     edges {
#       node {
#         ... on PullRequest {
#           title
#           repository {
#             nameWithOwner
#           }
#           createdAt
#           url
#         }
#       }
#     }
#   }
# }
