# Run the review app on Windows

Run these commands in PowerShell on the Windows computer that can reach Oracle.

## Start the app

Open PowerShell in the application repository root, where `gradlew.bat` is located.

The terminal needs these Oracle settings:

- `SPRING_DATASOURCE_URL`
- `SPRING_DATASOURCE_USERNAME`
- `SPRING_DATASOURCE_PASSWORD`

If they are not already loaded, set them in that terminal. Replace the example values below with your own connection details. Do not save real credentials in this repository.

```powershell
$env:SPRING_DATASOURCE_URL = 'jdbc:oracle:thin:@//HOST:1521/SERVICE'
$env:SPRING_DATASOURCE_USERNAME = 'YOUR_USERNAME'
$oraclePassword = Read-Host 'Oracle password' -AsSecureString
$env:SPRING_DATASOURCE_PASSWORD = [System.Net.NetworkCredential]::new('', $oraclePassword).Password
```

Start the app with Oracle:

```powershell
.\gradlew.bat :icms-review-service:bootRun --args="--spring.profiles.active=oracle --spring.sql.init.mode=never --review.demo=false --review.sql-directory=sql --spring.datasource.driver-class-name=oracle.jdbc.OracleDriver --server.port=8080"
```

Open [http://127.0.0.1:8080/companies](http://127.0.0.1:8080/companies).

Keep PowerShell open while using the app. Press **Ctrl+C** there to stop it. If port 8080 is already in use, stop the other app first, or change `8080` to `8081` in the command and browser address.

IntelliJ Run Configuration variables do not automatically apply to PowerShell. Set the variables in this terminal, or start the app using the saved Oracle Run Configuration in IntelliJ.

## Build and test

From the repository root:

```powershell
.\gradlew.bat :icms-review-service:test
.\gradlew.bat :icms-review-service:bootJar
```

Java 17 or 21 and the existing bank Artifactory settings are required. These instructions do not change those settings. The Oracle startup command disables demo mode and database initialization.
