# Guía de Configuración iOS - SwipeClean

## Requisitos previos

1. **Mac con macOS 12+**
2. **Xcode 14+** (descargar desde App Store)
3. **Apple ID** (para firmar la app)
4. **iPhone conectado** (opcional, para pruebas en dispositivo real)

---

## Paso 1: Instalar herramientas

Abrir Terminal y ejecutar:

```bash
# Aceptar licencia de Xcode
sudo xcodebuild -license accept

# Instalar herramientas de línea de comandos
xcode-select --install

# Instalar Homebrew (si no lo tienes)
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Instalar Flutter
brew install flutter

# Instalar CocoaPods
brew install cocoapods

# Verificar instalación
flutter doctor
```

---

## Paso 2: Clonar y preparar el proyecto

```bash
# Clonar repositorio
git clone https://github.com/Avzolem/swipeclean.git
cd swipeclean

# Regenerar archivos iOS faltantes (IMPORTANTE)
# Esto crea Runner.xcodeproj, AppDelegate.swift, etc.
# El Podfile y Info.plist ya están configurados correctamente
flutter create . --platforms=ios

# Instalar dependencias de Flutter
flutter pub get

# Instalar pods de iOS (el Podfile ya tiene la config de permisos)
cd ios && pod install && cd ..

# Generar icono de la app
dart run flutter_launcher_icons
```

> **Nota**: El proyecto ya incluye:
> - `ios/Podfile` - Configurado con permisos de fotos
> - `ios/Runner/Info.plist` - Con descripciones de permisos en español

---

## Paso 3: Configurar firma en Xcode

```bash
# Abrir proyecto en Xcode
open ios/Runner.xcworkspace
```

En Xcode:

1. Seleccionar **Runner** en el navegador izquierdo
2. Ir a pestaña **Signing & Capabilities**
3. Marcar **Automatically manage signing**
4. Seleccionar tu **Team** (tu Apple ID)
5. Si el Bundle Identifier da error, cambiarlo a algo único:
   - Ejemplo: `com.tunombre.swipeclean`

---

## Paso 4: Compilar y probar

### Opción A: Simulador de iPhone
```bash
# Listar simuladores disponibles
flutter devices

# Ejecutar en simulador
flutter run -d "iPhone 15"
```

### Opción B: iPhone físico conectado
```bash
# Ver dispositivos conectados
flutter devices

# Ejecutar en iPhone (reemplaza DEVICE_ID)
flutter run -d DEVICE_ID --release
```

### Opción C: Solo compilar (sin ejecutar)
```bash
# Compilar sin firma (para verificar que compila)
flutter build ios --no-codesign

# Compilar con firma (para instalar)
flutter build ios --release
```

---

## Paso 5: Instalar en iPhone

1. Conectar iPhone por USB
2. En el iPhone: **Configuración > General > Gestión de dispositivos**
3. Confiar en tu perfil de desarrollador
4. Ejecutar desde Xcode o con `flutter run`

---

## Solución de problemas comunes

### Error: "No signing certificate"
- Ir a Xcode > Preferences > Accounts
- Agregar tu Apple ID
- Descargar certificados

### Error: "Pod install failed"
```bash
cd ios
pod deintegrate
pod cache clean --all
pod install
```

### Error: "Minimum deployment target"
Editar `ios/Podfile` y agregar al inicio:
```ruby
platform :ios, '12.0'
```

### Error de permisos de fotos
Ya están configurados en `Info.plist`. Si hay problemas, verificar que existan:
- `NSPhotoLibraryUsageDescription`
- `NSPhotoLibraryAddUsageDescription`

---

## Comandos útiles

```bash
# Limpiar build
flutter clean

# Ver logs del dispositivo
flutter logs

# Ejecutar en modo debug con logs
flutter run --verbose

# Generar IPA para distribución
flutter build ipa
```

---

## Contacto

Si hay problemas, contactar al desarrollador con:
1. Captura del error
2. Salida de `flutter doctor -v`
