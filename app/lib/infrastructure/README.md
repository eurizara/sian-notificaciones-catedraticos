# lib/infrastructure — Implementaciones Firebase

Adaptadores concretos: repositorios sobre Firestore, adaptador de Storage,
adaptador de FCM, adaptador de Auth.

Es la **única** carpeta de `lib/` autorizada a importar paquetes de Firebase.
Si aparece un `import 'package:cloud_firestore/...'` fuera de aquí, es un defecto
de arquitectura, no un atajo (RNF-19).

Se puebla en la iteración 1.2.
