# Makefile — Portal Escarlate
# Atalhos para build, deploy Docker e Kubernetes.
#
# Uso:
#   make docker-build   → builda todas as imagens
#   make docker-up      → sobe o stack de produção
#   make docker-down    → para e remove os containers
#   make k8s-build      → builda e carrega imagens no Minikube
#   make k8s-apply      → aplica o manifesto Kubernetes
#   make k8s-urls       → exibe as URLs dos serviços no Minikube

# ---------------------------------------------------------------------------
# Docker Compose (produção)
# ---------------------------------------------------------------------------

.PHONY: docker-build
docker-build:
	docker build -t portal-escarlate-node:latest .
	docker build -t portal-escarlate-dart:latest \
	  --build-arg APP=api_gateway ./backend-dart
	docker build -t portal-escarlate-dart-auth:latest \
	  --build-arg APP=auth_service ./backend-dart
	docker build -t portal-escarlate-dart-registration:latest \
	  --build-arg APP=registration_service ./backend-dart
	docker build -t portal-escarlate-dart-recovery:latest \
	  --build-arg APP=password_recovery_service ./backend-dart
	docker build -t portal-escarlate-dart-email:latest \
	  --build-arg APP=email_service ./backend-dart

.PHONY: docker-up
docker-up:
	docker compose -f docker-compose.prod.yml up --build -d

.PHONY: docker-down
docker-down:
	docker compose -f docker-compose.prod.yml down

.PHONY: docker-logs
docker-logs:
	docker compose -f docker-compose.prod.yml logs -f

.PHONY: docker-ps
docker-ps:
	docker compose -f docker-compose.prod.yml ps

# ---------------------------------------------------------------------------
# Kubernetes (Minikube)
# ---------------------------------------------------------------------------

.PHONY: k8s-build
k8s-build: docker-build
	minikube image load portal-escarlate-node:latest
	minikube image load portal-escarlate-dart:latest
	minikube image load portal-escarlate-dart-auth:latest
	minikube image load portal-escarlate-dart-registration:latest
	minikube image load portal-escarlate-dart-recovery:latest
	minikube image load portal-escarlate-dart-email:latest

.PHONY: k8s-secret
k8s-secret:
	kubectl create secret generic portal-escarlate-env \
	  --from-literal=PORTAL_DB_PASSWORD=$$(grep PORTAL_DB_PASSWORD .env | cut -d= -f2) \
	  --from-literal=AUTH_SECRET=$$(grep ^AUTH_SECRET .env | cut -d= -f2) \
	  --from-literal=PORTAL_INTERNAL_TOKEN=$$(grep PORTAL_INTERNAL_TOKEN .env | cut -d= -f2) \
	  --from-literal=SECRETS_ENCRYPTION_KEY=$$(grep SECRETS_ENCRYPTION_KEY .env | cut -d= -f2) \
	  --from-literal=GOOGLE_CLIENT_ID=$$(grep GOOGLE_CLIENT_ID .env | cut -d= -f2) \
	  --from-literal=GOOGLE_CLIENT_SECRET=$$(grep GOOGLE_CLIENT_SECRET .env | cut -d= -f2) \
	  --dry-run=client -o yaml | kubectl apply -f -

.PHONY: k8s-apply
k8s-apply:
	kubectl apply -f kubernetes/portal-escarlate.yaml

.PHONY: k8s-delete
k8s-delete:
	kubectl delete -f kubernetes/portal-escarlate.yaml

.PHONY: k8s-urls
k8s-urls:
	@echo "=== URLs dos serviços ==="
	@minikube service dart-gateway --url 2>/dev/null | sed 's/^/Dart Gateway (3100): /'
	@minikube service node-gateway --url 2>/dev/null | sed 's/^/Node Gateway (3000): /'
	@minikube service frontend --url 2>/dev/null | sed 's/^/Frontend (5173):     /'

.PHONY: k8s-status
k8s-status:
	kubectl get pods,services

.PHONY: k8s-logs
k8s-logs:
	kubectl logs -l app=dart-gateway --tail=50
