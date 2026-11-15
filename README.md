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
- Temperatura
