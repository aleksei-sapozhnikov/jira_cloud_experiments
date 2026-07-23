# Script Manager source

This directory mirrors reusable Groovy code that must be created in **ScriptRunner → Script Manager**.

The repository folder `scriptmanager/` is only a documentation boundary. Do not create a `scriptmanager` folder inside ScriptRunner. Recreate the folders below it, so this repository path:

```text
scriptrunner/scriptmanager/incident/IncidentRcaService.groovy
```

is stored in Script Manager as:

```text
incident/IncidentRcaService.groovy
```

The folder path and the Groovy package must match. Entry scripts can then use:

```groovy
import incident.IncidentRcaService
```
