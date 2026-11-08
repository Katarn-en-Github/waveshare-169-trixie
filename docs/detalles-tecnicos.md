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

## 9. Consideraciones para futuras versiones

El objetivo de este proyecto es facilitar la instalación a otros usuarios.

Por ello, se plantea organizar los componentes de forma que un futuro instalador automático pueda:

1. Comprobar que se está ejecutando Raspberry Pi OS Trixie.
2. Identificar la arquitectura y los componentes necesarios.
3. Habilitar SPI si todavía no está habilitado.
4. Instalar el firmware `panel.bin`.
5. Configurar el overlay en `config.txt`.
6. Aplicar la orientación seleccionada.
7. Permitir revertir los cambios mediante un desinstalador.

Estos pasos forman parte del desarrollo previsto y no deben considerarse todavía un instalador terminado.

## 10. Referencias

- [Linux Kernel: panel-mipi-dbi SPI binding](https://github.com/torvalds/linux/blob/master/Documentation/devicetree/bindings/display/panel/panel-mipi-dbi-spi.yaml)
- [Linux Kernel: DRM/KMS](https://docs.kernel.org/gpu/drm-kms.html)
- [notro/panel-mipi-dbi](https://github.com/notro/panel-mipi-dbi)
- [Raspberry Pi: Device Tree](https://www.raspberrypi.com/documentation/computers/configuration.html#device-trees-overlays-and-parameters)

---

**Proyecto:** Waveshare 1.69" ST7789V2 en Raspberry Pi OS Trixie.

**Estado:** documentación técnica basada en una implementación probada en Raspberry Pi Zero W.
