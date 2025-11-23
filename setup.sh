#!/bin/bash
set +e  # Don't exit on errors

echo "Fast Cleanup - No waiting"

# Delete ArgoCD app first (stops sync loop)
kubectl delete application job-board -n argocd --wait=false 2>/dev/null
kubectl patch application job-board -n argocd -p '{"metadata":{"finalizers":null}}' --type=merge 2>/dev/null

# Force delete namespaces immediately
kubectl delete namespace job-board --grace-period=0 --force --wait=false 2>/dev/null
kubectl delete namespace argocd --grace-period=0 --force --wait=false 2>/dev/null

# Remove finalizers (this is the key!)
kubectl get namespace job-board -o json 2>/dev/null | jq '.spec.finalizers=[]' | kubectl replace --raw "/api/v1/namespaces/job-board/finalize" -f - 2>/dev/null
kubectl get namespace argocd -o json 2>/dev/null | jq '.spec.finalizers=[]' | kubectl replace --raw "/api/v1/namespaces/argocd/finalize" -f - 2>/dev/null

echo "Waiting 30 seconds for K8s cleanup..."
sleep 30

# AWS cleanup (fast - don't wait for responses)
echo "Cleaning AWS resources..."
aws elbv2 describe-load-balancers --region eu-west-2 --query "LoadBalancers[?contains(LoadBalancerName, 'k8s')].LoadBalancerArn" --output text 2>/dev/null | xargs -n1 -I{} aws elbv2 delete-load-balancer --load-balancer-arn {} --region eu-west-2 2>/dev/null &

sleep 20

aws elbv2 describe-target-groups --region eu-west-2 --query "TargetGroups[?contains(TargetGroupName, 'k8s')].TargetGroupArn" --output text 2>/dev/null | xargs -n1 -I{} aws elbv2 delete-target-group --target-group-arn {} --region eu-west-2 2>/dev/null &

sleep 10

# Terraform destroy
echo "Running terraform destroy..."
cd terraform/ 2>/dev/null
terraform destroy -auto-approve -lock=false

echo "✅ Done! Check: aws eks list-clusters --region eu-west-2"
