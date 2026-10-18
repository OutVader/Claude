@{
    # Reglas de estilo que no aplican a este proyecto (justificación en INSTRUCCIONES.md):
    #  - PSAvoidUsingWriteHost: son herramientas de consola interactivas; la salida es para la persona.
    #  - PSUseSingularNouns: los nombres están en español (Mes, Lotes, Origenes...) y la regla es para inglés.
    #  - PSUseShouldProcessForStateChangingFunctions: son funciones internas; -WhatIf/-Confirm se
    #    controlan una sola vez a nivel de script, antes de copiar o borrar nada.
    #  - PSUseLiteralInitializerForHashtable: las tablas de hashes se crean A PROPÓSITO con
    #    StringComparer.Ordinal (distinguen mayúsculas: A.jpg y a.jpg son archivos distintos);
    #    @{} no las distingue y llevaría a asignar el SHA256 de un archivo a otro.
    Severity     = @('Error', 'Warning')
    ExcludeRules = @('PSAvoidUsingWriteHost', 'PSUseSingularNouns', 'PSUseShouldProcessForStateChangingFunctions', 'PSUseLiteralInitializerForHashtable')
}
