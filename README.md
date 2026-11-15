# Waveshare 1.69" LCD en Raspberry Pi OS Trixie

**Pantalla ST7789V2 funcionando como consola Linux mediante DRM/KMS en Raspberry Pi Zero W.**

Este proyecto documenta cómo configurar la pantalla LCD Waveshare de 1.69 pulgadas y resolución 240 × 280 para utilizarla como consola Linux en Raspberry Pi OS Trixie.

La solución utiliza el subsistema DRM/KMS del kernel y el overlay `mipi-dbi-spi`, sin depender de programas Python que dibujen continuamente en la pantalla.

El objetivo es ofrecer una instalación reproducible, sencilla y documentada, que permita utilizar esta pequeña pantalla como consola desde el arranque del sistema.

## Características

- Pantalla Waveshare 1.69" con controlador ST7789V2.
- Resolución nativa de 240 × 280 píxeles.
- Comunicación mediante SPI.
- Control de pantalla mediante DRM/KMS.
- Integración con el sistema de consola Linux.
- Funcionamiento desde el arranque.
- Cuatro orientaciones disponibles: 0°, 90°, 180° y 270°.
- Configuración persistente mediante Device Tree Overlay.
- Instalación y desinstalación mediante scripts.
- Respaldos de la configuración original del sistema.

## Hardware probado

| Componente | Modelo |
|---|---|
| Raspberry Pi | Zero W Rev 1.1 |
| Pantalla | Waveshare 1.69" LCD |
| Controlador LCD | ST7789V2 |
| Resolución | 240 × 280 |
| Interfaz | SPI de 4 hilos |

## Software probado

| Componente | Versión |
|---|---|
| Sistema operativo | Raspberry Pi OS Lite |
| Debian | Trixie 13 |
| Arquitectura | ARM 32-bit (armhf) |
| Kernel | 6.18.x |

Las pruebas incluyen instalaciones de referencia y una instalación limpia de Raspberry Pi OS Trixie.

Se verificaron la instalación inicial, la desinstalación, la restauración de la configuración original y una posterior reinstalación.

**Nota:** el funcionamiento ha sido comprobado en el hardware y las versiones indicadas. No se garantiza el mismo resultado en otros modelos de Raspberry Pi o versiones del sistema operativo.

## Instalación

El repositorio incluye el instalador `install.sh`, que automatiza la configuración de la pantalla.

Clona o descarga este repositorio y ejecuta:

```bash
sudo bash install.sh
```

El instalador:

1. Comprueba el equipo, el sistema operativo y la arquitectura.
2. Solicita la orientación de la pantalla, con 0° como opción predeterminada.
3. Descarga el firmware correspondiente desde el repositorio.
4. Verifica el tamaño y el SHA256 del firmware.
5. Instala el firmware en `/lib/firmware/panel.bin`.
6. Configura el overlay MIPI DBI SPI.
7. Configura `fbcon=map:1` para dirigir la consola al framebuffer de la pantalla Waveshare.
8. Conserva respaldos de los archivos originales y registra la configuración administrada.

Al finalizar, reinicia la Raspberry Pi:

```bash
sudo reboot
```

### Cambiar la orientación de la pantalla

Si la pantalla LCD ya está instalada y funcionando, no es necesario desinstalarla ni modificar manualmente los archivos de configuración para cambiar su orientación.

Simplemente hay que ejecutar nuevamente el instalador:

```bash
sudo bash install.sh
```

Durante el proceso, seleccionar la nueva orientación deseada:

- 0° (vertical).
- 90° (horizontal).
- 180° (vertical invertida).
- 270° (horizontal).

El instalador actualizará automáticamente el firmware `panel.bin` y los parámetros de resolución y desplazamiento correspondientes en `/boot/firmware/config.txt`.

Después de finalizar, reiniciar la Raspberry Pi para aplicar los cambios.

**No es necesario ejecutar previamente `uninstall.sh`.** El instalador admite nuevas ejecuciones sobre una instalación existente y conserva los respaldos originales, sin generar bloques duplicados en la configuración.

Este procedimiento fue probado satisfactoriamente en una Raspberry Pi Zero W con Raspberry Pi OS Trixie, cambiando la orientación de una pantalla que ya estaba funcionando.

## Desinstalación

El repositorio incluye `uninstall.sh` para retirar la configuración administrada por el proyecto y restaurar los archivos originales.

Ejecuta:

```bash
sudo bash uninstall.sh
```

El desinstalador comprueba los archivos administrados y restaura los respaldos correspondientes. También elimina los archivos instalados por el proyecto cuando no existían antes de la instalación.

