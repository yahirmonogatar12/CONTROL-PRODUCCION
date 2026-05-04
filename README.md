# Sistema de Control de Produccion

> **Versión:** 1.0.0
> **Última actualización:** Enero 2026
> **Desarrollado para:** LGEMN

[![Flutter](https://img.shields.io/badge/Flutter-3.0+-02569B?logo=flutter)](https://flutter.dev)
[![Node.js](https://img.shields.io/badge/Node.js-18+-339933?logo=node.js)](https://nodejs.org)
[![MySQL](https://img.shields.io/badge/MySQL-8.0+-4479A1?logo=mysql)](https://www.mysql.com)

## Descripción

**Sistema de Control de Produccion** es una aplicación empresarial multi-plataforma diseñada para la gestión completa de materiales de almacén en entornos de manufactura electrónica. Desarrollado con Flutter para máxima portabilidad (Windows Desktop, Android, iOS) y backend robusto en Node.js/Express con MySQL.

### Características Principales

- **📦 Recepción de Material** - Ingreso automático con generación de etiquetas ZPL y códigos únicos
- **📤 Salida de Material** - Validación FIFO, consumo BOM y tracking de distribución
- **🔍 Inspección IQC** - Sistema de calidad con muestreo AQL y especificaciones configurables
- **📊 Control de Inventario** - Tracking en tiempo real de lotes, ubicaciones y disponibilidad
- **↩️ Devoluciones** - Gestión de material devuelto a proveedores
- **🔎 Auditoría Física** - Sistema de auditoría con sincronización real-time vía WebSocket
- **📱 App Móvil** - Aplicación Android/iOS con escaneo por cámara y Bluetooth
- **🖨️ Impresión de Etiquetas** - Soporte ZPL para impresoras Zebra (desktop y móvil)
- **🌐 Multi-idioma** - Interfaz en Inglés, Español y Coreano (한국어)
- **👥 Sistema de Permisos** - Control de acceso basado en departamentos y roles

### Plataformas Soportadas

| Plataforma | Estado | Notas |
|------------|--------|-------|
| Windows Desktop | ✅ Producción | Aplicación principal de escritorio |
| Android | ✅ Producción | App móvil con scanner de cámara |
| iOS | 🔧 Desarrollo | Pendiente de testing final |

---

## 📋 Tabla de Contenidos

- [Arquitectura del Sistema](#-arquitectura-del-sistema)
- [Tecnologías Utilizadas](#-tecnologías-utilizadas)
- [Módulos Principales](#-módulos-principales)
- [Estructura del Proyecto](#-estructura-del-proyecto)
- [Instalación](#-instalación)
- [Configuración](#-configuración)
- [Base de Datos](#-base-de-datos)
- [API Endpoints](#-api-endpoints)
- [Compilación](#-compilación)
- [Documentación](#-documentación)
- [Roadmap](#-roadmap)

---

## 🏗️ Arquitectura del Sistema

### Arquitectura General

```
┌─────────────────────────────────────────────────────────────┐
│                    CLIENTES (Multi-plataforma)              │
├─────────────────────────────────────────────────────────────┤
│  Windows Desktop      │   Android Mobile   │   iOS Mobile   │
│  (Flutter Windows)    │   (Flutter)        │   (Flutter)    │
│  - Gestión completa   │   - Escaneo        │   - Escaneo    │
│  - Impresión ZPL      │   - Auditoría      │   - Auditoría  │
│  - Reportes Excel     │   - Bluetooth      │   - Bluetooth  │
└──────────┬────────────┴─────────┬──────────┴────────┬───────┘
           │                      │                   │
           │ HTTP/REST            │ HTTP/REST         │
           │ WebSocket            │ UDP Discovery     │
           │                      │                   │
           └──────────────────────┼───────────────────┘
                                  │
           ┌──────────────────────▼───────────────────┐
           │         BACKEND - Node.js/Express        │
           ├──────────────────────────────────────────┤
           │  - API REST (16 módulos)                 │
           │  - WebSocket Server (auditoría)          │
           │  - UDP Discovery Server                  │
           │  - Rate Limiting                         │
           │  - Error Handling                        │
           └─────────────────┬────────────────────────┘
                             │
                             │ MySQL Driver
                             │ Pool: 50 conexiones
                             │
           ┌─────────────────▼────────────────────────┐
           │         BASE DE DATOS - MySQL 8.0+       │
           ├──────────────────────────────────────────┤
           │  - 25+ tablas                            │
           │  - Stored Procedures                     │
           │  - Migraciones automáticas               │
           │  - Timezone: UTC-6 (México)              │
           └──────────────────────────────────────────┘
```

### Flujo de Datos Principal

1. **Frontend (Flutter)** → Llamadas REST API → **Backend (Express)**
2. **Backend** → Consultas MySQL → **Base de Datos**
3. **Base de Datos** → Resultados → **Backend** → JSON → **Frontend**
4. **WebSocket** → Sincronización en tiempo real para auditoría multi-usuario

### Patrones de Diseño

- **MVC (Model-View-Controller)** - Backend modularizado con controladores especializados
- **Service Layer Pattern** - ApiService centraliza todas las llamadas HTTP
- **Repository Pattern** - Controllers actúan como repositorios de datos
- **ChangeNotifier Pattern** - Gestión de estado simple en Flutter
- **Dependency Injection** - Configuración de servidor dinámica

---

## 🛠️ Tecnologías Utilizadas

### Frontend (Flutter)

| Tecnología | Versión | Propósito |
|------------|---------|-----------|
| Flutter SDK | ≥3.0.0 | Framework multi-plataforma |
| Dart | ≥3.0.0 | Lenguaje de programación |
| http | 1.6.0 | Comunicación REST API |
| window_manager | 0.4.3 | Control de ventanas desktop |
| printing | 5.14.2 | Impresión ZPL (Zebra) |
| excel | 4.0.6 | Generación de archivos Excel |
| mobile_scanner | 5.2.3 | Escaneo de códigos (móvil) |
| flutter_blue_plus | 1.32.0 | Bluetooth para impresoras |
| web_socket_channel | 3.0.2 | WebSocket real-time |
| shared_preferences | 2.5.3 | Almacenamiento local |
| qr_flutter | 4.1.0 | Generación de códigos QR |

### Backend (Node.js)

| Tecnología | Versión | Propósito |
|------------|---------|-----------|
| Node.js | ≥18.0.0 | Runtime JavaScript |
| Express.js | 4.18.2 | Framework web |
| mysql2 | 3.6.5 | Driver MySQL con promesas |
| cors | 2.8.5 | Cross-Origin Resource Sharing |
| dotenv | 16.3.1 | Variables de entorno |
| ws | 8.18.3 | Servidor WebSocket |
| pkg | 5.8.1 | Empaquetador Node.js a .exe |

### Base de Datos

- **MySQL** 8.0+
- **Base de datos:** `meslocal`
- **Pool de conexiones:** 50 conexiones simultáneas
- **Timezone:** Local (UTC-6 México)

---

## 📦 Módulos Principales

### 1. Control Produccion (Entradas de Material)
**Archivos:** [material_warehousing/](lib/screens/material_warehousing/)

Módulo de recepción de materiales con las siguientes capacidades:
- Ingreso de material con generación automática de código único
- Etiquetado ZPL: `[PREFIX]-[DATE]-[SEQUENCE]` (ej: `EAE66213501-20250107-0001`)
- Validación contra catálogo de materiales
- Asignación automática de ubicación en almacén
- Marcado de requerimiento IQC según configuración del material
- Edición individual y masiva de lotes
- Búsqueda y filtros por fecha, texto, estado IQC
- **Importación masiva CSV** via script [bulk_import_warehousing.js](backend/bulk_import_warehousing.js)

**Flujo:** Recibir → Validar → Etiquetar → Ubicar → Inspeccionar (IQC si aplica)

### 2. Material Outgoing (Salidas de Material)
**Archivos:** [material_outgoing/](lib/screens/material_outgoing/)

Gestión de salidas de material a producción:
- Validación FIFO (First In, First Out) opcional
- Consumo contra Bill of Materials (BOM)
- División automática de lotes para salidas parciales
- Validación de disponibilidad de cantidad
- Selección de departamento y proceso destino
- Tracking completo de consumo por modelo/plan

**Flujo:** Seleccionar Material → Validar Disponibilidad → Confirmar Salida → Actualizar Inventario

### 3. IQC Inspection (Inspección de Calidad)
**Archivos:** [iqc_inspection/](lib/screens/iqc_inspection/)

Sistema de inspección de calidad con muestreo AQL:
- **Niveles AQL:** 0.65, 1.0, 2.5, 4.0
- **Niveles de muestreo:** S-1, S-2, S-3, S-4, I, II, III
- **Pruebas configurables:**
  - **RoHS:** Prueba de conformidad (OK/NG)
  - **Brightness:** Medición de brillo (luminosidad) con tolerancias
  - **Dimension:** Mediciones de largo/ancho vs especificación
  - **Color:** Especificación de color
  - **Appearance:** Inspección visual
- **Disposiciones:** Release, Return, Scrap, Hold, Rework
- Registro de mediciones individuales por muestra
- Evaluación automática contra criterios AQL

**Flujo:** Lote Recibido → Muestreo AQL → Medición → Evaluación → Disposición

### 4. Inventory Audit (Auditoría Física)
**Archivos:** [inventory_audit/](lib/screens/inventory_audit/), [mobile/mobile_audit_screen.dart](lib/screens/mobile/mobile_audit_screen.dart)

Sistema de auditoría física con sincronización real-time:
- Creación de sesiones de auditoría por supervisor
- Escaneo simultáneo multi-usuario (móvil + desktop)
- Sincronización WebSocket en tiempo real
- Detección automática de discrepancias:
  - ✓ Items encontrados (coinciden)
  - ✗ Items faltantes (esperados pero no escaneados)
  - ⚠️ Items extras (escaneados pero no esperados)
- Aprobación de discrepancias por supervisor
- Generación automática de salidas para faltantes

**Flujo:** Iniciar Auditoría → Escanear Ubicaciones → Detectar Discrepancias → Aprobar → Generar Salidas

### 5. Material Control (Catálogo de Materiales)
**Archivos:** [material_control/](lib/screens/material_control/)

Gestión del catálogo maestro de materiales:
- CRUD completo de materiales
- Número de parte único
- Especificaciones técnicas
- Unidad de empaque (EA, Roll, Tray, etc.)
- Ubicación default en almacén
- Configuración de requerimientos IQC por prueba
- Gestión de proveedores y clientes

### 6. Quarantine (Cuarentena)
**Archivos:** [quarantine/](lib/screens/quarantine/)

Apartamiento de material con defectos:
- Registro de lotes en cuarentena
- Motivos de apartamiento
- Disposición: Release, Scrap, Return, Rework
- Seguimiento histórico de rechazos
- Análisis de tendencias de calidad

### 7. Material Return (Devoluciones)
**Archivos:** [material_return/](lib/screens/material_return/)

Devolución de material a proveedor:
- Registro de motivo de devolución
- Validación de trazabilidad
- Actualización de estado de inventario
- Auditoría completa de devoluciones

### 8. Blacklist (Lista Negra de Lotes)
**Archivos:** [blacklist/](lib/screens/blacklist/)

Marcado de lotes problemáticos para prevenir reuso:
- Bloqueo automático de lotes
- Razones de inclusión documentadas
- Historial de problemas por lote
- Prevención de uso futuro

### 9. User Management (Gestión de Usuarios)
**Archivos:** [user_management/](lib/screens/user_management/)

Administración completa de usuarios:
- CRUD de usuarios del sistema
- Asignación de departamentos
- Asignación de cargos/posiciones
- Control de permisos basado en rol
- Activación/desactivación de cuentas

### 10. Mobile Screens (Pantallas Móviles)
**Archivos:** [mobile/](lib/screens/mobile/)

6 pantallas especializadas para operación móvil:
- **Mobile Entry:** Recepción de material con cámara (83KB)
- **Mobile Outgoing:** Salidas con escaneo (32KB)
- **Mobile Inventory:** Consulta de disponibilidad (30KB)
- **Mobile Audit:** Auditoría física con escaneo (50KB)
- **Mobile Label Assignment:** Asignación de etiquetas (66KB)
- **Mobile Reentry:** Reubicación de material (23KB)

**Características móviles:**
- Auto-descubrimiento UDP de servidor
- Impresión Bluetooth directa
- Impresión remota vía servidor desktop
- Retroalimentación háptica y sonora
- Sincronización real-time

---

## 📁 Estructura del Proyecto

```
Control_produccion/
├── lib/                                # Código fuente Flutter
│   ├── main.dart                       # Punto de entrada
│   ├── app.dart                        # Root widget, navegación
│   ├── core/                           # Código compartido
│   │   ├── config/
│   │   │   ├── server_config.dart      # Perfiles multi-servidor
│   │   │   └── print_server_config.dart
│   │   ├── localization/
│   │   │   └── app_translations.dart   # Traducciones (EN/ES/KO)
│   │   ├── services/                   # 11 servicios especializados
│   │   │   ├── api_service.dart        # Llamadas REST (~115KB)
│   │   │   ├── auth_service.dart       # Autenticación y permisos
│   │   │   ├── backend_service.dart    # Gestión proceso backend
│   │   │   ├── printer_service.dart    # Impresión ZPL desktop
│   │   │   ├── mobile_printer_service.dart
│   │   │   ├── excel_export_service.dart
│   │   │   ├── feedback_service.dart
│   │   │   ├── server_discovery_service.dart
│   │   │   ├── audit_websocket_service.dart
│   │   │   ├── scanner_config_service.dart
│   │   │   └── update_service.dart
│   │   ├── theme/
│   │   │   └── app_colors.dart         # Paleta de colores
│   │   ├── utils/
│   │   │   └── platform_utils.dart
│   │   └── widgets/                    # 14 componentes reutilizables
│   │       ├── simple_grid.dart
│   │       ├── table_dropdown_field.dart
│   │       ├── labeled_field.dart
│   │       ├── printer_settings_dialog.dart
│   │       └── ...
│   └── screens/                        # 17 módulos funcionales
│       ├── launcher/                   # Inicio/conexión backend
│       ├── login/                      # Autenticación
│       ├── material_warehousing/       # Entradas (7 archivos)
│       ├── material_outgoing/          # Salidas (5 archivos)
│       ├── material_return/            # Devoluciones (3 archivos)
│       ├── material_control/           # Catálogo (4 archivos)
│       ├── iqc_inspection/             # IQC (5 archivos)
│       ├── quality_specs/              # Especificaciones (3 archivos)
│       ├── quarantine/                 # Cuarentena (3 archivos)
│       ├── long_term_inventory/        # Inventario (3 archivos)
│       ├── inventory_audit/            # Auditoría (3 archivos)
│       ├── blacklist/                  # Lista negra (3 archivos)
│       ├── user_management/            # Usuarios (3 archivos)
│       ├── reentry/                    # Reingreso (2 archivos)
│       ├── mobile/                     # Móvil (7 archivos)
│       └── main_tabbed_screen.dart     # Navegación principal (29KB)
│
├── backend/                            # API REST Node.js
│   ├── server.js                       # Punto de entrada (275 líneas)
│   ├── package.json                    # Dependencias NPM
│   ├── .env                            # Credenciales BD (no en git)
│   ├── config/
│   │   ├── database.js                 # Pool MySQL
│   │   └── permissions.js              # Constantes de permisos
│   ├── controllers/                    # 14 controladores
│   │   ├── auth.controller.js
│   │   ├── warehousing.controller.js   # Entradas (20KB)
│   │   ├── outgoing.controller.js      # Salidas (21KB)
│   │   ├── return.controller.js        # Devoluciones
│   │   ├── plan.controller.js          # Plan producción + BOM
│   │   ├── materials.controller.js     # Catálogo (19KB)
│   │   ├── iqc.controller.js           # IQC (20KB)
│   │   ├── quality-specs.controller.js
│   │   ├── quarantine.controller.js
│   │   ├── inventory.controller.js
│   │   ├── customers.controller.js
│   │   ├── cancellation.controller.js
│   │   ├── audit.controller.js         # Auditoría (37KB)
│   │   └── blacklist.controller.js
│   ├── routes/                         # 16 archivos de rutas
│   │   ├── index.js                    # Agregador (2.4KB)
│   │   ├── warehousing.routes.js
│   │   ├── outgoing.routes.js
│   │   ├── return.routes.js
│   │   ├── plan.routes.js
│   │   ├── auth.routes.js
│   │   ├── materials.routes.js
│   │   ├── iqc.routes.js
│   │   ├── quality-specs.routes.js
│   │   ├── quarantine.routes.js
│   │   ├── inventory.routes.js
│   │   ├── customers.routes.js
│   │   ├── cancellation.routes.js
│   │   ├── print.routes.js             # Impresión remota (16KB)
│   │   ├── audit.routes.js
│   │   └── blacklist.routes.js
│   ├── middleware/
│   │   ├── errorHandler.js             # Manejo centralizado errores
│   │   └── rateLimiter.js              # Rate limiting
│   ├── utils/
│   │   ├── dbMigrations.js             # Migraciones BD (16KB)
│   │   ├── udpDiscovery.js             # UDP descubrimiento
│   │   ├── sequenceService.js          # Generador secuencias (10KB)
│   │   └── partNumberHelper.js
│   ├── database/
│   │   └── schema.sql                  # Schema de referencia
│   └── bulk_import_warehousing.js      # Script importación CSV (414 líneas)
│
├── Documentacion/                      # Documentación técnica
│   ├── structure.md                    # Estructura del proyecto
│   ├── backend.md                      # Convenciones backend
│   ├── tech.md                         # Stack tecnológico
│   ├── product.md                      # Descripción del producto
│   ├── permissions.md                  # Sistema de permisos
│   ├── conventions.md                  # Convenciones de código
│   ├── new-module-guide.md             # Guía nuevos módulos
│   ├── data-mapping.md                 # Mapeo BD ↔ Flutter
│   ├── database-schema.md              # Schema completo BD (25+ tablas)
│   ├── GUIA_TABLAS_GRID.md             # Implementación de grids
│   ├── MOBILE_APP_ROADMAP.md           # Roadmap app móvil
│   ├── inventory-audit.md              # Flujo auditoría detallado
│   └── TROUBLESHOOTING.md              # Solución de problemas
│
├── installer/                          # Configuración Inno Setup
├── assets/                             # Logo y recursos
├── windows/                            # Configuración Windows
├── android/                            # Configuración Android
├── ios/                                # Configuración iOS
├── pubspec.yaml                        # Dependencias Flutter
├── build.ps1                           # Script de compilación PowerShell
├── BUILD_README.md                     # Sistema de compilación
├── CHANGELOG.md                        # Historial de versiones
└── VERSION.txt                         # Versión actual
```

---

## 🚀 Instalación

### Requisitos de Desarrollo

#### Obligatorios:
- **Flutter SDK** ≥3.0.0 ([Descargar](https://flutter.dev/docs/get-started/install))
- **Node.js** ≥18.0.0 ([Descargar](https://nodejs.org))
- **MySQL** 8.0+ ([Descargar](https://dev.mysql.com/downloads/mysql/))
- **Git** ([Descargar](https://git-scm.com/downloads))

#### Para Windows Desktop:
- **Visual Studio 2022** con C++ Desktop Development
- **Windows 10/11** (64-bit)

#### Para Android:
- **Android Studio** con Android SDK
- **Java JDK** 11+

#### Para iOS:
- **Xcode** 14+ (solo en macOS)
- **CocoaPods**

### Pasos de Instalación

#### 1. Clonar el Repositorio
```bash
git clone <repository-url>
cd Control_produccion
```

#### 2. Instalar Dependencias Flutter
```bash
flutter pub get
```

#### 3. Instalar Dependencias Backend
```bash
cd backend
npm install
cd ..
```

#### 4. Configurar Base de Datos

Crear base de datos en MySQL:
```sql
CREATE DATABASE meslocal CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
```

Ejecutar migraciones (se ejecutan automáticamente al iniciar el backend):
```bash
cd backend
node server.js
```

#### 5. Configurar Variables de Entorno

Crear archivo `backend/.env`:
```env
# Database Configuration
DB_HOST=localhost
DB_PORT=3306
DB_USER=root
DB_PASSWORD=tu_password
DB_NAME=meslocal
DB_POOL_SIZE=50

# Server Configuration
PORT=3000
NODE_ENV=development
```

---

## ⚙️ Configuración

### Configuración del Servidor (Flutter)

El sistema soporta múltiples perfiles de servidor. Editar [lib/core/config/server_config.dart](lib/core/config/server_config.dart):

```dart
class ServerConfig {
  static final Map<String, ServerProfile> profiles = {
    'localhost': ServerProfile(
      name: 'Local Development',
      baseUrl: 'http://localhost:3000',
      isDefault: true,
    ),
    'production': ServerProfile(
      name: 'Production Server',
      baseUrl: 'http://192.168.1.100:3000',
      isDefault: false,
    ),
  };
}
```

### Sistema de Permisos

6 niveles de permiso basados en departamento:

| Nivel | Descripción | Departamentos |
|-------|-------------|---------------|
| **Full Access** | Acceso completo al sistema | Sistemas, Gerencia, Administración |
| **Warehousing Write** | Crear/editar entradas de material | Almacén, Almacén Supervisor |
| **Outgoing Write** | Crear/editar salidas de material | Almacén, Almacén Supervisor |
| **IQC Write** | Realizar inspecciones IQC | Calidad, Calidad Supervisor |
| **Audit Manage** | Crear sesiones de auditoría | Almacén Supervisor |
| **Audit Scan** | Escanear en auditorías | Almacén, Almacén Supervisor |
| **Audit Approve Discrepancy** | Aprobar discrepancias | Almacén Supervisor |

Ver [Documentacion/permissions.md](Documentacion/permissions.md) para detalles completos.

### Impresión ZPL

#### Desktop (Windows):
- Configurar impresora Zebra en Windows
- Seleccionar en **Settings → Printer Settings**
- Soporte para impresoras USB y de red

#### Móvil (Android/iOS):
- **Bluetooth:** Emparejar impresora en configuración del dispositivo
- **Remota:** Enviar trabajos de impresión a servidor desktop
- Configurar en **Settings → Mobile Printer Settings**

---

## 🗄️ Base de Datos

### Schema Principal

**Base de datos:** `meslocal`
**Total de tablas:** 25+
**Timezone:** UTC-6 (México)

#### Tablas Principales:

| Tabla | Descripción | Registros Aprox. |
|-------|-------------|------------------|
| `control_material_almacen_prod` | Entradas de material | 10,000+ |
| `control_material_salida_prod` | Salidas de material | 5,000+ |
| `materiales` | Catálogo de materiales | 500+ |
| `iqc_inspection_lot` | Lotes inspeccionados IQC | 2,000+ |
| `iqc_inspection_detail` | Mediciones individuales | 20,000+ |
| `quarantine_prod` | Material en cuarentena | 100+ |
| `inventory_audit` | Sesiones de auditoría | 50+ |
| `inventory_audit_item` | Items auditados | 5,000+ |
| `material_returns` | Devoluciones a proveedor | 200+ |
| `blacklist` | Lotes problemáticos | 50+ |
| `usuarios` | Usuarios del sistema | 100+ |
| `plan_main` | Plan de producción | 1,000+ |
| `bom` | Bill of Materials | 5,000+ |

Ver [Documentacion/database-schema.md](Documentacion/database-schema.md) para schema completo con todas las columnas.

### Migraciones

Las migraciones se ejecutan automáticamente al iniciar el backend:
- Ubicación: [backend/utils/dbMigrations.js](backend/utils/dbMigrations.js)
- Estrategia: Crear tablas si no existen, no destructivo
- Versionado: Tabla `schema_version` para control de migraciones

---

## 🔌 API Endpoints

### Autenticación

| Método | Endpoint | Descripción |
|--------|----------|-------------|
| POST | `/api/auth/login` | Iniciar sesión |
| POST | `/api/auth/logout` | Cerrar sesión |
| GET | `/api/auth/validate-session` | Validar sesión activa |

### Warehousing (Entradas)

| Método | Endpoint | Descripción |
|--------|----------|-------------|
| GET | `/api/warehousing` | Listar entradas con filtros |
| POST | `/api/warehousing` | Crear nueva entrada |
| PUT | `/api/warehousing/:id` | Actualizar entrada |
| DELETE | `/api/warehousing/:id` | Eliminar entrada |
| POST | `/api/warehousing/bulk-import` | Importación masiva CSV |

### Outgoing (Salidas)

| Método | Endpoint | Descripción |
|--------|----------|-------------|
| GET | `/api/outgoing` | Listar salidas |
| POST | `/api/outgoing` | Crear salida |
| GET | `/api/outgoing/available/:codigo` | Verificar disponibilidad |

### IQC Inspection

| Método | Endpoint | Descripción |
|--------|----------|-------------|
| GET | `/api/iqc/lots` | Listar lotes para inspección |
| POST | `/api/iqc/lot` | Crear lote IQC |
| GET | `/api/iqc/lot/:id` | Obtener detalles de lote |
| POST | `/api/iqc/measurement` | Registrar medición |
| PUT | `/api/iqc/lot/:id/disposition` | Actualizar disposición |

### Inventory Audit

| Método | Endpoint | Descripción |
|--------|----------|-------------|
| GET | `/api/audit/sessions` | Listar sesiones de auditoría |
| POST | `/api/audit/session` | Crear sesión |
| POST | `/api/audit/scan` | Registrar escaneo |
| GET | `/api/audit/session/:id/discrepancies` | Obtener discrepancias |
| POST | `/api/audit/approve-discrepancy` | Aprobar discrepancia |

### Materials (Catálogo)

| Método | Endpoint | Descripción |
|--------|----------|-------------|
| GET | `/api/materials` | Listar materiales |
| POST | `/api/materials` | Crear material |
| PUT | `/api/materials/:id` | Actualizar material |
| DELETE | `/api/materials/:id` | Eliminar material |
| GET | `/api/materials/:id/iqc-config` | Obtener config IQC |

Ver documentación completa de API en [Documentacion/backend.md](Documentacion/backend.md).

---

## 🏗️ Compilación

### Desarrollo

#### Flutter Desktop (Windows)
```bash
flutter run -d windows
```

#### Flutter Android
```bash
flutter run -d <device-id>
```

#### Backend (Node.js)
```bash
cd backend
npm run dev  # Con nodemon (hot-reload)
# o
npm start    # Sin hot-reload
```

### Producción

#### Build Completo (Usando PowerShell)
```powershell
.\build.ps1
```

Este script realiza:
1. Compilación Flutter Windows release
2. Empaquetado backend Node.js a .exe
3. Generación de instalador Inno Setup
4. Output: `installer/EscaneoInput_Setup_v{VERSION}.exe`

#### Build Manual

**Flutter Windows:**
```bash
flutter build windows --release
```

**Backend standalone:**
```bash
cd backend
npm run build
# Genera: backend/dist/backend-server.exe
```

**Android APK:**
```bash
flutter build apk --release
```

**Android App Bundle:**
```bash
flutter build appbundle --release
```

Ver [BUILD_README.md](BUILD_README.md) para detalles completos del sistema de compilación.

---

## 📚 Documentación

### Guías Disponibles

| Documento | Propósito | Audiencia |
|-----------|-----------|-----------|
| [structure.md](Documentacion/structure.md) | Estructura completa del proyecto | Desarrolladores |
| [tech.md](Documentacion/tech.md) | Stack tecnológico detallado | Arquitectos |
| [backend.md](Documentacion/backend.md) | Convenciones backend y API | Backend devs |
| [database-schema.md](Documentacion/database-schema.md) | Schema BD completo (25+ tablas) | DBAs |
| [data-mapping.md](Documentacion/data-mapping.md) | Mapeo datos BD ↔ Flutter | Full-stack devs |
| [permissions.md](Documentacion/permissions.md) | Sistema de permisos | Admins/Devs |
| [conventions.md](Documentacion/conventions.md) | Convenciones de código | Todos |
| [new-module-guide.md](Documentacion/new-module-guide.md) | Crear nuevos módulos | Desarrolladores |
| [GUIA_TABLAS_GRID.md](Documentacion/GUIA_TABLAS_GRID.md) | Implementación de grids | Frontend devs |
| [MOBILE_APP_ROADMAP.md](Documentacion/MOBILE_APP_ROADMAP.md) | Roadmap app móvil | Product owners |
| [inventory-audit.md](Documentacion/inventory-audit.md) | Flujo auditoría detallado | Todos |
| [TROUBLESHOOTING.md](Documentacion/TROUBLESHOOTING.md) | Solución de problemas | Soporte/Admins |
| [product.md](Documentacion/product.md) | Descripción del producto | Stakeholders |

### Convenciones de Código

- **Dart/Flutter:** Estilo oficial de Dart ([dart.dev/guides/language/effective-dart](https://dart.dev/guides/language/effective-dart))
- **JavaScript/Node.js:** ESLint con configuración estándar
- **SQL:** Nombres de tablas en minúsculas con guiones bajos (`snake_case`)
- **Commits:** Mensajes descriptivos en español/inglés

### Contribución

1. Crear branch desde `main`: `git checkout -b feature/nueva-funcionalidad`
2. Seguir convenciones de código en [Documentacion/conventions.md](Documentacion/conventions.md)
3. Actualizar documentación si es necesario
4. Crear Pull Request con descripción detallada
5. Revisar con al menos 1 aprobación

---

## 🗺️ Roadmap

### Versión Actual: 1.0.0

### Próximas Versiones:

#### v1.1.0 - Mejoras de Performance (Q1 2026)
- [ ] Optimización de consultas MySQL
- [ ] Caché de datos frecuentes
- [ ] Paginación en todas las grids
- [ ] Lazy loading de imágenes

#### v1.2.0 - Nuevas Funcionalidades (Q2 2026)
- [ ] Dashboard analítico con gráficas
- [ ] Reportes personalizables
- [ ] Exportación PDF
- [ ] Sistema de notificaciones push

#### v1.3.0 - Expansión Móvil (Q3 2026)
- [ ] App iOS completamente funcional
- [ ] Modo offline con sincronización
- [ ] Soporte para tablets
- [ ] Widget de acceso rápido

#### v2.0.0 - Integración Empresarial (Q4 2026)
- [ ] Integración con ERP
- [ ] API pública con autenticación OAuth2
- [ ] Webhooks para eventos
- [ ] Multi-tenancy (multi-empresa)

Ver [CHANGELOG.md](CHANGELOG.md) para historial completo de versiones.

---

## 🔧 Solución de Problemas

### Problemas Comunes

#### Backend no inicia
```bash
# Verificar puerto 3000 disponible
netstat -ano | findstr :3000

# Verificar conexión MySQL
mysql -u root -p -e "SELECT 1"
```

#### Flutter no compila Windows
```bash
# Reinstalar dependencias
flutter clean
flutter pub get

# Verificar Visual Studio
flutter doctor -v
```

#### Error de conexión en móvil
1. Verificar que dispositivo y servidor estén en la misma red
2. Probar UDP discovery: Settings → Auto-discover
3. Configurar manualmente: Settings → Server URL

Ver [Documentacion/TROUBLESHOOTING.md](Documentacion/TROUBLESHOOTING.md) para guía completa.

---

## 📊 Estadísticas del Proyecto

- **Archivos Dart:** 49+ archivos
- **Controllers Node.js:** 14 controladores
- **Rutas API:** 16 módulos
- **Tablas Base Datos:** 25+ tablas
- **Módulos Funcionales:** 14 desktop + 6 móvil
- **Servicios Frontend:** 11 servicios especializados
- **Componentes UI:** 14 widgets reutilizables
- **Idiomas:** 3 (EN/ES/KO)
- **Líneas de código:** ~50,000+ (estimado)

---

## 📄 Licencia

Este proyecto es propietario y está desarrollado para LGEMN.

---

## 👥 Contacto y Soporte

**Desarrollado para:** LGEMN
**Periodo:** 2025-2026

Para soporte técnico o consultas, contactar al equipo de Sistemas.

---

## 🙏 Agradecimientos

- Equipo de Sistemas LGEMN
- Departamento de Almacén
- Departamento de Calidad
- Usuarios beta testers

---

**Última actualización:** Enero 2026
**Versión del documento:** 1.0.0
