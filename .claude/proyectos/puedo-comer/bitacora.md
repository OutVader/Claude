# Bitácora

## 2026-10-04
- Partimos del index.html de 214505 bytes (md5 8c486fe0…), con `pedirGemini` y los modelos de reserva.
- Cambios en el flujo de la foto (sin tocar datos ni avisos):
  - Texto de espera: antes decía «máx. 20 s», pero con los reintentos puede tardar más. Ahora lo avisa.
  - Si el modelo elegido da 503 y uno de reserva da 404, se muestra el 503, que es el error que importa.
  - El aviso del modelo de reserva ya no da por hecho «saturado»: dice «saturado o no disponible».
- Verificación local (file://): 5/5. Simulación de Gemini: reserva tras 503 OK, todo caído → 503, clave inválida → sin reintentos.
- Publicación: no se puede crear el repo nuevo desde la sesión (403, integración limitada a OutVader/Claude).
