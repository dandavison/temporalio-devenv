ot() {
    omni temporal --yes --namespace oss-cicd.e2e "$@"
}
_ot() {
    words[1]=temporal
    _temporal
}
compdef _ot ot


temporal-bench-go-setup() {
	temporal operator namespace create -n default
	temporal operator search-attribute create --name CustomStringField --type Text || true
	temporal operator search-attribute create --name CustomKeywordField --type Keyword || true
	temporal operator nexus endpoint create --name bench-endpoint --target-namespace default --target-task-queue temporal-bench || true
}

temporal-ui-start() {
  if docker ps -q -f name=^temporal-ui$ | grep -q .; then
    echo "temporal-ui already running"
  elif docker ps -aq -f name=^temporal-ui$ | grep -q .; then
    docker start temporal-ui
  else
    docker run -d -p 8080:8080 -e TEMPORAL_ADDRESS=host.docker.internal:7233 --name temporal-ui temporalio/ui:latest
  fi
}

temporal-ui-stop() {
  docker stop temporal-ui 2>/dev/null || true
}

temporal-workflow-list-ids() {
  local namespace="${1:-default}"
  temporal workflow list --namespace "$namespace" --output json | jq -r '.[] | "\(.execution.workflowId) \(.execution.runId)"'
}

temporal-cancel-all() {
  local namespace="${1:-default}"
  local r w
  temporal-workflow-list-ids "$namespace" | while read w r; do temporal workflow --namespace "$namespace" cancel -w $w -r $r; done
}

temporal-delete-all() {
  local namespace="${1:-default}"
  local r w
  temporal-workflow-list-ids "$namespace" | while read w r; do temporal workflow --namespace "$namespace" delete -w $w -r $r; done
}

temporal-go-test-branch() {
  gds --name-only main... **/*_test.go | t-go-test
}

temporal-go-test() {
    xargs -I{} dirname {} | \
    sort -u | \
    xargs -I{} go test -p 8 -v -count 1 -tags test_dep go.temporal.io/server/{}
}

temporal-server() {
  temporal --log-format json server start-dev \
    --dynamic-config-value frontend.enableUpdateWorkflowExecution=true \
    --dynamic-config-value frontend.enableUpdateWorkflowExecutionAsyncAccepted=true "$@" |&
    pretty-logs
}

temporal-terminate-all() {
  local namespace="${1:-default}"
  local r w
  temporal-workflow-list-ids "$namespace" | while read w r; do temporal workflow --namespace "$namespace" terminate -w $w -r $r; done
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

sdk-java-kill-all() {
  # Kill Temporal server
  pkill -f "temporal server" || true

  # Kill HandlerWorker processes
  pkill -f "HandlerWorker" || true

  # Kill CallerWorker processes
  pkill -f "CallerWorker" || true

  # Kill any gradle execute processes related to nexus samples
  pkill -f "gradle.*execute.*nexus" || true

  # Kill any remaining gradle execute processes
  pkill -f "gradle.*execute" || true

  # Verify all processes are killed
  ps aux | grep -E "(temporal|nexus|gradle.*execute)" | grep -v grep
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
