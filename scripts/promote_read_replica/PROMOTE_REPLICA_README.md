# Script de Promoción de Read Replica

Este script automatiza el proceso de promover una Read Replica de RDS a una instancia principal independiente.

## Uso

```bash
./promote-read-replica.sh [environment]
```

**Ejemplo:**
```bash
./promote-read-replica.sh dev
```

Si no especificas el environment, por defecto usará `dev`.

## ¿Qué hace el script?

1. **Verifica** que la Read Replica exista y esté disponible
2. **Solicita confirmación** antes de proceder (operación irreversible)
3. **Promueve** la Read Replica a instancia principal con:
   - Retención de backups: 7 días
   - Ventana de backup: 03:00-04:00 UTC
4. **Espera** a que la promoción se complete
5. **Verifica** el estado final y muestra la información del nuevo endpoint

## Cuándo usar este script

- **Failover manual:** Cuando la instancia RDS principal en `us-east-1` falla
- **Mantenimiento:** Cuando necesitas promover la réplica para operaciones específicas
- **Testing:** Para probar escenarios de recuperación ante desastres

## Importante

⚠️ **Esta operación es IRREVERSIBLE:**
- Rompe permanentemente la relación de replicación
- La Read Replica se convierte en instancia independiente de lectura/escritura
- No se puede revertir automáticamente

## Después de la promoción

1. **Actualizar Lambda:** Modifica las variables de entorno en tu Lambda de `us-west-2`:
   ```bash
   DB_HOST=<nuevo-endpoint>
   ```

2. **Verificar conectividad:** Prueba que tu aplicación puede escribir en la nueva instancia

3. **Considerar nueva réplica:** Crea una nueva Read Replica para mantener DR capabilities

4. **Estrategia de failback:** Si la instancia original se recupera, decide tu estrategia:
   - Reconfigurar replicación inversa
   - Mantener la nueva configuración
   - Recrear desde cero

## Requisitos

- AWS CLI instalado y configurado
- Permisos IAM para:
  - `rds:DescribeDBInstances`
  - `rds:PromoteReadReplica`
- Acceso a la región `us-west-2`

## Ejemplo de salida

```
======================================
  Promoción de Read Replica a Principal
======================================

Environment: dev
Replica ID:  multiregion-dev-rds-replica
Region:      us-west-2

¿Estás seguro de promover esta Read Replica? [y/N]: y

[1/4] Verificando estado de la Read Replica...
✓ Read Replica encontrada. Estado actual: available

[2/4] Iniciando promoción de Read Replica...
✓ Comando de promoción ejecutado exitosamente.

[3/4] Esperando a que la promoción se complete...
✓ Promoción completada. La instancia está disponible.

[4/4] Verificando estado final...

======================================
  ✓ PROMOCIÓN EXITOSA
======================================

Endpoint: multiregion-dev-rds-replica.xxx.us-west-2.rds.amazonaws.com
Puerto:   5432
Estado:   available

✓ La instancia ya NO es una Read Replica (promoción exitosa)

PRÓXIMOS PASOS:
1. Actualiza las variables de entorno de tu Lambda en us-west-2
2. Verifica que las aplicaciones puedan escribir en la nueva instancia
3. Considera crear una nueva Read Replica si necesitas DR
4. Si la RDS original se recupera, evalúa tu estrategia de failback

Script completado exitosamente.
```

## Notas adicionales

- El script espera a que la promoción se complete. Puedes cancelar con `Ctrl+C` sin detener la promoción en AWS
- La promoción típicamente toma 5-10 minutos
- Durante la promoción, la réplica puede estar temporalmente indisponible
