#!/bin/bash

# Script para promover Read Replica a instancia RDS principal
# Uso: ./promote-read-replica.sh [environment]

set -e

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuración
ENVIRONMENT=${1:-dev}
REPLICA_IDENTIFIER="multiregion-${ENVIRONMENT}-rds-replica"
REGION="us-west-2"

echo -e "${YELLOW}======================================${NC}"
echo -e "${YELLOW}  Promoción de Read Replica a Principal${NC}"
echo -e "${YELLOW}======================================${NC}"
echo ""
echo -e "Environment: ${GREEN}${ENVIRONMENT}${NC}"
echo -e "Replica ID:  ${GREEN}${REPLICA_IDENTIFIER}${NC}"
echo -e "Region:      ${GREEN}${REGION}${NC}"
echo ""

# Confirmación
read -p "$(echo -e ${YELLOW}¿Estás seguro de promover esta Read Replica? Esto romperá la replicación permanentemente. [y/N]: ${NC})" -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${RED}Operación cancelada.${NC}"
    exit 1
fi

echo ""
echo -e "${YELLOW}[1/4] Verificando estado de la Read Replica...${NC}"

# Verificar que existe la réplica
REPLICA_STATUS=$(aws rds describe-db-instances \
    --db-instance-identifier ${REPLICA_IDENTIFIER} \
    --region ${REGION} \
    --query 'DBInstances[0].DBInstanceStatus' \
    --output text 2>/dev/null || echo "NOT_FOUND")

if [ "$REPLICA_STATUS" == "NOT_FOUND" ]; then
    echo -e "${RED}Error: La Read Replica '${REPLICA_IDENTIFIER}' no existe en la región ${REGION}.${NC}"
    exit 1
fi

echo -e "${GREEN}✓${NC} Read Replica encontrada. Estado actual: ${REPLICA_STATUS}"

if [ "$REPLICA_STATUS" != "available" ]; then
    echo -e "${YELLOW}Advertencia: La réplica no está en estado 'available'. Estado actual: ${REPLICA_STATUS}${NC}"
    read -p "$(echo -e ${YELLOW}¿Deseas continuar de todas formas? [y/N]: ${NC})" -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${RED}Operación cancelada.${NC}"
        exit 1
    fi
fi

echo ""
echo -e "${YELLOW}[2/4] Iniciando promoción de Read Replica...${NC}"

# Promover la Read Replica
aws rds promote-read-replica \
    --db-instance-identifier ${REPLICA_IDENTIFIER} \
    --region ${REGION} \
    --backup-retention-period 7 \
    --preferred-backup-window "03:00-04:00"

echo -e "${GREEN}✓${NC} Comando de promoción ejecutado exitosamente."

echo ""
echo -e "${YELLOW}[3/4] Esperando a que la promoción se complete...${NC}"
echo -e "${YELLOW}Esto puede tomar varios minutos. Puedes cancelar con Ctrl+C (la promoción continuará en AWS).${NC}"
echo ""

# Esperar a que la promoción se complete
aws rds wait db-instance-available \
    --db-instance-identifier ${REPLICA_IDENTIFIER} \
    --region ${REGION}

echo -e "${GREEN}✓${NC} Promoción completada. La instancia está disponible."

echo ""
echo -e "${YELLOW}[4/4] Verificando estado final...${NC}"

# Obtener información de la instancia promovida
INSTANCE_INFO=$(aws rds describe-db-instances \
    --db-instance-identifier ${REPLICA_IDENTIFIER} \
    --region ${REGION} \
    --query 'DBInstances[0].[Endpoint.Address,Endpoint.Port,DBInstanceStatus,ReadReplicaSourceDBInstanceIdentifier]' \
    --output text)

ENDPOINT=$(echo $INSTANCE_INFO | awk '{print $1}')
PORT=$(echo $INSTANCE_INFO | awk '{print $2}')
STATUS=$(echo $INSTANCE_INFO | awk '{print $3}')
SOURCE=$(echo $INSTANCE_INFO | awk '{print $4}')

echo ""
echo -e "${GREEN}======================================${NC}"
echo -e "${GREEN}  ✓ PROMOCIÓN EXITOSA${NC}"
echo -e "${GREEN}======================================${NC}"
echo ""
echo -e "Endpoint: ${GREEN}${ENDPOINT}${NC}"
echo -e "Puerto:   ${GREEN}${PORT}${NC}"
echo -e "Estado:   ${GREEN}${STATUS}${NC}"
echo ""

if [ "$SOURCE" == "None" ] || [ -z "$SOURCE" ]; then
    echo -e "${GREEN}✓${NC} La instancia ya NO es una Read Replica (promoción exitosa)"
else
    echo -e "${YELLOW}⚠${NC} Advertencia: La instancia aún muestra fuente de replicación: ${SOURCE}"
fi

echo ""
echo -e "${YELLOW}PRÓXIMOS PASOS:${NC}"
echo -e "1. Actualiza las variables de entorno de tu Lambda en ${REGION} para usar este endpoint"
echo -e "2. Verifica que las aplicaciones puedan escribir en la nueva instancia principal"
echo -e "3. Considera crear una nueva Read Replica si necesitas recuperación ante desastres"
echo -e "4. Si la instancia RDS original en us-east-1 se recupera, evalúa tu estrategia de failback"
echo ""
echo -e "${GREEN}Script completado exitosamente.${NC}"
