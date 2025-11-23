#!/bin/bash

VPC_ID="vpc-03269083e4931d2f1"
REGION="eu-west-2"

echo "=========================================="
echo "VPC DEPENDENCY CLEANUP"
echo "=========================================="

# 1. Delete Load Balancers
echo ""
echo "Step 1: Deleting Load Balancers..."
aws elbv2 describe-load-balancers --region $REGION \
  --query "LoadBalancers[?VpcId=='$VPC_ID'].LoadBalancerArn" \
  --output text | tr '\t' '\n' | while read ALB; do
    if [ -n "$ALB" ]; then
      echo "  Deleting ALB: $ALB"
      aws elbv2 delete-load-balancer --load-balancer-arn "$ALB" --region $REGION 2>/dev/null
    fi
done

echo "  Waiting 30 seconds for ALBs to delete..."
sleep 30

# 2. Delete Target Groups
echo ""
echo "Step 2: Deleting Target Groups..."
aws elbv2 describe-target-groups --region $REGION \
  --query "TargetGroups[].TargetGroupArn" \
  --output text | tr '\t' '\n' | while read TG; do
    # Check if TG is in our VPC
    TG_VPC=$(aws elbv2 describe-target-groups --target-group-arns "$TG" --region $REGION --query 'TargetGroups[0].VpcId' --output text 2>/dev/null)
    if [ "$TG_VPC" = "$VPC_ID" ]; then
      echo "  Deleting TG: $TG"
      aws elbv2 delete-target-group --target-group-arn "$TG" --region $REGION 2>/dev/null
    fi
done

sleep 10

# 3. Delete Network Interfaces (ENIs)
echo ""
echo "Step 3: Detaching and deleting Network Interfaces..."
aws ec2 describe-network-interfaces \
  --filters "Name=vpc-id,Values=$VPC_ID" \
  --region $REGION \
  --query 'NetworkInterfaces[].NetworkInterfaceId' \
  --output text | tr '\t' '\n' | while read ENI; do
    if [ -n "$ENI" ]; then
      echo "  Processing ENI: $ENI"
      
      # Get attachment ID
      ATTACHMENT_ID=$(aws ec2 describe-network-interfaces \
        --network-interface-ids "$ENI" \
        --region $REGION \
        --query 'NetworkInterfaces[0].Attachment.AttachmentId' \
        --output text 2>/dev/null)
      
      # Detach if attached
      if [ "$ATTACHMENT_ID" != "None" ] && [ -n "$ATTACHMENT_ID" ]; then
        echo "    Detaching..."
        aws ec2 detach-network-interface \
          --attachment-id "$ATTACHMENT_ID" \
          --region $REGION \
          --force 2>/dev/null
        sleep 5
      fi
      
      # Delete ENI
      echo "    Deleting..."
      aws ec2 delete-network-interface \
        --network-interface-id "$ENI" \
        --region $REGION 2>/dev/null || echo "    (in use or already deleted)"
    fi
done

sleep 10

# 4. Delete NAT Gateways
echo ""
echo "Step 4: Deleting NAT Gateways..."
aws ec2 describe-nat-gateways \
  --filter "Name=vpc-id,Values=$VPC_ID" "Name=state,Values=available" \
  --region $REGION \
  --query 'NatGateways[].NatGatewayId' \
  --output text | tr '\t' '\n' | while read NGW; do
    if [ -n "$NGW" ]; then
      echo "  Deleting NAT Gateway: $NGW"
      aws ec2 delete-nat-gateway --nat-gateway-id "$NGW" --region $REGION 2>/dev/null
    fi
done

echo "  Waiting 60 seconds for NAT Gateways to delete..."
sleep 60

