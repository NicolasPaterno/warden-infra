COMPOSE_FILE=local/docker-compose.yml
K8S_NS=warden
GATEWAY_IMAGE=warden-gateway:local
GATEWAY_DIR=../warden-gateway

# ── Minikube ─────────────────────────────────────────────────────────────────
minikube-start:
	minikube start --driver=docker --cpus=2 --memory=4096

minikube-stop:
	minikube stop

# Build the gateway image locally and load it into minikube
minikube-load:
	docker build -t $(GATEWAY_IMAGE) $(GATEWAY_DIR)
	minikube image load $(GATEWAY_IMAGE)

# Override running deployment to use local image (minikube only)
minikube-set-image:
	kubectl set image deployment/warden-gateway gateway=$(GATEWAY_IMAGE) -n $(K8S_NS)

# Full K8s dev setup from scratch: start cluster + load image + apply all manifests
dev-k8s: minikube-start minikube-load k8s-apply minikube-set-image

# ── Docker (local stack) ──────────────────────────────────────────────────────
up:
	docker compose -f $(COMPOSE_FILE) up -d

down:
	docker compose -f $(COMPOSE_FILE) down

down-v:
	docker compose -f $(COMPOSE_FILE) down -v

logs:
	docker compose -f $(COMPOSE_FILE) logs -f

ps:
	docker compose -f $(COMPOSE_FILE) ps

monitoring-up:
	docker compose -f $(COMPOSE_FILE) up -d prometheus grafana jaeger

monitoring-down:
	docker compose -f $(COMPOSE_FILE) stop prometheus grafana jaeger

monitoring-logs:
	docker compose -f $(COMPOSE_FILE) logs -f prometheus grafana jaeger

# ── Kubernetes — namespace ────────────────────────────────────────────────────
k8s-namespace:
	kubectl apply -f k8s/base/namespace.yml

# ── Kubernetes — base infrastructure ─────────────────────────────────────────
k8s-base: k8s-namespace
	kubectl apply -f k8s/base/postgres-deployment.yml
	kubectl apply -f k8s/base/nats-deployment.yml
	kubectl apply -f k8s/base/redis-deployment.yml

# ── Kubernetes — secrets (requires secret.env files — never committed) ────────
k8s-secrets: k8s-namespace
	kubectl create secret generic postgres-secret \
		--from-env-file=k8s/base/secret.env \
		--namespace=$(K8S_NS) \
		--dry-run=client -o yaml | kubectl apply -f -
	kubectl create secret generic gateway-secret \
		--from-env-file=k8s/gateway/secret.env \
		--namespace=$(K8S_NS) \
		--dry-run=client -o yaml | kubectl apply -f -

# ── Kubernetes — migrations (runs once before deploy, waits for completion) ───
k8s-migrate: k8s-namespace
	kubectl apply -f k8s/gateway/migrations-configmap.yml
	kubectl delete job gateway-migrate -n $(K8S_NS) --ignore-not-found
	kubectl apply -f k8s/gateway/migrations-job.yml
	kubectl wait --for=condition=complete job/gateway-migrate -n $(K8S_NS) --timeout=120s

# ── Kubernetes — gateway (always runs after migrations) ───────────────────────
k8s-gateway: k8s-namespace k8s-migrate
	kubectl apply -f k8s/gateway/configmap.yml
	kubectl apply -f k8s/gateway/deployment.yml
	kubectl apply -f k8s/gateway/service.yml
	kubectl apply -f k8s/gateway/hpa.yml

# ── Kubernetes — apply everything ────────────────────────────────────────────
k8s-apply: k8s-base k8s-secrets k8s-gateway

# ── Kubernetes — status ───────────────────────────────────────────────────────
k8s-status:
	kubectl get all -n $(K8S_NS)

k8s-pods:
	kubectl get pods -n $(K8S_NS) -o wide

k8s-logs:
	kubectl logs -n $(K8S_NS) -l app=warden-gateway --tail=50 -f

# ── Kubernetes — teardown ─────────────────────────────────────────────────────
k8s-delete-gateway:
	kubectl delete -f k8s/gateway/ --ignore-not-found

k8s-delete-all:
	kubectl delete namespace $(K8S_NS) --ignore-not-found

.PHONY: minikube-start minikube-stop minikube-load minikube-set-image dev-k8s \
        up down down-v logs ps \
        monitoring-up monitoring-down monitoring-logs \
        k8s-namespace k8s-base k8s-secrets k8s-migrate k8s-gateway k8s-apply \
        k8s-status k8s-pods k8s-logs \
        k8s-delete-gateway k8s-delete-all