Si detecta modificaciones posteriores que impiden una restauración segura, evita sobrescribirlas.

Al finalizar, reinicia la Raspberry Pi:

```bash
sudo reboot
```

## Orientaciones disponibles

Se comprobaron las cuatro orientaciones mediante la configuración MADCTL del controlador ST7789V2 y los parámetros de resolución y desplazamiento del overlay.

| Orientación | MADCTL | Resolución configurada | Desplazamiento |
|---|---|---|---|
| 0° | 0x00 | 240 × 280 | Y = 20 |
| 90° | 0x60 | 280 × 240 | X = 20 |
| 180° | 0xC0 | 240 × 280 | Y = 20 |
| 270° | 0xA0 | 280 × 240 | X = 20 |

Las cuatro configuraciones fueron probadas visualmente, verificando que el texto de la consola pudiera leerse correctamente.

Más información: [docs/orientaciones.md](docs/orientaciones.md).

## Rendimiento SPI

Se realizaron pruebas con diferentes velocidades de comunicación SPI durante la reproducción de vídeo.

| Velocidad SPI | Fotogramas perdidos observados |
|---|---:|
| 10 MHz | Más de 3500 |
| 20 MHz | 1350 |
| 32 MHz | 180 |

En las pruebas realizadas, 32 MHz ofreció una mejora considerable en la fluidez de reproducción.

La velocidad SPI determina la capacidad de transferencia de datos entre la Raspberry Pi y la pantalla. No representa directamente la frecuencia de refresco nativa del panel.

Los 32 MHz son un valor comprobado en nuestro hardware de pruebas; no constituyen una garantía de funcionamiento para todas las unidades o instalaciones.

Más información: [docs/rendimiento.md](docs/rendimiento.md).

## Temperatura

Durante las pruebas se registraron los siguientes valores:

- Temperatura en reposo: aproximadamente 34,7 °C.
- Temperatura máxima observada durante la reproducción: 42,2 °C.

No se modificó la frecuencia de funcionamiento de la CPU.

## Enfoque técnico

La solución utiliza componentes disponibles en Raspberry Pi OS Trixie:

- `mipi-dbi-spi` como Device Tree Overlay.
- `panel-mipi-dbi` como controlador de pantalla.
- `drm_mipi_dbi` para la comunicación con el subsistema DRM.
- Un archivo de firmware `panel.bin` con la secuencia de inicialización del ST7789V2.

La pantalla se integra en el sistema gráfico del kernel, permitiendo utilizarla como consola Linux.

No se necesita mantener un programa Python ejecutándose en segundo plano para actualizar la pantalla.

Más información: [docs/detalles-tecnicos.md](docs/detalles-tecnicos.md).

## Estructura del repositorio

```text
waveshare-169-trixie/
├── config/
│   └── waveshare-169.conf
├── docs/
│   ├── conexiones.md
│   ├── detalles-tecnicos.md
│   ├── orientaciones.md
│   └── rendimiento.md
├── firmware/
│   ├── panel.bin
│   ├── waveshare-169-init-180.bin
│   ├── waveshare-169-init-270.bin
│   └── waveshare-169-init-90.bin
├── tools/
│   └── mipi-dbi-cmd
├── install.sh
├── uninstall.sh
└── README.md
```

## Documentación

| Documento | Contenido |
|---|---|
| [Conexiones](docs/conexiones.md) | Cableado entre Raspberry Pi y pantalla |
| [Detalles técnicos](docs/detalles-tecnicos.md) | Funcionamiento de DRM/KMS y configuración |
| [Orientaciones](docs/orientaciones.md) | Configuración de las cuatro orientaciones |
| [Rendimiento](docs/rendimiento.md) | Pruebas de velocidad SPI y temperatura |

## Estado del proyecto

**Implementación técnica y pruebas principales completadas.**

La instalación, desinstalación y reinstalación fueron verificadas en una instalación limpia de Raspberry Pi OS Trixie sobre Raspberry Pi Zero W Rev 1.1.

Los scripts `install.sh` y `uninstall.sh` están publicados en el repositorio y sus archivos fueron verificados mediante SHA256.

La documentación se mantiene inicialmente en español. La versión en inglés se incorporará posteriormente.

## Objetivo

El propósito de este repositorio es compartir una solución práctica y reproducible con la comunidad de Raspberry Pi, especialmente con quienes quieran utilizar esta pequeña pantalla como consola Linux en Raspberry Pi OS Trixie.

## Contribuciones

Las pruebas realizadas, observaciones y mejoras de otros usuarios serán bienvenidas.

Se agradecen especialmente los reportes de funcionamiento en otros modelos de Raspberry Pi y distintas versiones del sistema operativo.
