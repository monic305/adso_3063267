# Script de despliegue para entorno SGT (PowerShell)
# Uso: .\deploy.ps1 [staging|production]

param(
    [Parameter(Mandatory=$false)]
    [ValidateSet("staging", "production")]
    [string]$Environment = "staging"
)

Write-Host "Iniciando despliegue para entorno: $Environment" -ForegroundColor Green

# Configurar variables según entorno
if ($Environment -eq "staging") {
    $ComposeFile = "docker-compose.stg.yml"
    $EnvFile = ".stg.env"
    $DbName = "auth_stg_db"
} else {
    $ComposeFile = "docker-compose.yml"
    $EnvFile = ".prod.env"
    $DbName = "auth_prod_db"
}

Write-Host "Configuracion:" -ForegroundColor Cyan
Write-Host "   - Archivo compose: $ComposeFile"
Write-Host "   - Archivo entorno: $EnvFile"
Write-Host "   - Base de datos: $DbName"

# Verificar archivos necesarios
if (-not (Test-Path $ComposeFile)) {
    Write-Host "Error: No se encuentra el archivo $ComposeFile" -ForegroundColor Red
    exit 1
}

if (-not (Test-Path $EnvFile)) {
    Write-Host "Error: No se encuentra el archivo $EnvFile" -ForegroundColor Red
    exit 1
}

try {
    # Detener servicios existentes
    Write-Host "Deteniendo servicios existentes..." -ForegroundColor Yellow
    docker-compose -f $ComposeFile down --remove-orphans 2>$null

    # Limpiar imágenes antiguas
    Write-Host "Limpiando imagenes antiguas..." -ForegroundColor Yellow
    docker image prune -f 2>$null

    # Construir y levantar servicios
    Write-Host "Construyendo imagen de la aplicacion..." -ForegroundColor Blue
    docker-compose -f $ComposeFile build --no-cache

    Write-Host "Levantando servicios..." -ForegroundColor Blue
    docker-compose -f $ComposeFile up -d

    # Esperar a que la base de datos esté lista
    Write-Host "Esperando a que la base de datos este lista..." -ForegroundColor Yellow
    Start-Sleep -Seconds 10

    # Verificar estado de los servicios
    Write-Host "Verificando estado de los servicios..." -ForegroundColor Cyan
    docker-compose -f $ComposeFile ps

    # Verificar salud de la aplicación
    Write-Host "Verificando salud de la aplicacion..." -ForegroundColor Yellow
    $healthy = $false
    for ($i = 1; $i -le 10; $i++) {
        try {
            $response = Invoke-WebRequest -Uri "http://localhost:3000/health" -TimeoutSec 5 -ErrorAction Stop
            if ($response.StatusCode -eq 200) {
                Write-Host "Aplicacion saludable" -ForegroundColor Green
                $healthy = $true
                break
            }
        } catch {
            Write-Host "Esperando a la aplicacion... ($i/10)" -ForegroundColor Yellow
            Start-Sleep -Seconds 5
        }
    }

    if (-not $healthy) {
        Write-Host "La aplicacion no esta saludable despues de 10 intentos" -ForegroundColor Yellow
    }

    # Mostrar logs recientes
    Write-Host "Logs recientes:" -ForegroundColor Cyan
    docker-compose -f $ComposeFile logs --tail=50 app

    Write-Host "Despliegue completado para entorno $Environment" -ForegroundColor Green
    Write-Host "Aplicacion disponible en: http://localhost:3000" -ForegroundColor Cyan
    Write-Host "PgAdmin disponible en: http://localhost:5050" -ForegroundColor Cyan

} catch {
    Write-Host "Error durante el despliegue: $_" -ForegroundColor Red
    exit 1
}
