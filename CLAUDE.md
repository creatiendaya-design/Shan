# Shannon — App de Finanzas Personales

App de finanzas personales hecha por **Lionel** como regalo para **Shannon**.

## Contexto
- Creada como detalle personal — Shannon es la persona a quien está dedicada
- Pantalla de bienvenida personal aparece solo la primera vez (flag `welcomed` en SharedPreferences)
- **Privacidad total**: todos los datos viven en el dispositivo, sin backend, sin internet requerido
- Sin registro, sin login de usuario — solo seguridad local opcional

## Stack Técnico
| | |
|--|--|
| Framework | Flutter (Android + iOS) |
| State management | Riverpod |
| Base de datos | Drift (SQLite local) |
| Navegación | go_router |
| Gráficas | fl_chart |
| Tipografía | IBM Plex Sans (google_fonts) |
| Seguridad | local_auth (biometría) + flutter_secure_storage (PIN) |
| Íconos | Material Icons |

## Diseño
- **Paleta**: Burgundy Elegante Dark
- Fondo: `#0D0005`
- Tarjeta: `#1A0A0F`
- Primario (marca): `#881337`
- Secundario: `#BE185D`
- Ingreso: `#10B981` (verde)
- Gasto: `#EF4444` (rojo)
- Texto: `#FFFFFF`
- Texto suave: `#CBD5E1`

## Arquitectura
Clean Architecture por features. Dinero siempre almacenado como **enteros en centavos** (nunca `double`).

```
lib/
├── main.dart
├── app/
│   ├── app.dart
│   ├── router/app_router.dart
│   └── theme/
│       ├── app_colors.dart
│       └── app_theme.dart
├── data/
│   └── local/
│       ├── app_database.dart        # Drift aggregate DB
│       ├── tables/                  # accounts, categories, transactions, budgets
│       ├── daos/                    # account_dao, category_dao, transaction_dao
│       └── seed/default_categories.dart
├── features/
│   ├── welcome/                     # Pantalla personal (solo primera vez)
│   ├── shell/                       # Bottom Nav + FAB
│   ├── dashboard/                   # Balance + resumen mensual
│   ├── transactions/                # Lista y formulario de transacciones
│   ├── budgets/                     # Presupuesto mensual
│   └── more/                        # Cuentas, inversiones, metas, ajustes
└── shared/
    └── providers/
        ├── database_provider.dart   # AppDatabase singleton + seed
        └── transaction_providers.dart
```

## Base de Datos (Drift, schemaVersion: 1)
- **accounts**: id, name, type, initialBalanceCents, currency, colorHex, iconKey, archived
- **categories**: id, name, kind (income|expense), iconKey, colorHex, isDefault, sortOrder
- **transactions**: id, type (income|expense|transfer), amountCents, accountId, transferAccountId, categoryId, date, note
- **budgets**: id, year, month, categoryId, limitCents, currency

Balance de cuenta = `initialBalanceCents + SUM(income) - SUM(expense) - SUM(transferOut) + SUM(transferIn)` — nunca almacenado.

## Fases
### Fase 1 — MVP (en progreso)
- [x] Pantalla de bienvenida personal (Shannon / Lionel)
- [x] Tema Burgundy Dark + IBM Plex Sans
- [x] Navegación Bottom Nav (Inicio, Gastos, Presupuesto, Más) + FAB
- [x] Base de datos Drift con tablas y DAOs
- [x] Categorías por defecto sembradas al primer arranque
- [x] Formulario agregar transacción (gasto/ingreso/transferencia)
- [x] Dashboard con balance real, ingresos, gastos y lista de movimientos
- [ ] Seguridad: PIN / huella / sin bloqueo (a elección del usuario)
- [ ] Lista de transacciones completa con eliminar/editar
- [ ] Presupuesto mensual funcional
- [ ] Pantalla de cuentas con saldos

### Fase 2 — Importación
- [ ] CSV import (estados de cuenta)
- [ ] Captura foto voucher + OCR (Google ML Kit, on-device)

### Fase 3 — Módulos avanzados
- [ ] Seguimiento de inversiones
- [ ] Deudas y pagos
- [ ] Metas de ahorro (con gamificación)

## Reglas Importantes
- Dinero: siempre `int` centavos, NUNCA `double`
- Sin datos bancarios reales (solo nombres/etiquetas que el usuario inventa)
- Sin números de cuenta, CLABE, ni datos sensibles
- Privacidad: cero conexiones externas, cero analytics
- Transferencias: modelo de fila única (`type = transfer` + `transferAccountId`)

## Comandos Útiles
```powershell
# Correr la app
flutter run

# Regenerar código Drift/Riverpod
dart run build_runner build --delete-conflicting-outputs

# Analizar errores
flutter analyze

# Hot restart (cambios grandes)
# Presionar R en la terminal donde corre flutter run
```

## Problema Conocido
El proyecto está en `D:\` y el pub cache en `C:\` — esto requiere `kotlin.incremental=false` en `android/gradle.properties` para evitar errores de compilación de Kotlin.