# 5. Release Elastic IPs
echo ""
echo "Step 5: Releasing Elastic IPs..."
aws ec2 describe-addresses \
  --region $REGION \
  --query "Addresses[?Domain=='vpc'].AllocationId" \
  --output text | tr '\t' '\n' | while read EIP; do
    if [ -n "$EIP" ]; then
      # Check if associated
      ASSOC=$(aws ec2 describe-addresses --allocation-ids "$EIP" --region $REGION --query 'Addresses[0].AssociationId' --output text 2>/dev/null)
      if [ "$ASSOC" = "None" ] || [ -z "$ASSOC" ]; then
        echo "  Releasing EIP: $EIP"
        aws ec2 release-address --allocation-id "$EIP" --region $REGION 2>/dev/null
      fi
    fi
done

# 6. Delete Security Groups (except default)
echo ""
echo "Step 6: Deleting Security Groups..."
aws ec2 describe-security-groups \
  --filters "Name=vpc-id,Values=$VPC_ID" \
  --region $REGION \
  --query 'SecurityGroups[?GroupName!=`default`].GroupId' \
  --output text | tr '\t' '\n' | while read SG; do
    if [ -n "$SG" ]; then
      echo "  Deleting SG: $SG"
      
      # First remove all rules
      aws ec2 describe-security-groups --group-ids "$SG" --region $REGION \
        --query 'SecurityGroups[0].IpPermissions' --output json 2>/dev/null | \
        jq -c '.[]' 2>/dev/null | while read rule; do
          aws ec2 revoke-security-group-ingress \
            --group-id "$SG" \
            --ip-permissions "$rule" \
            --region $REGION 2>/dev/null
        done
      
      aws ec2 describe-security-groups --group-ids "$SG" --region $REGION \
        --query 'SecurityGroups[0].IpPermissionsEgress' --output json 2>/dev/null | \
        jq -c '.[]' 2>/dev/null | while read rule; do
          aws ec2 revoke-security-group-egress \
            --group-id "$SG" \
            --ip-permissions "$rule" \
            --region $REGION 2>/dev/null
        done
      
      # Then delete
      aws ec2 delete-security-group --group-id "$SG" --region $REGION 2>/dev/null || echo "    (still in use)"
    fi
done

sleep 5

# 7. Detach and Delete Internet Gateways
echo ""
echo "Step 7: Deleting Internet Gateways..."
aws ec2 describe-internet-gateways \
  --filters "Name=attachment.vpc-id,Values=$VPC_ID" \
  --region $REGION \
  --query 'InternetGateways[].InternetGatewayId' \
  --output text | tr '\t' '\n' | while read IGW; do
    if [ -n "$IGW" ]; then
      echo "  Detaching IGW: $IGW"
      aws ec2 detach-internet-gateway \
        --internet-gateway-id "$IGW" \
        --vpc-id "$VPC_ID" \
        --region $REGION 2>/dev/null
      
      echo "  Deleting IGW: $IGW"
      aws ec2 delete-internet-gateway \
        --internet-gateway-id "$IGW" \
        --region $REGION 2>/dev/null
    fi
done

# 8. Delete Subnets
echo ""
echo "Step 8: Deleting Subnets..."
aws ec2 describe-subnets \
  --filters "Name=vpc-id,Values=$VPC_ID" \
  --region $REGION \
  --query 'Subnets[].SubnetId' \
  --output text | tr '\t' '\n' | while read SUBNET; do
    if [ -n "$SUBNET" ]; then
      echo "  Deleting Subnet: $SUBNET"
      aws ec2 delete-subnet --subnet-id "$SUBNET" --region $REGION 2>/dev/null
    fi
done

# 9. Delete Route Tables
echo ""
echo "Step 9: Deleting Route Tables..."
aws ec2 describe-route-tables \
  --filters "Name=vpc-id,Values=$VPC_ID" \
  --region $REGION \
  --query 'RouteTables[?Associations[0].Main!=`true`].RouteTableId' \
  --output text | tr '\t' '\n' | while read RT; do
    if [ -n "$RT" ]; then
      echo "  Deleting Route Table: $RT"
      aws ec2 delete-route-table --route-table-id "$RT" --region $REGION 2>/dev/null
    fi
done

echo ""
echo "=========================================="
echo "✅ CLEANUP COMPLETE"
echo "=========================================="
echo ""
echo "Now retry: terraform destroy -auto-approve"
