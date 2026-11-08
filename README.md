# Waveshare 1.69" LCD en Raspberry Pi OS Trixie

**Pantalla ST7789V2 funcionando como consola Linux mediante DRM/KMS en Raspberry Pi Zero W.**

Este proyecto documenta cómo configurar la pantalla LCD Waveshare de 1.69 pulgadas y resolución 240 × 280 para utilizarla como pantalla principal de consola en Raspberry Pi OS Trixie, sin depender de programas Python que dibujen continuamente en ella.

El objetivo es conseguir una instalación reproducible, sencilla y documentada, que permita que la pantalla funcione desde el arranque del sistema y muestre directamente la consola Linux.

## Características

- Pantalla Waveshare 1.69" con controlador ST7789V2.
- Resolución nativa: 240 × 280 píxeles.
- Comunicación mediante SPI.
- Control de pantalla mediante DRM/KMS.
- Integración con el sistema de consola Linux.
- Funcionamiento desde el arranque.
- Cuatro orientaciones de pantalla.
- Configuración persistente mediante Device Tree Overlay.

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

Las pruebas se realizaron tanto en una instalación de referencia como en una instalación limpia de Raspberry Pi OS Trixie.

## Orientaciones disponibles

Se comprobaron las cuatro orientaciones mediante la configuración MADCTL del controlador ST7789V2 y los parámetros de resolución y desplazamiento del overlay.

| Orientación | MADCTL | Resolución configurada | Desplazamiento |
|---|---|---|---|
| 0° | `0x00` | 240 × 280 | Y = 20 |
| 90° | `0x60` | 280 × 240 | X = 20 |
| 180° | `0xC0` | 240 × 280 | Y = 20 |
| 270° | `0xA0` | 280 × 240 | X = 20 |

Las cuatro configuraciones fueron probadas visualmente, verificando que el texto de la consola pudiera leerse correctamente.

## Rendimiento SPI

Se realizaron pruebas con diferentes velocidades de comunicación SPI durante la reproducción de vídeo.

| Velocidad SPI | Fotogramas perdidos observados |
|---|---:|
| 10 MHz | Más de 3500 |
| 20 MHz | 1350 |
| 32 MHz | 180 |

En las pruebas realizadas, 32 MHz ofreció una mejora considerable en la fluidez de reproducción.

**Importante:** la velocidad SPI determina la capacidad de transferencia de datos entre la Raspberry Pi y la pantalla. No representa directamente la frecuencia de refresco nativa del panel.

Los 32 MHz son un valor comprobado en nuestro hardware de pruebas; no constituyen una garantía de funcionamiento para todas las unidades o instalaciones.

### Temperatura

Durante las pruebas de reproducción de vídeo se registraron los siguientes valores:

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

## Estado del proyecto

<details>
<summary>Desarrollo y documentación</summary>

- [x] Funcionamiento de la pantalla en Raspberry Pi OS Trixie.
- [x] Prueba en una instalación limpia.
- [x] Visualización de la consola Linux desde el arranque.
- [x] Comprobación de las cuatro orientaciones.
- [x] Pruebas de rendimiento SPI a 10, 20 y 32 MHz.
- [x] Comprobación de temperatura durante reproducción de vídeo.
- [ ] Documentación completa de conexiones.
- [ ] Documentación detallada de instalación manual.
- [ ] Preparación del instalador automático.
- [ ] Preparación del desinstalador.
- [ ] Pruebas adicionales de reproducibilidad.

</details>

## Objetivo

El propósito de este repositorio es compartir una solución práctica y reproducible con la comunidad de Raspberry Pi, especialmente con quienes quieran utilizar esta pequeña pantalla como consola Linux en Raspberry Pi OS Trixie.

La documentación se desarrollará inicialmente en español. Posteriormente se incorporará una versión en inglés.

## Contribuciones

Las pruebas realizadas, observaciones y mejoras de otros usuarios serán bienvenidas. Se agradecen especialmente los reportes de funcionamiento en otros modelos de Raspberry Pi y distintas versiones del sistema operativo.

---

**Proyecto en desarrollo.** La documentación y los scripts de instalación se irán incorporando a medida que se completen y verifiquen.
