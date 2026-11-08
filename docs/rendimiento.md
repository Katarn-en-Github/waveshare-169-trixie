# Rendimiento de la pantalla Waveshare 1.69"

Este documento recoge las pruebas realizadas para evaluar el rendimiento de la pantalla Waveshare 1.69" ST7789V2 conectada mediante SPI a una Raspberry Pi Zero W con Raspberry Pi OS Trixie.

El objetivo fue comprobar cómo influye la velocidad del bus SPI en la transferencia de imágenes y en la reproducción de vídeo mediante ZeroPlay.

## 1. Configuración de las pruebas

Hardware utilizado:

| Componente | Configuración |
|---|---|
| Raspberry Pi | Zero W Rev 1.1 |
| Pantalla | Waveshare 1.69" ST7789V2 |
| Resolución | 240 × 280 píxeles |
| Interfaz | SPI0, CE0 |
| Sistema operativo | Raspberry Pi OS Lite Trixie |
| Arquitectura | ARM 32-bit (armhf) |
| Controlador | DRM/KMS, MIPI DBI |

Se realizaron pruebas modificando el parámetro `speed` del overlay `mipi-dbi-spi`.

La configuración utilizada fue:

```ini
dtoverlay=mipi-dbi-spi,spi0-0,speed=32000000,write-only
```

Para las pruebas comparativas se modificó únicamente la velocidad SPI:

- 10 MHz
- 20 MHz
- 32 MHz

Después de cada modificación se reinició la Raspberry Pi y se comprobó el funcionamiento de la pantalla.

## 2. Resultados de reproducción de vídeo

Se utilizó ZeroPlay para observar el comportamiento de la pantalla durante la reproducción de vídeo.

Los resultados registrados fueron:

| Velocidad SPI | Fotogramas perdidos | Resultado visual |
|---|---:|---|
| 10 MHz | Más de 3500 | Reproducción muy entrecortada |
| 20 MHz | 1350 | Mejora apreciable, con interrupciones |
| 32 MHz | 180 | Reproducción considerablemente más fluida |

<details>
<summary>Interpretación de los resultados</summary>

El aumento de la velocidad SPI mejoró considerablemente la capacidad de transferencia de datos hacia la pantalla.

A 10 MHz, la reproducción presentó muchas interrupciones.

A 20 MHz se observó una mejora, aunque todavía existían pérdidas importantes de fotogramas.

A 32 MHz la reproducción fue mucho más fluida y el número de fotogramas perdidos disminuyó considerablemente.

</details>

**Importante:** estos valores corresponden a las pruebas realizadas en nuestro equipo. No deben interpretarse como resultados de un benchmark normalizado ni como una garantía de rendimiento en otras instalaciones.

## 3. Comparación del ancho de banda teórico

La pantalla tiene una resolución de 240 × 280 píxeles.

Considerando una transferencia de imagen completa en formato RGB565 (16 bits por píxel):

\[
240 \times 280 \times 16 = 1\,075\,200\text{ bits}
\]

Por tanto, una imagen completa representa aproximadamente 134.4 kB de datos.

Podemos calcular el tiempo mínimo teórico de transferencia suponiendo que todos los bits se transmiten continuamente a la velocidad SPI configurada.

| Velocidad SPI | Tiempo teórico por imagen | Máximo teórico de imágenes completas |
|---|---:|---:|
| 10 MHz | 107.52 ms | 9.3 por segundo |
| 20 MHz | 53.76 ms | 18.6 por segundo |
| 32 MHz | 33.60 ms | 29.8 por segundo |

Estos valores son estimaciones matemáticas del tiempo de transferencia, no mediciones de FPS reales.

En la práctica existen tiempos adicionales asociados a comandos, pausas, organización de las transferencias y funcionamiento del controlador DRM/KMS.

Tampoco representan la frecuencia de refresco nativa del panel.

## 4. Temperatura durante las pruebas

Se realizaron mediciones de temperatura utilizando:

```bash
watch -n 2 vcgencmd measure_temp
```

Se registraron los siguientes valores:

| Condición | Temperatura |
|---|---:|
| Raspberry Pi en reposo | 34.7 °C |
| Durante reproducción de vídeo | 42.2 °C (máximo observado) |

La diferencia entre ambas mediciones fue de aproximadamente 7.5 °C.

Durante estas pruebas no se modificó la frecuencia de funcionamiento de la CPU ni se aplicó overclock.

Los resultados muestran que, en nuestro montaje, el aumento de velocidad SPI hasta 32 MHz no produjo un incremento térmico importante.

Estas mediciones corresponden a las condiciones ambientales y de funcionamiento de nuestro equipo; no constituyen una especificación térmica universal.

## 5. Configuración recomendada

La configuración que ofreció el mejor resultado en nuestras pruebas fue:

```ini
dtoverlay=mipi-dbi-spi,spi0-0,speed=32000000,write-only
```

<badge color="success">Probada y estable en nuestro equipo</badge>

Después de aplicar esta configuración y reiniciar, se comprobó:

- La consola Linux continúa funcionando normalmente.
- No se observaron parpadeos.
- No aparecieron caracteres corruptos.
- No se observaron líneas faltantes.
- No se perdió la imagen.
- ZeroPlay presentó una reproducción considerablemente más fluida.

**Recomendación:** comenzar con 10 MHz si se desea una configuración conservadora y aumentar progresivamente la velocidad, comprobando la estabilidad de cada instalación. Los 32 MHz son el valor que mejor funcionó en nuestro montaje, pero cada combinación de Raspberry Pi, pantalla y cableado puede comportarse de manera diferente.

## 6. SPI y frecuencia de refresco: dos conceptos diferentes

Es importante distinguir entre la velocidad de comunicación SPI y la frecuencia de refresco del panel.

**Velocidad SPI**

Es la velocidad a la que se transfieren los datos entre la Raspberry Pi y el controlador de la pantalla. Se expresa en MHz.

**Frecuencia de refresco**

Es la frecuencia con la que el panel actualiza su imagen. No queda establecida directamente por el parámetro `speed` del overlay.

Aumentar la velocidad SPI permite transferir los datos con mayor rapidez, pero no significa que el panel tenga automáticamente una frecuencia de refresco equivalente.

