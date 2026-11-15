# Detalles técnicos: Waveshare 1.69" ST7789V2

Este documento explica la arquitectura utilizada para integrar la pantalla Waveshare 1.69" ST7789V2 en Raspberry Pi OS Trixie mediante los subsistemas SPI y DRM/KMS del kernel Linux.

El objetivo es documentar cómo funciona la solución y qué componentes intervienen durante el arranque.

## 1. Arquitectura de la solución

La implementación utiliza componentes que ya están disponibles en Raspberry Pi OS Trixie:

- Interfaz SPI del SoC Broadcom.
- Device Tree Overlay `mipi-dbi-spi`.
- Controlador de panel `panel-mipi-dbi`.
- Infraestructura DRM/KMS del kernel Linux.
- Firmware de inicialización `panel.bin`.

El flujo de funcionamiento es:

```text
Raspberry Pi Zero W
        |
        v
     SPI0 / CE0
        |
        v
   mipi-dbi-spi
        |
        v
   panel-mipi-dbi
        |
        v
      DRM/KMS
        |
        v
  Consola Linux
        |
        v
Waveshare 1.69" LCD
     ST7789V2
```

La pantalla queda integrada en el sistema de visualización del kernel, en lugar de depender de una aplicación que dibuje imágenes directamente.

## 2. Interfaz SPI

La comunicación con la pantalla utiliza SPI0, dispositivo CE0.

Los pines empleados son:

| Señal | GPIO BCM | Función |
|---|---:|---|
| MOSI | GPIO10 | Transmisión de datos |
| SCLK | GPIO11 | Reloj SPI |
| CE0 | GPIO8 | Selección del dispositivo |
| DC | GPIO25 | Selección Data/Command |
| RST | GPIO27 | Reinicio del controlador |
| BL | GPIO18 | Retroiluminación |

La interfaz SPI debe estar habilitada en el sistema operativo.

Puede comprobarse mediante:

```bash
ls -l /dev/spidev*
```

En nuestra instalación se encontraron:

```text
/dev/spidev0.0
/dev/spidev0.1
```

La presencia de estos dispositivos confirma que la interfaz SPI está habilitada en el sistema. No significa, por sí sola, que la pantalla esté funcionando.

## 3. Device Tree Overlay

Raspberry Pi OS Trixie incluye el overlay:

```text
/boot/firmware/overlays/mipi-dbi-spi.dtbo
```

Este overlay permite declarar una pantalla MIPI DBI conectada mediante SPI.

En nuestro proyecto se utiliza con la siguiente configuración de referencia:

```ini
dtoverlay=mipi-dbi-spi,spi0-0,speed=32000000,write-only
dtparam=width=240,height=280
dtparam=reset-gpio=27,dc-gpio=25
dtparam=backlight-gpio=18
dtparam=y-offset=20
```

Esta variante corresponde a la orientación vertical de 0°.

Para otras orientaciones deben modificarse conjuntamente las dimensiones, el desplazamiento y el valor MADCTL del firmware. Los detalles están documentados en `orientaciones.md`.

### Parámetros utilizados

| Parámetro | Función |
|---|---|
| `spi0-0` | Selecciona SPI0 y CE0 |
| `speed=32000000` | Establece una velocidad SPI de 32 MHz |
| `write-only` | Configura la comunicación de escritura |
| `width` | Ancho de la imagen |
| `height` | Alto de la imagen |
| `reset-gpio` | GPIO conectado al reset |
| `dc-gpio` | GPIO Data/Command |
| `backlight-gpio` | GPIO de retroiluminación |
| `x-offset` | Desplazamiento horizontal |
| `y-offset` | Desplazamiento vertical |

Los parámetros de resolución y desplazamiento dependen de la orientación seleccionada.

## 4. Firmware de inicialización: panel.bin

El archivo `panel.bin` contiene la secuencia de comandos necesaria para inicializar el controlador ST7789V2.

No es un programa ejecutable. Es un archivo binario de firmware que interpreta el controlador de pantalla durante su inicialización.

Entre las operaciones realizadas se encuentran:

- Configuración de orientación mediante MADCTL (`0x36`).
- Selección del formato de color mediante `0x3A`.
- Configuración de parámetros internos del controlador.
- Ajustes de voltaje y gamma.
- Activación de inversión de color mediante `0x21`.
- Salida del modo de suspensión mediante `0x11`.
- Activación del panel mediante `0x29`.

El archivo se instala en:

```text
/lib/firmware/panel.bin
```

El overlay utiliza este firmware para inicializar la pantalla.

### Generación del firmware

La secuencia de inicialización se prepara en un archivo de texto con instrucciones como:

```text
command 0x36 0x00
command 0x3A 0x05
command 0x21
command 0x11
delay 100
command 0x29
```

