# Orientaciones de la pantalla Waveshare 1.69"

La pantalla Waveshare 1.69" utiliza el controlador ST7789V2. Es posible configurar cuatro orientaciones: 0°, 90°, 180° y 270°.

Para conseguirlo hay que modificar dos elementos de la configuración:

1. El registro MADCTL (`0x36`) en el firmware de inicialización `panel.bin`.
2. La resolución y el desplazamiento de imagen definidos mediante los parámetros del overlay `mipi-dbi-spi`.

**Importante:** ambos ajustes deben corresponder a la misma orientación. Si no coinciden, la imagen puede aparecer desplazada, recortada o reflejada.

## 1. Tabla de orientaciones comprobadas

Las siguientes combinaciones fueron probadas visualmente en una Raspberry Pi Zero W con Raspberry Pi OS Trixie.

| Orientación | MADCTL (`0x36`) | Ancho | Alto | Desplazamiento |
|---|---|---:|---:|---|
| 0° | `0x00` | 240 | 280 | Y = 20 |
| 90° | `0x60` | 280 | 240 | X = 20 |
| 180° | `0xC0` | 240 | 280 | Y = 20 |
| 270° | `0xA0` | 280 | 240 | X = 20 |

Las cuatro configuraciones permiten visualizar la consola con el texto correctamente orientado.

## 2. Configuración del firmware

El archivo de inicialización utilizado para generar `panel.bin` contiene una instrucción MADCTL:

```text
command 0x36 0x00
```

El segundo valor es el que determina la orientación.

Para seleccionar otra posición, sustituir ese valor de acuerdo con la tabla:

| Orientación | Instrucción |
|---|---|
| 0° | `command 0x36 0x00` |
| 90° | `command 0x36 0x60` |
| 180° | `command 0x36 0xC0` |
| 270° | `command 0x36 0xA0` |

Después de modificar la instrucción, hay que generar nuevamente el archivo binario `panel.bin` utilizando la herramienta `mipi-dbi-cmd` y sustituir el firmware instalado en:

```text
/lib/firmware/panel.bin
```

## 3. Configuración del Device Tree Overlay

Además de modificar MADCTL, hay que ajustar la resolución y el desplazamiento en `/boot/firmware/config.txt`.

La configuración común utilizada en las pruebas es:

```ini
dtoverlay=mipi-dbi-spi,spi0-0,speed=32000000,write-only
dtparam=reset-gpio=27,dc-gpio=25
dtparam=backlight-gpio=18
```

A continuación, añadir los parámetros correspondientes a la orientación elegida.

### Orientación 0° (vertical)

```ini
dtparam=width=240,height=280
dtparam=y-offset=20
```

### Orientación 90° (horizontal)

```ini
dtparam=width=280,height=240
dtparam=x-offset=20
```

### Orientación 180° (vertical invertida)

```ini
dtparam=width=240,height=280
dtparam=y-offset=20
```

### Orientación 270° (horizontal)

```ini
dtparam=width=280,height=240
dtparam=x-offset=20
```

**Nota:** la orientación 0° y 180° comparten resolución y desplazamiento. Lo mismo sucede con 90° y 270°. La diferencia entre ellas está en el valor MADCTL del firmware.

## 4. Aplicar los cambios

Para cambiar la orientación:

1. Modificar el valor MADCTL en el archivo de inicialización.
2. Generar el nuevo `panel.bin`.
3. Instalar el firmware actualizado en `/lib/firmware/panel.bin`.
4. Modificar los parámetros de resolución y desplazamiento en `/boot/firmware/config.txt`.
5. Reiniciar la Raspberry Pi.

Los cambios se aplican durante el arranque del sistema.

## 5. Resultados y observaciones

Durante las pruebas se comprobaron las cuatro orientaciones.

Se observó que:

- Las posiciones verticales utilizan una resolución de 240 × 280.
- Las posiciones horizontales utilizan una resolución de 280 × 240.
- El desplazamiento de 20 píxeles cambia de eje al pasar de vertical a horizontal.
- La selección incorrecta de MADCTL puede producir texto reflejado.
- La combinación `0xA0` fue necesaria para obtener la orientación horizontal de 270° con el texto correctamente legible.

## 6. Configuración recomendada

No existe una orientación obligatoria: depende de cómo se quiera instalar físicamente la pantalla.

La configuración de 90° fue probada satisfactoriamente y permite utilizar la pantalla en posición horizontal.

Para reproducir los resultados, es importante utilizar conjuntamente los valores MADCTL y los parámetros del overlay indicados en esta documentación.

---

**Nota:** los valores de esta guía corresponden a las pruebas realizadas con la pantalla Waveshare 1.69" ST7789V2 en Raspberry Pi Zero W y Raspberry Pi OS Trixie.
