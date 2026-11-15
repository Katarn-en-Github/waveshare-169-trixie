
# Orientaciones de la pantalla Waveshare 1.69"

La pantalla Waveshare 1.69" utiliza el controlador ST7789V2. Es posible configurar cuatro orientaciones: 0°, 90°, 180° y 270°.

Para conseguirlo hay que modificar dos elementos de la configuración:

1. El registro MADCTL (`0x36`) en el firmware de inicialización `panel.bin`.
2. La resolución y el desplazamiento de imagen definidos mediante los parámetros del overlay `mipi-dbi-spi`.

**Importante:** ambos ajustes deben corresponder a la misma orientación. Si no coinciden, la imagen puede aparecer desplazada, recortada o reflejada.

## 1. Tabla de orientaciones comprobadas

Las siguientes combinaciones fueron probadas visualmente en una Raspberry Pi Zero W con Raspberry Pi OS Trixie.

| **Orientación** | **MADCTL (`0x36`)** | **Ancho** | **Alto** | **Desplazamiento** |
| --------------- | ------------------- | --------- | -------- | ------------------ |
| 0°              | `0x00`              | 240       | 280      | Y = 20             |
| 90°             | `0x60`              | 280       | 240      | X = 20             |
| 180°            | `0xC0`              | 240       | 280      | Y = 20             |
| 270°            | `0xA0`              | 280       | 240      | X = 20             |

Las cuatro configuraciones permiten visualizar la consola con el texto correctamente orientado.

## 2. Configuración del firmware

El archivo de inicialización utilizado para generar `panel.bin` contiene una instrucción MADCTL:

```text
command 0x36 0x00
```

El segundo valor es el que determina la orientación.

Para seleccionar otra posición, sustituir ese valor de acuerdo con la tabla:

| **Orientación** | **Instrucción**     |
| --------------- | ------------------- |
| 0°              | `command 0x36 0x00` |
| 90°             | `command 0x36 0x60` |
| 180°            | `command 0x36 0xC0` |
| 270°            | `command 0x36 0xA0` |

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

Existen dos formas de seleccionar la orientación de la pantalla.

### Mediante el instalador

El instalador `install.sh` permite seleccionar la orientación durante el proceso de instalación:

- 0° (vertical, predeterminada).
- 90° (horizontal).
- 180° (vertical invertida).
- 270° (horizontal).

El instalador utiliza el firmware y los parámetros de resolución y desplazamiento correspondientes a la orientación seleccionada.

Esta es la forma recomendada de configurar la pantalla.

### Mediante configuración manual

Para cambiar la orientación manualmente:

1. Seleccionar el archivo de firmware correspondiente a la orientación deseada, disponible en el directorio `firmware/` del repositorio.
2. Copiarlo como `/lib/firmware/panel.bin`.
3. Modificar los parámetros de resolución y desplazamiento en `/boot/firmware/config.txt`, de acuerdo con la tabla de esta documentación.
4. Reiniciar la Raspberry Pi.

Los cambios se aplican durante el arranque del sistema.

**Importante:** el valor MADCTL del firmware y los parámetros del overlay deben corresponder a la misma orientación. No se debe combinar un firmware de una orientación con los parámetros de otra.

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

La orientación predeterminada del instalador es 0° (vertical). Las cuatro orientaciones fueron probadas satisfactoriamente y permiten utilizar la pantalla con el texto correctamente orientado.

Para reproducir los resultados, es importante utilizar conjuntamente los archivos de firmware y los parámetros del overlay indicados en esta documentación.

**Nota:** los valores de esta guía corresponden a las pruebas realizadas con la pantalla Waveshare 1.69" ST7789V2 en Raspberry Pi Zero W Rev 1.1 y Raspberry Pi OS Trixie.
EOF

echo "===== VERIFICACIÓN DEL DOCUMENTO ====="
wc -l orientaciones.md
echo
echo "===== INICIO DEL DOCUMENTO ====="
sed -n '1,35p' orientaciones.md
echo
echo "===== FINAL DEL DOCUMENTO ====="
tail -n 25 orientaciones.md