Este es solamente un fragmento ilustrativo de la secuencia completa.

Para convertir el archivo de instrucciones en firmware binario se utiliza la herramienta `mipi-dbi-cmd`:

```bash
python3 mipi-dbi-cmd -v panel.bin panel.txt
```

La herramienta utilizada en este proyecto procede del repositorio:

[notro/panel-mipi-dbi](https://github.com/notro/panel-mipi-dbi)

El archivo binario debe generarse a partir de la secuencia completa y probada para el ST7789V2. No debe utilizarse el fragmento ilustrativo anterior como firmware completo.

## 5. Controlador DRM/KMS

La solución utiliza el subsistema DRM/KMS del kernel Linux.

Los componentes principales son:

```text
panel-mipi-dbi
drm_mipi_dbi
```

Estos módulos permiten gestionar el panel y su comunicación mediante MIPI DBI.

En Raspberry Pi OS Trixie se encuentran disponibles en los módulos suministrados con el kernel.

La integración con DRM/KMS permite que el sistema operativo gestione la pantalla como un dispositivo de visualización.

Esto evita tener que implementar manualmente un mecanismo de dibujo permanente desde una aplicación de usuario.

## 6. Integración con la consola Linux

Uno de los objetivos principales del proyecto es utilizar la pantalla como consola del sistema.

Una vez que la configuración se aplica correctamente durante el arranque, la pantalla puede mostrar los mensajes de inicio y el shell de Linux.

La solución no necesita:

- Un programa Python ejecutándose continuamente.
- Un bucle de actualización de imágenes.
- Un servicio adicional para dibujar la consola.
- Bibliotecas como Pillow o NumPy para gestionar la pantalla.

La visualización es gestionada por el propio sistema operativo y el kernel.

## 7. Archivos y ubicaciones importantes

| Archivo o directorio | Función |
|---|---|
| `/boot/firmware/config.txt` | Configuración del overlay |
| `/boot/firmware/overlays/mipi-dbi-spi.dtbo` | Overlay de pantalla SPI |
| `/lib/firmware/panel.bin` | Firmware de inicialización |
| `/dev/spidev0.0` | Dispositivo SPI0 CE0 |
| `/sys/bus/spi/devices/` | Dispositivos SPI detectados |
| `/dev/dri/` | Dispositivos del subsistema DRM |

## 8. Configuración comprobada

La solución fue comprobada en dos instalaciones de Raspberry Pi OS Lite Trixie de 32 bits:

| Instalación | Kernel |
|---|---|
| Instalación de referencia | 6.18.50+rpt-rpi-v6 |
| Instalación limpia de reproducción | 6.18.60+rpt-rpi-v6 |

En ambas se consiguió iniciar la pantalla desde el arranque y visualizar la consola Linux.

Esto permitió comprobar que la solución no dependía exclusivamente de la configuración de una instalación anterior.

## 9. Instalación y desinstalación automatizadas

El repositorio incluye dos scripts para facilitar la instalación y retirada de la configuración:

- `install.sh`: instala el firmware, configura el overlay MIPI DBI SPI, aplica la orientación seleccionada y configura la consola Linux mediante `fbcon=map:1`.
- `uninstall.sh`: comprueba los archivos administrados por el proyecto y restaura los respaldos originales cuando corresponde.

Ambos scripts fueron probados en una instalación limpia de Raspberry Pi OS Lite Trixie de 32 bits sobre Raspberry Pi Zero W Rev 1.1.

Las pruebas incluyeron:

1. Instalación inicial y activación de la pantalla después del reinicio.
2. Desinstalación y restauración de la configuración original.
3. Comprobación de la eliminación de los archivos instalados por el proyecto cuando no existían previamente.
4. Reinstalación posterior en el mismo sistema.

El proceso completo se realizó satisfactoriamente.

Los scripts están disponibles en la raíz del repositorio:

- [`install.sh`](../install.sh)
- [`uninstall.sh`](../uninstall.sh)

**Nota:** los scripts están diseñados para Raspberry Pi OS Trixie y la configuración de hardware documentada en este proyecto. Las pruebas realizadas no garantizan compatibilidad con todos los modelos de Raspberry Pi o versiones del sistema operativo.

## 10. Referencias

- Linux Kernel: panel-mipi-dbi SPI binding.
- Linux Kernel: DRM/KMS.
- notro/panel-mipi-dbi.
- Raspberry Pi: Device Tree.
- Proyecto: Waveshare 1.69" ST7789V2 en Raspberry Pi OS Trixie.

**Estado:** implementación técnica, instalación automatizada, desinstalación y reinstalación probadas satisfactoriamente en Raspberry Pi Zero W Rev 1.1 con Raspberry Pi OS Trixie.
