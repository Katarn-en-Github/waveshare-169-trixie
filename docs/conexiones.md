# Conexiones de la pantalla Waveshare 1.69"

Esta guía describe cómo conectar la pantalla Waveshare 1.69" (ST7789V2) a una Raspberry Pi Zero W utilizando la interfaz SPI.

## Hardware

- Raspberry Pi Zero W.
- Waveshare 1.69" LCD Module (ST7789V2).
- Cables Dupont hembra-hembra.

## Diagrama de conexiones

| Pin de la pantalla | GPIO BCM | Pin físico Raspberry Pi | Función |
|---|---:|---:|---|
| VCC | — | 1 | Alimentación 3.3 V |
| GND | — | 6 | Tierra |
| DIN | GPIO10 | 19 | SPI MOSI |
| CLK | GPIO11 | 23 | SPI SCLK |
| CS | GPIO8 | 24 | SPI CE0 |
| DC | GPIO25 | 22 | Data / Command |
| RST | GPIO27 | 13 | Reset |
| BL | GPIO18 | 12 | Control de retroiluminación |

## Esquema de conexión

```text
Waveshare 1.69"       Raspberry Pi Zero W

VCC  ---------------- Pin 1  (3.3V)
GND  ---------------- Pin 6  (GND)
DIN  ---------------- Pin 19 (GPIO10 / MOSI)
CLK  ---------------- Pin 23 (GPIO11 / SCLK)
CS   ---------------- Pin 24 (GPIO8 / CE0)
DC   ---------------- Pin 22 (GPIO25)
RST  ---------------- Pin 13 (GPIO27)
BL   ---------------- Pin 12 (GPIO18)
```

## Precauciones

1. **Alimentación:** conectar VCC exclusivamente a 3.3 V (pin físico 1). No conectar a 5 V.
2. **Polaridad:** comprobar las conexiones de VCC y GND antes de encender la Raspberry Pi.
3. **Interfaz SPI:** la pantalla utiliza SPI0, dispositivo CE0.
4. **Numeración GPIO:** la columna BCM identifica el número lógico del GPIO; la columna de pin físico indica su posición en el conector de 40 pines de la Raspberry Pi.
5. **Retroiluminación:** BL se conecta a GPIO18, utilizado por la configuración de este proyecto para controlar la retroiluminación.

## Activación de SPI

La interfaz SPI debe estar habilitada en Raspberry Pi OS Trixie.

Puede habilitarse mediante:

```bash
sudo raspi-config
```

Seleccionar:

`Interface Options` → `SPI` → `Enable`

También puede habilitarse desde la terminal:

```bash
sudo raspi-config nonint do_spi 0
```

Después de reiniciar, comprobar que los dispositivos SPI están disponibles:

```bash
ls -l /dev/spidev*
```

En esta configuración se espera encontrar:

```text
/dev/spidev0.0
/dev/spidev0.1
```

## Comprobación final

Antes de continuar con la instalación del controlador, verificar:

- [ ] La pantalla está conectada según la tabla.
- [ ] VCC recibe 3.3 V.
- [ ] GND está conectado correctamente.
- [ ] SPI está habilitado.
- [ ] Existe `/dev/spidev0.0`.

**Importante:** esta guía corresponde al cableado probado en una Raspberry Pi Zero W Rev 1.1. Aunque la distribución de pines es compatible con otros modelos Raspberry Pi de 40 pines, las pruebas de este proyecto se realizaron con el hardware indicado.
